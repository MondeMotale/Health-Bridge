import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../config/agora_config.dart';
import '../../services/call_service.dart';
import '../../utils/constants.dart';

class VoiceCallScreen extends StatefulWidget {
  final String channelName;
  final String callWithName;
  final String token;
  final String callId;
  final int uid;
  final bool isCaller;

  const VoiceCallScreen({
    super.key,
    required this.channelName,
    required this.callWithName,
    required this.token,
    required this.callId,
    required this.uid,
    required this.isCaller,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  static const int _ringTimeoutSeconds = 30;

  RtcEngine? _engine;
  bool _isMuted = false;
  final CallService _callService = CallService();
  bool _callEnded = false;
  bool _joined = false;
  bool _needsSettings = false;

  bool _remoteJoined = false;
  String? _errorMessage;
  String? _endReason; // 'no_answer' | 'declined' | null
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
    // Watch call status — pop if ended remotely.
    _callSub = _callService.watchCall(widget.callId).listen((call) {
      if (call == null) return;
      final status = call['status'];
      final reason = call['endReason'] as String?;

      if (status == 'ended' && !_callEnded) {
        if (widget.isCaller && !_remoteJoined) {
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

    // Receiver: fetch token, answer Firestore, then join.
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
    if (_callEnded || _remoteJoined || _endReason != null) return;

    debugPrint('[Call] ring timeout — no answer');
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
    if (!micStatus.isGranted) {
      if (mounted) {
        setState(() {
          _errorMessage = micStatus.isPermanentlyDenied
              ? 'Microphone permission permanently denied. Enable in Settings.'
              : 'Microphone permission is required.';
          _needsSettings = micStatus.isPermanentlyDenied;
        });
      }
      return;
    }

    try {
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: AgoraConfig.appId,
        logConfig: const LogConfig(level: LogLevel.logLevelInfo),
      ));

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (conn, elapsed) {
            debugPrint('[Agora] joined uid=${conn.localUid}');
            if (mounted && _status != 'Connected') {
              setState(() => _status = 'Ringing…');
            }
          },
          onUserJoined: (conn, remoteUid, elapsed) {
            debugPrint('[Agora] onUserJoined remoteUid=$remoteUid');
            if (!mounted) return;
            _cancelRingCountdown();
            setState(() {
              _remoteJoined = true;
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

      await _engine!.enableAudio();
      await _engine!.setChannelProfile(
          ChannelProfileType.channelProfileCommunication);
      await _engine!.setClientRole(
          role: ClientRoleType.clientRoleBroadcaster);

      if (!kIsWeb) {
        try {
          await _engine!.setDefaultAudioRouteToSpeakerphone(true);
        } catch (_) {}
      }

      await _engine!.joinChannel(
        token: _token,
        channelId: widget.channelName,
        uid: widget.uid,
        options: const ChannelMediaOptions(
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: false,
          publishCameraTrack: false,
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

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _engine?.muteLocalAudioStream(_isMuted);
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
    if (_errorMessage != null) return 'Call failed';
    if (_remoteJoined) return _formatDuration(_callDuration);
    return _status;
  }

  bool get _isEndingState => _endReason != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Voice Call'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.call_end, color: Colors.red),
          onPressed: _isEndingState ? null : _endCall,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: _isEndingState
                    ? const Color(0xFF6B7280)
                    : const Color(0xFF1E3A8A),
                child: Text(
                  widget.callWithName.isNotEmpty
                      ? widget.callWithName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.callWithName,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                _displayStatus,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _errorMessage != null || _isEndingState
                      ? const Color(0xFFEF4444)
                      : Colors.white70,
                  fontSize: 16,
                ),
              ),
              if (_isEndingState) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _endReason == 'declined'
                        ? '${widget.callWithName} declined the call'
                        : '${widget.callWithName} did not answer',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13)),
                ),
                if (_needsSettings)
                  TextButton(
                    onPressed: () => openAppSettings(),
                    child: const Text('Open Settings',
                        style: TextStyle(color: Colors.white)),
                  ),
              ],
              const SizedBox(height: 40),
              if (!_isEndingState)
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
                        child: const Icon(Icons.call_end,
                            color: Colors.white, size: 32),
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