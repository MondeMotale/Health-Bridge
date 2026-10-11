import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../config/agora_config.dart';
import '../../services/call_service.dart';

class VoiceCallScreen extends StatefulWidget {
  final String channelName;
  final String callWithName;
  final String token;
  final String callId;
  final int uid;

  const VoiceCallScreen({
    super.key,
    required this.channelName,
    required this.callWithName,
    required this.token,
    required this.callId,
    required this.uid,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  RtcEngine? _engine;
  bool _isMuted = false;
  final CallService _callService = CallService();
  bool _callEnded = false;

  bool _connected = false;
  bool _remoteJoined = false;
  String? _errorMessage;
  Duration _callDuration = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    try {
      // 1. Ask for microphone permission
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        if (mounted) {
          setState(() => _errorMessage =
              'Microphone permission required. Enable it in your browser/OS settings.');
        }
        return;
      }

      // 2. Create the engine
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: AgoraConfig.appId,
        // Logging — helps you debug in the terminal
        logConfig: const LogConfig(level: LogLevel.logLevelInfo),
      ));

      // 3. Register event handlers BEFORE join
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint('[Agora] onJoinChannelSuccess uid=${connection.localUid}');
            if (!mounted) return;
            setState(() => _connected = true);
            _startTimer();
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint('[Agora] onUserJoined remoteUid=$remoteUid');
            if (!mounted) return;
            setState(() => _remoteJoined = true);
          },
          onUserOffline: (
            RtcConnection connection,
            int remoteUid,
            UserOfflineReasonType reason,
          ) {
            debugPrint('[Agora] onUserOffline remoteUid=$remoteUid');
            _endCall();
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint('[Agora] onError: $err — $msg');
            if (mounted) {
              setState(() => _errorMessage = '$err — $msg');
            }
          },
          onLeaveChannel: (RtcConnection connection, RtcStats stats) {
            debugPrint('[Agora] onLeaveChannel');
          },
        ),
      );

      // 4. Configure the channel — audio-only communication
      await _engine!.enableAudio();
      await _engine!.setChannelProfile(
        ChannelProfileType.channelProfileCommunication,
      );
      // CRITICAL: set the client role to broadcaster so we actually publish
      await _engine!.setClientRole(
        role: ClientRoleType.clientRoleBroadcaster,
      );
      // Route audio through the speaker by default
      await _engine!.setDefaultAudioRouteToSpeakerphone(true);

      // 5. Join the channel
      debugPrint('[Agora] joinChannel: channel=${widget.channelName} uid=${widget.uid}');
      await _engine!.joinChannel(
        token: widget.token,
        channelId: widget.channelName,
        uid: widget.uid,
        options: const ChannelMediaOptions(
          // Explicitly publish our microphone
          publishMicrophoneTrack: true,
          // Explicitly subscribe to remote audio
          autoSubscribeAudio: true,
          autoSubscribeVideo: false,
          publishCameraTrack: false,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      debugPrint('[Agora] init error: $e');
      if (mounted) {
        setState(() => _errorMessage = 'Failed to start call: $e');
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _callDuration += const Duration(seconds: 1));
      }
    });
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _engine?.muteLocalAudioStream(_isMuted);
  }

  Future<void> _endCall() async {
    if (_callEnded) return;
    _callEnded = true;
    _timer?.cancel();
    await _callService.endCall(widget.callId);
    await _engine?.leaveChannel();
    await _engine?.release();
    _engine = null;
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (!_callEnded) {
      _callService.endCall(widget.callId);
    }
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: const Color(0xFF1E3A8A),
                child: Text(
                  widget.callWithName.isNotEmpty
                      ? widget.callWithName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.callWithName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage != null
                    ? 'Call failed'
                    : !_connected
                        ? 'Connecting…'
                        : !_remoteJoined
                            ? 'Ringing…'
                            : _formatDuration(_callDuration),
                style: TextStyle(
                  color: _errorMessage != null
                      ? const Color(0xFFEF4444)
                      : Colors.white70,
                  fontSize: 16,
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
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
                      child: const Icon(
                        Icons.call_end,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}