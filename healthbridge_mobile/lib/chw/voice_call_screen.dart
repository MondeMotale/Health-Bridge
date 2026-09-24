import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../config/agora_config.dart';
import '../../services/call_service.dart';

class VoiceCallScreen extends StatefulWidget {
  final String channelName;
  final String callWithName;
  final String token;
  final String callId; // <--- NEW

  const VoiceCallScreen({
    super.key,
    required this.channelName,
    required this.callWithName,
    required this.token,
    required this.callId,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  RtcEngine? _engine;
  bool _isMuted = false;
  final CallService _callService = CallService();
  bool _callEnded = false;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    await [Permission.microphone].request();

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: AgoraConfig.appId));

    await _engine!.enableAudio();
    await _engine!.setChannelProfile(ChannelProfileType.channelProfileCommunication);

    await _engine!.joinChannel(
      token: widget.token,
      channelId: widget.channelName,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _engine!.muteLocalAudioStream(_isMuted);
  }

  Future<void> _endCall() async {
    if (_callEnded) return;
    _callEnded = true;
    await _callService.endCall(widget.callId);
    await _engine?.leaveChannel();
    await _engine?.release();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    if (!_callEnded) {
      _callService.endCall(widget.callId);
    }
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Voice Call'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: const Color(0xFF1E3A8A),
              child: Text(
                widget.callWithName.isNotEmpty ? widget.callWithName[0] : '?',
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.callWithName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connecting...',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 40),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _toggleMute,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _isMuted ? Colors.white : Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isMuted ? Icons.mic_off : Icons.mic,
                      color: _isMuted ? Colors.black : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 30),

                GestureDetector(
                  onTap: _endCall,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call_end, color: Colors.white, size: 32),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}