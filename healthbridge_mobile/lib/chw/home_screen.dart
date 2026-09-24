import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../auth/auth_provider.dart';
import '../../models/patient.dart';
import 'patients_screen.dart';
import 'schedule_screen.dart';
import 'reports_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String get _currentDate => DateFormat('EEEE, MMMM d').format(DateTime.now());
  
  // Cached stats variable
  Map<String, int> _stats = {'total': 0, 'critical': 0, 'followUp': 0, 'done': 0};
  int _appointmentCount = 0; // <--- NEW

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final String chwId = authProvider.user?.uid ?? '';
    
    if (chwId.isNotEmpty) {
      try {
        // Fetch all stats in parallel
        final results = await Future.wait([
          FirestoreService().getDashboardStats(chwId),
          FirestoreService().getAppointmentsCount(chwId),
        ]);

        if (mounted) {
          setState(() {
            _stats = results[0] as Map<String, int>;
            _appointmentCount = results[1] as int;
          });
        }
      } catch (e) {
        print("Error loading stats: $e");
      }
    }
  }

  Stream<List<Patient>> _getAlerts(String chwId) {
    return FirestoreService().getPatientsForChw(chwId).map((patients) {
      return patients.where((p) => 
        p.status == 'Critical' || p.status == 'Needs Follow-up'
      ).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final String chwId = authProvider.user?.uid ?? '';
    final String userName = authProvider.user?.displayName ?? 'CHW';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hello, $userName ', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                        const SizedBox(height: 4),
                        Text(_currentDate, style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ReportsScreen()),
                        );
                      },
                      icon: const Icon(Icons.description, size: 16),
                      label: const Text('Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1E3A8A),
                        elevation: 0,
                        side: const BorderSide(color: Color(0xFF1E3A8A)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildClickableStatCard(
                          title: 'Active Patients',
                          count: _stats['total'] ?? 0,
                          icon: Icons.people,
                          color: Colors.blue,
                          subtitle: '${_stats['total'] ?? 0} today',
                          filter: 'all',
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _buildClickableStatCard(
                          title: 'Pending Visits',
                          count: _stats['followUp'] ?? 0,
                          icon: Icons.pending_actions,
                          color: Colors.orange,
                          subtitle: 'Needs follow-up',
                          filter: 'followUp',
                        )),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildClickableStatCard(
                          title: 'Done Visits',
                          count: _stats['done'] ?? 0,
                          icon: Icons.check_circle,
                          color: Colors.green,
                          subtitle: 'Completed',
                          filter: 'done',
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _buildClickableStatCard(
                          title: 'Scheduled',
                          count: _appointmentCount, // <--- REAL COUNT
                          icon: Icons.calendar_today,
                          color: Colors.purple,
                          subtitle: 'For today',
                          filter: 'scheduled',
                        )),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                const Text("Today's Schedule", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ScheduleScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.access_time, color: Color(0xFF1E3A8A), size: 28),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Morning Checkup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('9:00 AM - 10:00 AM', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                        Chip(label: Text('Pending', style: TextStyle(color: Colors.white)), backgroundColor: Colors.orange),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Patient Alerts", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                    TextButton(onPressed: () {}, child: const Text('See all')),
                  ],
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<Patient>>(
                  stream: _getAlerts(chwId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final alerts = snapshot.data ?? [];
                    if (alerts.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: const Center(child: Text('No critical alerts. All patients are stable!', style: TextStyle(color: Colors.grey))),
                      );
                    }
                    return Column(children: alerts.map((patient) => _buildAlertCard(patient)).toList());
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClickableStatCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required String subtitle,
    required String filter,
  }) {
    return InkWell(
      onTap: () {
        if (filter == 'scheduled') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ScheduleScreen()),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PatientsScreen(initialFilter: filter),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 20),
                ),
                Text('$count', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(Patient patient) {
    Color alertColor = patient.status == 'Critical' ? Colors.red : Colors.orange;
    IconData alertIcon = patient.status == 'Critical' ? Icons.warning_amber_rounded : Icons.medical_services;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: alertColor, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: alertColor.withValues(alpha: 0.1), child: Icon(alertIcon, color: alertColor, size: 20)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patient.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('${patient.age} yrs • ${patient.condition}', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: alertColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(patient.status, style: TextStyle(color: alertColor, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}