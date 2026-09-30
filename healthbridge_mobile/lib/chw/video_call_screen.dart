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
  final int uid; // <--- NEW: unique per user

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

  // --- Call state ---
  Duration _callDuration = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    await [Permission.microphone, Permission.camera].request();

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: widget.appId));

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          if (!mounted) return;
          setState(() {
            _localUserJoined = true;
          });
          // Start call timer
          _timer?.cancel();
          _timer = Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted) {
              setState(() {
                _callDuration += const Duration(seconds: 1);
              });
            }
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          if (!mounted) return;
          setState(() {
            _remoteUid = remoteUid;
          });
        },
        onUserOffline: (
          RtcConnection connection,
          int remoteUid,
          UserOfflineReasonType reason,
        ) {
          // Remote peer hung up — end our side too
          _endCall();
        },
      ),
    );

    await _engine!.enableVideo();
    await _engine!.startPreview();
    await _engine!.joinChannel(
      token: widget.token,
      channelId: widget.channelName,
      uid: widget.uid, // <--- use the assigned uid
      options: const ChannelMediaOptions(),
    );
  }

  Future<void> _endCall() async {
    if (_callEnded) return;
    _callEnded = true;
    _timer?.cancel();
    await _callService.endCall(widget.callId);
    await _engine?.leaveChannel();
    await _engine?.release();
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
          // Remote Video View (full screen)
          Center(
            child: _remoteUid != null
                ? AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: _engine!,
                      canvas: VideoCanvas(uid: _remoteUid),
                    ),
                  )
                : const Center(
                    child: Text(
                      'Waiting for the other person to join...',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),
          ),

          // Call timer at the top
          if (_localUserJoined)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 60),
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

          // Local Video View (small preview top-right)
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _localUserJoined
                  ? Container(
                      width: 120,
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AgoraVideoView(
                          controller: VideoViewController(
                            rtcEngine: _engine!,
                            canvas: VideoCanvas(uid: widget.uid), // <--- own uid
                          ),
                        ),
                      ),
                    )
                  : const SizedBox(),
            ),
          ),

          // End Call Button (bottom center)
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