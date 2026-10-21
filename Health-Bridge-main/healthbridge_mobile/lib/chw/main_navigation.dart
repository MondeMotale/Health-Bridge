import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/auth_provider.dart';
import '../../services/emergency_service.dart';
import '../../models/emergency_alert.dart';
import '../../widgets/emergency_alert_banner.dart';
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

  final EmergencyService _emergencyService = EmergencyService();

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