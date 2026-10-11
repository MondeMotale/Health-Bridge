import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/call_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String channelName;
  final String appId;
  final String token;
  final String callId;
  final int uid;

  const VideoCallScreen({
    super.key,
    required this.channelName,
    required this.appId,
    required this.token,
    required this.callId,
    required this.uid,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  int? _remoteUid;
  bool _localUserJoined = false;
  RtcEngine? _engine;
  final CallService _callService = CallService();
  bool _callEnded = false;
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
      final perms = await [Permission.microphone, Permission.camera].request();
      final micOk = perms[Permission.microphone]?.isGranted ?? false;
      final camOk = perms[Permission.camera]?.isGranted ?? false;
      if (!micOk || !camOk) {
        if (mounted) {
          setState(() => _errorMessage =
              'Microphone and camera permissions are required.');
        }
        return;
      }

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: widget.appId,
        logConfig: const LogConfig(level: LogLevel.logLevelInfo),
      ));

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint('[Agora] joined uid=${connection.localUid}');
            if (!mounted) return;
            setState(() => _localUserJoined = true);
            _timer?.cancel();
            _timer = Timer.periodic(const Duration(seconds: 1), (_) {
              if (mounted) {
                setState(() =>
                    _callDuration += const Duration(seconds: 1));
              }
            });
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint('[Agora] remote joined: $remoteUid');
            if (!mounted) return;
            setState(() => _remoteUid = remoteUid);
          },
          onUserOffline: (
            RtcConnection connection,
            int remoteUid,
            UserOfflineReasonType reason,
          ) {
            debugPrint('[Agora] remote left: $remoteUid');
            _endCall();
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint('[Agora] error: $err — $msg');
            if (mounted) setState(() => _errorMessage = '$err — $msg');
          },
        ),
      );

      // Configure for video 1:1
      await _engine!.enableVideo();
      await _engine!.enableAudio();
      await _engine!.setChannelProfile(
        ChannelProfileType.channelProfileCommunication,
      );
      await _engine!.setClientRole(
        role: ClientRoleType.clientRoleBroadcaster,
      );

      // Start local preview BEFORE joining so we see ourselves immediately
      await _engine!.startPreview();

      await _engine!.joinChannel(
        token: widget.token,
        channelId: widget.channelName,
        uid: widget.uid,
        options: const ChannelMediaOptions(
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      debugPrint('[Agora] init error: $e');
      if (mounted) setState(() => _errorMessage = 'Failed: $e');
    }
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Video Call'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.call_end, color: Colors.red),
          onPressed: _endCall,
        ),
      ),
      body: Stack(
        children: [
          // Remote video — full screen
          Positioned.fill(
            child: _remoteUid != null
                ? AgoraVideoView(
                    controller: VideoViewController.remote(
                      rtcEngine: _engine!,
                      canvas: VideoCanvas(uid: _remoteUid),
                      connection: RtcConnection(channelId: widget.channelName),
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage ??
                              'Waiting for the other person to join…',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _errorMessage != null
                                ? const Color(0xFFEF4444)
                                : Colors.white70,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          // Call duration — top center
          if (_localUserJoined)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _formatDuration(_callDuration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Local preview — top right
          if (_localUserJoined)
            Positioned(
              top: 70,
              right: 16,
              child: GestureDetector(
                onTap: () {
                  // Toggle camera on/off when tapped
                  _engine?.muteLocalVideoStream(false);
                },
                child: Container(
                  width: 110,
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                    color: Colors.black,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: _engine!,
                        canvas: const VideoCanvas(uid: 0),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // End button — bottom center
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: GestureDetector(
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
            ),
          ),
        ],
      ),
    );
  }
}