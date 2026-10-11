import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/auth_provider.dart';
import '../../services/call_service.dart';
import '../../services/emergency_service.dart';
import '../../models/emergency_alert.dart';
import '../../config/agora_config.dart';
import '../../utils/constants.dart';
import '../../widgets/incoming_call_banner.dart';
import '../../widgets/incoming_video_call_overlay.dart';
import '../../widgets/emergency_alert_banner.dart';
import 'voice_call_screen.dart';
import 'video_call_screen.dart';
import 'emergency_alert_detail_screen.dart';

// Import your pages
import 'home_screen.dart';
import 'patients_screen.dart';
import 'messages_screen.dart';
import 'appointments_screen.dart';
import 'profile_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final CallService _callService = CallService();
  final EmergencyService _emergencyService = EmergencyService();

  Map<String, dynamic>? _activeCall;
  String _callerName = 'Unknown';
  String? _handledCallId;

  // Track which emergency alert IDs we've already opened the detail
  // screen for, so we don't push it twice.
  final Set<String> _openedAlertIds = {};

  final List<Widget> _pages = [
    HomeScreen(),
    PatientsScreen(),
    MessagesScreen(),
    AppointmentsScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

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

  // --- ACCEPT VOICE ---
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

  // --- ACCEPT VIDEO ---
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

  // --- DECLINE ---
  Future<void> _declineCall(Map<String, dynamic> call) async {
    await _callService.endCall(call['callId']);
    setState(() {
      _activeCall = null;
      _handledCallId = call['callId'];
    });
  }

  // --- OPEN EMERGENCY DETAIL ---
  void _openEmergencyDetail(EmergencyAlert alert, String chwName) {
    if (_openedAlertIds.contains(alert.id)) return;
    _openedAlertIds.add(alert.id);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmergencyAlertDetailScreen(
          alertId: alert.id,
          chwName: chwName,
        ),
      ),
    ).then((_) {
      _openedAlertIds.remove(alert.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    if (authProvider.user == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    final String myUid = authProvider.user?.uid ?? '';
    final String myName = authProvider.user?.displayName ?? 'CHW';

    // CHECK USER ROLE (Security check)
    return FutureBuilder<String>(
      future: authProvider.getCurrentRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final role = snapshot.data ?? 'none';

        if (role == 'patient') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, '/patient_home');
          });
          return const Scaffold(body: Center(child: Text('Redirecting...')));
        }

        // ---- CHW / Admin view ----
        return Scaffold(
          body: Stack(
            children: [
              _pages[_selectedIndex],

              // ---- Emergency alert banner ----
              StreamBuilder<List<EmergencyAlert>>(
                stream: _emergencyService.watchActiveAlertsForChw(myUid),
                builder: (context, alertSnapshot) {
                  final alerts = alertSnapshot.data ?? [];
                  if (alerts.isEmpty) return const SizedBox.shrink();

                  // Show the newest alert
                  final alert = alerts.first;

                  return EmergencyAlertBanner(
                    patientName: alert.patientName,
                    timeSince: alert.timeSinceCreated,
                    onTap: () => _openEmergencyDetail(alert, myName),
                  );
                },
              ),

              // ---- Global incoming-call listener ----
              StreamBuilder<Map<String, dynamic>?>(
                stream: _callService.listenForIncomingCalls(myUid),
                builder: (context, callSnapshot) {
                  final call = callSnapshot.data;

                  // No call / already handled
                  if (call == null || call['callId'] == _handledCallId) {
                    if (_activeCall != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _activeCall = null);
                      });
                    }
                    return const SizedBox.shrink();
                  }

                  // New call → fetch caller name once
                  if (_activeCall == null ||
                      _activeCall!['callId'] != call['callId']) {
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      final name = await _callService
                          .getCallerName(call['callerId']);
                      if (mounted) {
                        setState(() {
                          _activeCall = call;
                          _callerName = name;
                        });
                      }
                    });
                    return const SizedBox.shrink();
                  }

                  // Render UI based on call type
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
            onTap: _onItemTapped,
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
                icon: Icon(Icons.people_outline),
                activeIcon: Icon(Icons.people),
                label: 'Patients',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.chat_bubble_outline),
                activeIcon: Icon(Icons.chat_bubble),
                label: 'Messages',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today_outlined),
                activeIcon: Icon(Icons.calendar_today),
                label: 'Appointments',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}