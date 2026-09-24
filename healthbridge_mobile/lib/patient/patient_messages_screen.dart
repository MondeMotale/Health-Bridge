import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';
import '../../services/call_service.dart';
import '../../auth/auth_provider.dart';
import '../../config/agora_config.dart';
import '../../utils/constants.dart';
import '../../widgets/incoming_call_banner.dart';
import '../../widgets/incoming_video_call_overlay.dart';
import '../chw/chat_screen.dart';
import '../chw/video_call_screen.dart';
import '../chw/voice_call_screen.dart';

class PatientMessagesScreen extends StatefulWidget {
  const PatientMessagesScreen({super.key});

  @override
  State<PatientMessagesScreen> createState() => _PatientMessagesScreenState();
}

class _PatientMessagesScreenState extends State<PatientMessagesScreen> {
  final CallService _callService = CallService();

  Map<String, dynamic>? _activeCall;
  String _callerName = 'Unknown';
  String? _handledCallId;

  // --- Fetch the Agora Token using ApiConfig ---
  Future<String> _getAgoraToken(String channelName) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.agoraTokenEndpoint}?channel=$channelName'),
    );
    final data = jsonDecode(response.body);
    return data['token'] as String;
  }

  // --- ACCEPT VOICE ---
  Future<void> _acceptVoice(Map<String, dynamic> call) async {
    final token = await _getAgoraToken(call['channelName']);
    await _callService.answerCall(call['callId']);

    setState(() {
      _activeCall = null;
      _handledCallId = call['callId'];
    });

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VoiceCallScreen(
          channelName: call['channelName'],
          callWithName: _callerName,
          token: token,
          callId: call['callId'],
        ),
      ),
    );
  }

  // --- ACCEPT VIDEO ---
  Future<void> _acceptVideo(Map<String, dynamic> call) async {
    final token = await _getAgoraToken(call['channelName']);
    await _callService.answerCall(call['callId']);

    setState(() {
      _activeCall = null;
      _handledCallId = call['callId'];
    });

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          channelName: call['channelName'],
          appId: AgoraConfig.appId,
          token: token,
          callId: call['callId'],
        ),
      ),
    );
  }

  // --- DECLINE ---
  Future<void> _declineCall(Map<String, dynamic> call) async {
    await _callService.endCall(call['callId']);
    setState(() {
      _activeCall = null;
      _handledCallId = call['callId'];
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final String? patientUid = authProvider.user?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Messages & Contacts'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: patientUid == null
          ? const Center(child: Text('User not logged in'))
          : Stack(
              children: [
                _buildEmergencyAndChats(patientUid),

                // --- Listen for incoming calls ---
                StreamBuilder<Map<String, dynamic>?>(
                  stream: _callService.listenForIncomingCalls(patientUid),
                  builder: (context, snapshot) {
                    final call = snapshot.data;

                    // No call, or already handled → clear UI
                    if (call == null || call['callId'] == _handledCallId) {
                      if (_activeCall != null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _activeCall = null);
                        });
                      }
                      return const SizedBox.shrink();
                    }

                    // New call arrived → fetch the caller name once
                    if (_activeCall == null ||
                        _activeCall!['callId'] != call['callId']) {
                      WidgetsBinding.instance.addPostFrameCallback((_) async {
                        final name =
                            await _callService.getCallerName(call['callerId']);
                        if (mounted) {
                          setState(() {
                            _activeCall = call;
                            _callerName = name;
                          });
                        }
                      });
                      return const SizedBox.shrink();
                    }

                    // Render the correct UI based on callType
                    final callType = call['callType'] ?? 'voice';
                    if (callType == 'video') {
                      return IncomingVideoCallOverlay(
                        callerName: _callerName,
                        onAccept: () => _acceptVideo(call),
                        onDecline: () => _declineCall(call),
                      );
                    } else {
                      return IncomingCallBanner(
                        callerName: _callerName,
                        onAccept: () => _acceptVoice(call),
                        onDecline: () => _declineCall(call),
                      );
                    }
                  },
                ),
              ],
            ),
    );
  }

  // --- EXISTING UI (unchanged) ---
  Widget _buildEmergencyAndChats(String patientUid) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirestoreService().getAssignedChw(patientUid),
      builder: (context, chwSnapshot) {
        if (chwSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final chwList = chwSnapshot.data ?? [];

        return SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 20, bottom: 24, left: 20, right: 20),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E3A8A),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🚨 Emergency Contact',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white,
                          child: Text('EC',
                              style: TextStyle(
                                  color: Color(0xFF1E3A8A),
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Emergency Services',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Available 24/7 • 10111',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.phone,
                              color: Color(0xFF1E3A8A), size: 24),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '💬 Your CHW',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E)),
                    ),
                    const SizedBox(height: 16),
                    if (chwList.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No CHW assigned to you yet.'),
                        ),
                      )
                    else
                      ...chwList.map((chw) => _buildChwCard(chw)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChwCard(Map<String, dynamic> chw) {
    final String chwName = chw['displayName'] ?? 'CHW';
    final String chwUid = chw['uid'] ?? '';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatWithId: chwUid,
              chatWithName: chwName,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
              child: Text(
                chwName.isNotEmpty ? chwName[0] : '?',
                style: const TextStyle(
                  color: Color(0xFF1E3A8A),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chwName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Community Health Worker',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}