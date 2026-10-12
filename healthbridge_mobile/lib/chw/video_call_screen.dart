import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/call_service.dart';
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
  static const int _ringTimeoutSeconds = 30;

  int? _remoteUid;
  bool _localUserJoined = false;
  RtcEngine? _engine;
  final CallService _callService = CallService();
  bool _callEnded = false;
  bool _joined = false;
  bool _needsSettings = false;
  String? _errorMessage;
  String? _endReason;
  String _status = 'Connecting…';
  Duration _callDuration = Duration.zero;

  Timer? _timer;
  Timer? _ringCountdown;
  int _ringSecondsLeft = _ringTimeoutSeconds;

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
      final reason = call['endReason'] as String?;

      if (status == 'ended' && !_callEnded) {
        if (widget.isCaller && _remoteUid == null) {
          setState(() {
            _endReason = reason == 'declined' ? 'declined' : 'no_answer';
            _status = _endReason == 'declined' ? 'Call declined' : 'No answer';
          });
          Future.delayed(const Duration(seconds: 2, milliseconds: 500), () {
            if (mounted) _cleanup();
          });
        } else {
          _cleanup();
        }
        return;
      }

      if (widget.isCaller && status == 'active' && !_joined) {
        _cancelRingCountdown();
        _joinChannel();
      }
    });

    if (widget.isCaller) {
      setState(() {
        _status = 'Ringing…';
        _ringSecondsLeft = _ringTimeoutSeconds;
      });
      _startRingCountdown();
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

  void _startRingCountdown() {
    _ringCountdown?.cancel();
    _ringCountdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_ringSecondsLeft <= 1) {
        t.cancel();
        _ringCountdown = null;
        _onRingTimeout();
      } else {
        setState(() => _ringSecondsLeft--);
      }
    });
  }

  void _cancelRingCountdown() {
    _ringCountdown?.cancel();
    _ringCountdown = null;
  }

  Future<void> _onRingTimeout() async {
    if (_callEnded || _remoteUid != null || _endReason != null) return;

    debugPrint('[Call] video ring timeout — no answer');
    _cancelRingCountdown();

    setState(() {
      _endReason = 'no_answer';
      _status = 'No answer';
    });

    await _callService.endCall(widget.callId, reason: 'no_answer');
    if (!mounted) return;

    await Future.delayed(const Duration(seconds: 2, milliseconds: 500));
    if (mounted) _cleanup();
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
              if (_status != 'Connected') _status = 'Ringing…';
            });
          },
          onUserJoined: (conn, remoteUid, elapsed) {
            debugPrint('[Agora] onUserJoined remoteUid=$remoteUid');
            if (!mounted) return;
            _cancelRingCountdown();
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

      await _engine!.enableVideo();
      await _engine!.enableAudio();
      await _engine!.setChannelProfile(
          ChannelProfileType.channelProfileCommunication);
      await _engine!.setClientRole(
          role: ClientRoleType.clientRoleBroadcaster);

      await _engine!.startPreview();
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
    if (_callEnded && !mounted) return;
    _callEnded = true;
    _timer?.cancel();
    _cancelRingCountdown();
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
    _cancelRingCountdown();
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

  String get _displayStatus {
    if (_endReason == 'declined') return 'Call declined';
    if (_endReason == 'no_answer') return 'No answer';
    if (_remoteUid != null) return _formatDuration(_callDuration);
    return _status;
  }

  bool get _isEndingState => _endReason != null;

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
          onPressed: _isEndingState ? null : _endCall,
        ),
      ),
      body: Stack(
        children: [
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
                        if (_errorMessage == null && !_isEndingState)
                          const CircularProgressIndicator(color: Colors.white)
                        else
                          const Icon(Icons.error_outline,
                              color: Color(0xFFEF4444), size: 48),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage ??
                              (_isEndingState ? _displayStatus : _status),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _errorMessage != null || _isEndingState
                                ? const Color(0xFFEF4444)
                                : Colors.white70,
                            fontSize: 15,
                          ),
                        ),
                        if (_isEndingState) ...[
                          const SizedBox(height: 8),
                          Text(
                            _endReason == 'declined'
                                ? '${widget.peerName} declined the call'
                                : '${widget.peerName} did not answer',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                        ],
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

          if (_localUserJoined && !_isEndingState)
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
                      _displayStatus,
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

          if (_engine != null && !_isEndingState)
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

          if (!_isEndingState)
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