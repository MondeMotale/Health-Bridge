import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/call_service.dart';
import '../../config/agora_config.dart';
import '../../utils/constants.dart';

class VideoCallScreen extends StatefulWidget {
  final String channelName;
  final String appId;
  final String token;
  final String callId;
  final int uid;
  final bool isCaller;
  final String peerName;

  const VideoCallScreen({
    super.key,
    required this.channelName,
    required this.appId,
    required this.token,
    required this.callId,
    required this.uid,
    required this.isCaller,
    required this.peerName,
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
  bool _joined = false;
  bool _needsSettings = false;
  String? _errorMessage;
  String _status = 'Connecting…';
  Duration _callDuration = Duration.zero;
  Timer? _timer;
  StreamSubscription<Map<String, dynamic>?>? _callSub;
  String _token = '';

  @override
  void initState() {
    super.initState();
    _token = widget.token;
    _boot();
  }

  Future<String> _fetchToken() async {
    final res = await http.get(
      Uri.parse(
        '${ApiConfig.agoraTokenEndpoint}?channel=${widget.channelName}&uid=${widget.uid}',
      ),
    );
    if (res.statusCode != 200) {
      throw Exception('Token server returned ${res.statusCode}');
    }
    final data = jsonDecode(res.body);
    final t = data['token'];
    if (t is! String || t.isEmpty) throw Exception('No token');
    return t;
  }

  Future<void> _boot() async {
    _callSub = _callService.watchCall(widget.callId).listen((call) {
      if (call == null) return;
      final status = call['status'];
      if (status == 'ended' && !_callEnded) {
        _cleanup();
      }
      if (widget.isCaller && status == 'active' && !_joined) {
        _joinChannel();
      }
    });

    if (widget.isCaller) {
      setState(() => _status = 'Ringing…');
      return;
    }

    setState(() => _status = 'Connecting…');

    try {
      if (_token.isEmpty) {
        _token = await _fetchToken();
      }
      await _callService.answerCall(widget.callId);
    } catch (e) {
      debugPrint('[Call] receiver setup failed: $e');
      if (mounted) setState(() => _errorMessage = 'Failed to connect: $e');
      return;
    }

    if (!mounted) return;
    await _joinChannel();
  }

  Future<void> _joinChannel() async {
    if (_joined || _callEnded) return;
    _joined = true;

    if (_token.isEmpty) {
      try {
        _token = await _fetchToken();
      } catch (e) {
        if (mounted) {
          setState(() => _errorMessage = 'Could not fetch token: $e');
        }
        return;
      }
    }

    // Request both permissions.
    final micStatus = await Permission.microphone.request();
    final camStatus = await Permission.camera.request();

    if (!micStatus.isGranted || !camStatus.isGranted) {
      final permDenied =
          micStatus.isPermanentlyDenied || camStatus.isPermanentlyDenied;
      if (mounted) {
        setState(() {
          _errorMessage = permDenied
              ? 'Camera / mic permission permanently denied. Enable in Settings.'
              : 'Camera and microphone permissions are required.';
          _needsSettings = permDenied;
        });
      }
      return;
    }

    try {
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: widget.appId,
        logConfig: const LogConfig(level: LogLevel.logLevelInfo),
      ));

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (conn, elapsed) {
            debugPrint('[Agora] joined uid=${conn.localUid}');
            if (!mounted) return;
            setState(() {
              _localUserJoined = true;
              _status = 'Ringing…';
            });
          },
          onUserJoined: (conn, remoteUid, elapsed) {
            debugPrint('[Agora] onUserJoined remoteUid=$remoteUid');
            if (!mounted) return;
            setState(() {
              _remoteUid = remoteUid;
              _status = 'Connected';
            });
            _startTimer();
          },
          onUserOffline: (conn, remoteUid, reason) {
            debugPrint('[Agora] onUserOffline remoteUid=$remoteUid');
            _endCall();
          },
          onError: (err, msg) {
            debugPrint('[Agora] error $err — $msg');
            if (mounted) setState(() => _errorMessage = '$err — $msg');
          },
        ),
      );

      // Enable video + audio, then start preview BEFORE joining so
      // the local view renders immediately.
      await _engine!.enableVideo();
      await _engine!.enableAudio();
      await _engine!.setChannelProfile(
          ChannelProfileType.channelProfileCommunication);
      await _engine!.setClientRole(
          role: ClientRoleType.clientRoleBroadcaster);

      // Start preview — this triggers the camera to come on.
      await _engine!.startPreview();

      // The engine is now running — force a rebuild so the local view
      // mounts and can bind to the camera track.
      if (mounted) setState(() {});

      await _engine!.joinChannel(
        token: _token,
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

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _callDuration += const Duration(seconds: 1));
      }
    });
  }

  Future<void> _endCall() async {
    if (_callEnded) return;
    _callEnded = true;
    await _callService.endCall(widget.callId);
    await _cleanup();
  }

  Future<void> _cleanup() async {
    _callEnded = true;
    _timer?.cancel();
    try {
      await _engine?.leaveChannel();
    } catch (_) {}
    try {
      await _engine?.release();
    } catch (_) {}
    _engine = null;
    if (mounted) {
      final nav = Navigator.of(context);
      if (nav.canPop()) nav.pop();
    }
  }

  @override
  void dispose() {
    _callSub?.cancel();
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
        title: Text('Video Call • ${widget.peerName}'),
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
                        if (_errorMessage == null)
                          const CircularProgressIndicator(color: Colors.white)
                        else
                          const Icon(Icons.error_outline,
                              color: Color(0xFFEF4444), size: 48),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage ?? _status,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _errorMessage != null
                                ? const Color(0xFFEF4444)
                                : Colors.white70,
                            fontSize: 15,
                          ),
                        ),
                        if (_needsSettings) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => openAppSettings(),
                            child: const Text(
                              'Open Settings',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),

          // Status / timer — top center
          if (_localUserJoined)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _remoteUid != null
                          ? _formatDuration(_callDuration)
                          : _status,
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

          // Local preview — render as soon as the engine exists.
          // This makes the receiver's camera come on immediately.
          if (_engine != null)
            Positioned(
              top: 70,
              right: 16,
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
                      canvas: VideoCanvas(uid: widget.uid),
                    ),
                  ),
                ),
              ),
            ),

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