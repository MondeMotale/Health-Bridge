import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';
import '../services/call_service.dart';
import '../config/agora_config.dart';
import '../utils/constants.dart';
import '../main.dart' show navigatorKey;
import '../chw/voice_call_screen.dart';
import '../chw/video_call_screen.dart';
import 'incoming_call_banner.dart';
import 'incoming_video_call_overlay.dart';

class GlobalCallListener extends StatefulWidget {
  final Widget child;

  const GlobalCallListener({super.key, required this.child});

  @override
  State<GlobalCallListener> createState() => GlobalCallListenerState();
}

class GlobalCallListenerState extends State<GlobalCallListener> {
  final CallService _callService = CallService();

  Map<String, dynamic>? _activeCall;
  String _callerName = 'Unknown';
  String? _handledCallId;

  bool _launchingOutgoing = false;

  static int _uidFromString(String firebaseUid) {
    return firebaseUid.hashCode.abs() % 1000000000 + 1;
  }

  Future<String> _getAgoraToken(String channelName, int uid) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.agoraTokenEndpoint}?channel=$channelName&uid=$uid'),
    );
    if (response.statusCode != 200) {
      throw Exception('Token server returned ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    final token = data['token'];
    if (token is! String || token.isEmpty) {
      throw Exception('Token server returned no token');
    }
    return token;
  }

  // ============================================================
  // LAUNCH AN OUTGOING CALL — called from chat screen.
  // ============================================================
  Future<void> launchOutgoingCall({
    required BuildContext context,
    required String receiverId,
    required String receiverName,
    required String callType,
  }) async {
    if (_launchingOutgoing) return;
    _launchingOutgoing = true;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final callerId = authProvider.user?.uid ?? '';
      if (callerId.isEmpty) return;

      final myUid = _uidFromString(callerId);
      final channelName = 'call_${callerId}_$receiverId';

      final String callId;
      try {
        callId = await _callService.startCall(
          callerId: callerId,
          receiverId: receiverId,
          channelName: channelName,
          callType: callType,
        );
      } catch (e) {
        debugPrint('[Call] startCall failed: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not start call: $e')),
          );
        }
        return;
      }

      String token;
      try {
        token = await _getAgoraToken(channelName, myUid);
      } catch (e) {
        debugPrint('[Call] token fetch failed: $e');
        await _callService.endCall(callId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not reach the call service')),
          );
        }
        return;
      }

      final nav = navigatorKey.currentState;
      if (nav == null) {
        debugPrint('[Call] navigatorKey has no state — cannot push');
        return;
      }

      if (callType == 'video') {
        nav.push(MaterialPageRoute(
          fullscreenDialog: true,
          maintainState: true,
          builder: (_) => VideoCallScreen(
            channelName: channelName,
            appId: AgoraConfig.appId,
            token: token,
            callId: callId,
            uid: myUid,
            isCaller: true,
            peerName: receiverName,
          ),
        ));
      } else {
        nav.push(MaterialPageRoute(
          fullscreenDialog: true,
          maintainState: true,
          builder: (_) => VoiceCallScreen(
            channelName: channelName,
            callWithName: receiverName,
            token: token,
            callId: callId,
            uid: myUid,
            isCaller: true,
          ),
        ));
      }
    } finally {
      _launchingOutgoing = false;
    }
  }

  // ============================================================
  // INCOMING CALL — receiver taps Accept
  // ============================================================
  void _acceptVoice(Map<String, dynamic> call) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final myUid = _uidFromString(authProvider.user?.uid ?? '');
    final callId = call['callId'] as String;
    final channelName = call['channelName'] as String;

    setState(() {
      _activeCall = null;
      _handledCallId = callId;
    });

    final nav = navigatorKey.currentState;
    if (nav == null) {
      debugPrint('[Call] navigatorKey has no state — cannot push');
      return;
    }

    nav.push(MaterialPageRoute(
      fullscreenDialog: true,
      maintainState: true,
      builder: (_) => VoiceCallScreen(
        channelName: channelName,
        callWithName: _callerName,
        token: '',
        callId: callId,
        uid: myUid,
        isCaller: false,
      ),
    ));
  }

  void _acceptVideo(Map<String, dynamic> call) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final myUid = _uidFromString(authProvider.user?.uid ?? '');
    final callId = call['callId'] as String;
    final channelName = call['channelName'] as String;

    setState(() {
      _activeCall = null;
      _handledCallId = callId;
    });

    final nav = navigatorKey.currentState;
    if (nav == null) {
      debugPrint('[Call] navigatorKey has no state — cannot push');
      return;
    }

    nav.push(MaterialPageRoute(
      fullscreenDialog: true,
      maintainState: true,
      builder: (_) => VideoCallScreen(
        channelName: channelName,
        appId: AgoraConfig.appId,
        token: '',
        callId: callId,
        uid: myUid,
        isCaller: false,
        peerName: _callerName,
      ),
    ));
  }

  Future<void> _declineCall(Map<String, dynamic> call) async {
    try {
      await _callService.endCall(call['callId']);
    } catch (_) {}
    setState(() {
      _activeCall = null;
      _handledCallId = call['callId'];
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final uid = authProvider.user?.uid ?? '';

    if (uid.isEmpty) {
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        StreamBuilder<Map<String, dynamic>?>(
          stream: _callService.listenForIncomingCalls(uid),
          builder: (context, snapshot) {
            final call = snapshot.data;

            if (call == null || call['callId'] == _handledCallId) {
              if (_activeCall != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _activeCall = null);
                });
              }
              return const SizedBox.shrink();
            }

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
    );
  }
}