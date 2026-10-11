import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/auth_provider.dart';
import '../../services/call_service.dart';
import '../../config/agora_config.dart';
import '../../utils/constants.dart';
import '../../widgets/incoming_call_banner.dart';
import '../../widgets/incoming_video_call_overlay.dart';
import '../chw/voice_call_screen.dart';
import '../chw/video_call_screen.dart';
import 'patient_home_screen.dart';
import 'patient_appointments_screen.dart';
import 'patient_resources_screen.dart';
import 'patient_messages_screen.dart';
import 'patient_profile_screen.dart';

class PatientMainNavigation extends StatefulWidget {
  const PatientMainNavigation({super.key});

  @override
  State<PatientMainNavigation> createState() => _PatientMainNavigationState();
}

class _PatientMainNavigationState extends State<PatientMainNavigation> {
  int _selectedIndex = 0;

  final CallService _callService = CallService();

  Map<String, dynamic>? _activeCall;
  String _callerName = 'Unknown';
  String? _handledCallId;

  final List<Widget> _pages = [
    const PatientHomeScreen(),
    const PatientAppointmentsScreen(),
    const PatientResourcesScreen(),
    const PatientMessagesScreen(),
    const PatientProfileScreen(),
  ];

  int _uidFromString(String firebaseUid) {
    return firebaseUid.hashCode.abs() % 1000000000 + 1;
  }

  Future<String> _getAgoraToken(String channelName, int uid) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.agoraTokenEndpoint}?channel=$channelName&uid=$uid'),
    );
    final data = jsonDecode(response.body);
    return data['token'] as String;
  }

  Future<void> _acceptVoice(Map<String, dynamic> call) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final myUid = _uidFromString(authProvider.user?.uid ?? '');

    final token = await _getAgoraToken(call['channelName'], myUid);
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
          uid: myUid,
        ),
      ),
    );
  }

  Future<void> _acceptVideo(Map<String, dynamic> call) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final myUid = _uidFromString(authProvider.user?.uid ?? '');

    final token = await _getAgoraToken(call['channelName'], myUid);
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
          uid: myUid,
        ),
      ),
    );
  }

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
    final String patientUid = authProvider.user?.uid ?? '';

    if (authProvider.user == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    PatientHomeScreen.bottomNavCallback = (index) {
      if (mounted) {
        setState(() => _selectedIndex = index);
      }
    };

    return Scaffold(
      body: Stack(
        children: [
          _pages[_selectedIndex],

          // Global incoming-call listener only (SOS banner removed)
          StreamBuilder<Map<String, dynamic>?>(
            stream: _callService.listenForIncomingCalls(patientUid),
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
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1E3A8A),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Appointments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medical_services_outlined),
            activeIcon: Icon(Icons.medical_services),
            label: 'Resources',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}