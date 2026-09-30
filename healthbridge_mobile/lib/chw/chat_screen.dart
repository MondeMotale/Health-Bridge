import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/chat_service.dart';
import '../../services/call_service.dart';
import '../../auth/auth_provider.dart';
import 'video_call_screen.dart';
import 'voice_call_screen.dart';
import '../../config/agora_config.dart';
import '../../utils/constants.dart';

class ChatScreen extends StatefulWidget {
  final String chatWithId;
  final String chatWithName;

  const ChatScreen({super.key, required this.chatWithId, required this.chatWithName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final CallService _callService = CallService();

  /// Convert a Firebase UID (string) into a positive integer UID
  /// that Agora accepts. Agora requires distinct UIDs per user in
  /// the same channel, so we hash the string.
  int _uidFromString(String firebaseUid) {
    return firebaseUid.hashCode.abs() % 1000000000 + 1;
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final String senderId = authProvider.user?.uid ?? '';

    _chatService.sendMessage(
      senderId: senderId,
      receiverId: widget.chatWithId,
      message: _messageController.text.trim(),
    );

    _messageController.clear();
  }

  // --- Delete options pop-up ---
  void _showMessageOptions(Map<String, dynamic> message, String currentUserId) {
    final String messageId = message['id'] ?? '';
    final bool isMine = message['senderId'] == currentUserId;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Message options',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                ),
                const SizedBox(height: 4),
                Text(
                  message['message'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),

                // Delete for me
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.visibility_off, color: Color(0xFF1E3A8A)),
                  title: const Text('Delete for me'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _chatService.deleteForMe(messageId, currentUserId);
                  },
                ),

                // Delete for everyone (only if I sent it)
                if (isMine)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_forever, color: Color(0xFFEF4444)),
                    title: const Text('Delete for everyone',
                        style: TextStyle(color: Color(0xFFEF4444))),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _chatService.deleteForEveryone(messageId);
                    },
                  ),

                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Fetch the Agora Token using ApiConfig (now with uid) ---
  Future<String> _getAgoraToken(String channelName, int uid) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.agoraTokenEndpoint}?channel=$channelName&uid=$uid'),
    );
    final data = jsonDecode(response.body);
    return data['token'] as String;
  }

  // Start Voice Call
  void _startVoiceCall() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final String currentUserId = authProvider.user?.uid ?? '';
    final String channelName =
        _chatService.generateCallChannel(currentUserId, widget.chatWithId);

    final int myUid = _uidFromString(currentUserId);
    final token = await _getAgoraToken(channelName, myUid);

    final String callId = await _callService.startCall(
      callerId: currentUserId,
      receiverId: widget.chatWithId,
      channelName: channelName,
      callType: 'voice',
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VoiceCallScreen(
          channelName: channelName,
          callWithName: widget.chatWithName,
          token: token,
          callId: callId,
          uid: myUid,
        ),
      ),
    );
  }

  // Start Video Call
  void _startVideoCall() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final String currentUserId = authProvider.user?.uid ?? '';
    final String channelName =
        _chatService.generateCallChannel(currentUserId, widget.chatWithId);

    final int myUid = _uidFromString(currentUserId);
    final token = await _getAgoraToken(channelName, myUid);

    final String callId = await _callService.startCall(
      callerId: currentUserId,
      receiverId: widget.chatWithId,
      channelName: channelName,
      callType: 'video',
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoCallScreen(
          channelName: channelName,
          appId: AgoraConfig.appId,
          token: token,
          callId: callId,
          uid: myUid,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final String currentUserId = authProvider.user?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(widget.chatWithName),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.call), onPressed: _startVoiceCall),
          IconButton(icon: const Icon(Icons.videocam), onPressed: _startVideoCall),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _chatService.getMessages(
                user1: currentUserId,
                user2: widget.chatWithId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final bool isMe = message['senderId'] == currentUserId;

                    return GestureDetector(
                      onLongPress: () => _showMessageOptions(message, currentUserId),
                      child: Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMe ? const Color(0xFF1E3A8A) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            message['message'] ?? '',
                            style: TextStyle(
                              color: isMe ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF1E3A8A)),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}