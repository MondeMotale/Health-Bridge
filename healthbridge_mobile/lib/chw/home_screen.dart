import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../services/appointment_service.dart';
import '../../auth/auth_provider.dart';
import '../../models/patient.dart';
import '../../models/appointment.dart';
import 'patients_screen.dart';
import 'schedule_screen.dart';
import 'reports_screen.dart';
import 'chat_screen.dart';
import 'appointments_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String get _currentDate => DateFormat('EEEE, MMMM d').format(DateTime.now());

  final AppointmentService _appointmentService = AppointmentService();
  final FirestoreService _firestoreService = FirestoreService();

  Map<String, int> _stats = {
    'total': 0,
    'critical': 0,
    'followUp': 0,
    'done': 0,
  };
  int _appointmentCount = 0;

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
        final results = await Future.wait([
          _firestoreService.getDashboardStats(chwId),
          _firestoreService.getAppointmentsCount(chwId),
        ]);

        if (mounted) {
          setState(() {
            _stats = results[0] as Map<String, int>;
            _appointmentCount = results[1] as int;
          });
        }
      } catch (e) {
        debugPrint("Error loading stats: $e");
      }
    }
  }

  // ============================================================
  // ONE-TIME BACKFILL — remove after running once
  // ============================================================
  Future<void> _backfillPatientNames() async {
    final firestore = FirebaseFirestore.instance;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Backfilling patient names...')),
    );

    int fixed = 0;
    const badNames = {'Patient', 'Unknown Patient', 'Unknown', ''};

    // ---- 1. Fix appointments ----
    final appts = await firestore.collection('appointments').get();
    for (final doc in appts.docs) {
      final data = doc.data();
      final name = (data['patientName'] as String?)?.trim() ?? '';
      final patientId = data['patientId'] as String?;
      if (badNames.contains(name) &&
          patientId != null &&
          patientId.isNotEmpty) {
        try {
          final pDoc =
              await firestore.collection('patients').doc(patientId).get();
          final realName = (pDoc.data()?['name'] as String?)?.trim() ?? '';
          if (realName.isNotEmpty && !badNames.contains(realName)) {
            await doc.reference.update({'patientName': realName});
            fixed++;
          }
        } catch (_) {}
      }
    }

    // ---- 2. Fix appointment_requests ----
    final reqs = await firestore.collection('appointment_requests').get();
    for (final doc in reqs.docs) {
      final data = doc.data();
      final name = (data['patientName'] as String?)?.trim() ?? '';
      final patientId = data['patientId'] as String?;
      if (badNames.contains(name) &&
          patientId != null &&
          patientId.isNotEmpty) {
        try {
          final pDoc =
              await firestore.collection('patients').doc(patientId).get();
          final realName = (pDoc.data()?['name'] as String?)?.trim() ?? '';
          if (realName.isNotEmpty && !badNames.contains(realName)) {
            await doc.reference.update({'patientName': realName});
            fixed++;
          }
        } catch (_) {}
      }
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text('Done. Fixed $fixed documents.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ============================================================
  // PATIENT ALERTS STREAM
  // ============================================================
  Stream<List<Patient>> _getAlerts(String chwId) {
    return _firestoreService.getPatientsForChw(chwId).map((patients) {
      return patients
          .where((p) =>
              p.status == 'Critical' || p.status == 'Needs Follow-up')
          .toList();
    });
  }

  // ============================================================
  // TODAY'S APPOINTMENTS STREAM
  // ============================================================
  Stream<List<Appointment>> _getTodaysAppointments(String chwId) {
    return _appointmentService.getAppointmentsForChw(chwId).map((appts) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      return appts.where((a) {
        final d = DateTime(a.dateTime.year, a.dateTime.month, a.dateTime.day);
        final isToday = d.isAtSameMomentAs(today) ||
            (d.isAfter(today) && d.isBefore(tomorrow));
        final notFinished = a.status != 'Completed' &&
            a.status != 'Missed' &&
            a.status != 'Cancelled';
        return isToday && notFinished;
      }).toList();
    });
  }

  // ============================================================
  // PATIENT ALERT ACTIONS
  // ============================================================
  void _showAlertActions(Patient patient, String chwName) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor:
                        const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                    child: Text(
                      patient.name[0],
                      style: const TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${patient.age} yrs • ${patient.condition}',
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: patient.status == 'Critical'
                      ? Colors.red.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  patient.status,
                  style: TextStyle(
                    color: patient.status == 'Critical'
                        ? Colors.red
                        : Colors.orange,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _actionTile(
                icon: Icons.chat_bubble,
                color: const Color(0xFF10B981),
                title: 'Send Message',
                subtitle: 'Chat with the patient',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        chatWithId: patient.id,
                        chatWithName: patient.name,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _actionTile(
                icon: Icons.calendar_today,
                color: const Color(0xFF3B82F6),
                title: 'Book Appointment',
                subtitle: 'Schedule a visit for this patient',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PatientsScreen(initialFilter: 'all'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _actionTile(
                icon: Icons.medical_services,
                color: const Color(0xFF8B5CF6),
                title: 'Refer Patient',
                subtitle: 'Send to specialist or department',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PatientsScreen(initialFilter: 'all'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SCHEDULE CARD
  // ============================================================
  Widget _buildScheduleCard(Appointment appt) {
    final color = _statusColor(appt.status);
    final timeStr = DateFormat('h:mm a').format(appt.dateTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.access_time, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appt.patientName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$timeStr • ${appt.location}',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(appt.status),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (appt.status == 'Scheduled' || appt.status == 'Requested')
                Expanded(
                  child: _smallActionButton(
                    icon: Icons.directions_walk,
                    label: 'Start Trip',
                    color: const Color(0xFF3B82F6),
                    onTap: () => _appointmentService.markEnRoute(appt.id),
                  ),
                ),
              if (appt.status == 'EnRoute')
                Expanded(
                  child: _smallActionButton(
                    icon: Icons.check,
                    label: "I've Arrived",
                    color: const Color(0xFFF59E0B),
                    onTap: () => _appointmentService.markArrived(appt.id),
                  ),
                ),
              if (appt.status == 'InProgress')
                Expanded(
                  child: _smallActionButton(
                    icon: Icons.check_circle,
                    label: 'Complete Visit',
                    color: const Color(0xFF10B981),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ScheduleScreen(),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ALERT CARD (tap to open actions)
  // ============================================================
  Widget _buildAlertCard(Patient patient, String chwName) {
    final alertColor =
        patient.status == 'Critical' ? Colors.red : Colors.orange;
    final alertIcon = patient.status == 'Critical'
        ? Icons.warning_amber_rounded
        : Icons.medical_services;

    return InkWell(
      onTap: () => _showAlertActions(patient, chwName),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: alertColor, width: 4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: alertColor.withValues(alpha: 0.1),
              child: Icon(alertIcon, color: alertColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${patient.age} yrs • ${patient.condition}',
                    style: const TextStyle(color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: alertColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                patient.status,
                style: TextStyle(
                  color: alertColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Completed':
        return const Color(0xFF10B981);
      case 'Missed':
        return const Color(0xFFEF4444);
      case 'Cancelled':
        return Colors.grey;
      case 'EnRoute':
        return const Color(0xFF3B82F6);
      case 'InProgress':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF1E3A8A);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'EnRoute':
        return 'En Route';
      case 'InProgress':
        return 'In Progress';
      default:
        return status;
    }
  }

  // ============================================================
  // BUILD
  // ============================================================
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
                // ----- GREETING -----
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, $userName ',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentDate,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _backfillPatientNames,
                          icon: const Icon(Icons.build, size: 16),
                          label: const Text('Fix Names'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ReportsScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.description, size: 16),
                          label: const Text('Report'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF1E3A8A),
                            elevation: 0,
                            side: const BorderSide(color: Color(0xFF1E3A8A)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ----- STATS GRID -----
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildClickableStatCard(
                            title: 'Active Patients',
                            count: _stats['total'] ?? 0,
                            icon: Icons.people,
                            color: Colors.blue,
                            subtitle: '${_stats['total'] ?? 0} today',
                            filter: 'all',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildClickableStatCard(
                            title: 'Pending Visits',
                            count: _stats['followUp'] ?? 0,
                            icon: Icons.pending_actions,
                            color: Colors.orange,
                            subtitle: 'Next 7 days',
                            filter: 'followUp',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildClickableStatCard(
                            title: 'Done Visits',
                            count: _stats['done'] ?? 0,
                            icon: Icons.check_circle,
                            color: Colors.green,
                            subtitle: 'Completed / missed',
                            filter: 'done',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildClickableStatCard(
                            title: 'Scheduled',
                            count: _appointmentCount,
                            icon: Icons.calendar_today,
                            color: Colors.purple,
                            subtitle: 'For today',
                            filter: 'scheduled',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ----- TODAY'S SCHEDULE -----
                const Text(
                  "Today's Schedule",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<Appointment>>(
                  stream: _getTodaysAppointments(chwId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final appts = snapshot.data ?? [];
                    if (appts.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.event_available,
                                color: Color(0xFF10B981)),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No appointments scheduled for today',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return Column(
                      children: appts.map(_buildScheduleCard).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // ----- PATIENT ALERTS -----
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Patient Alerts",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PatientsScreen(initialFilter: 'all'),
                          ),
                        );
                      },
                      child: const Text('See all'),
                    ),
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
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            'No critical alerts. All patients are stable!',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: alerts
                          .map((p) => _buildAlertCard(p, userName))
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // STAT CARD — navigates to the right screen per card
  // ============================================================
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
        // "Active Patients" → open the Patients list
        if (filter == 'all') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PatientsScreen(initialFilter: 'all'),
            ),
          );
          return;
        }

        // Other cards → open filtered appointments
        AppointmentFilter apptFilter;
        switch (filter) {
          case 'scheduled':
            apptFilter = AppointmentFilter.today;
            break;
          case 'followUp':
            apptFilter = AppointmentFilter.pending;
            break;
          case 'done':
            apptFilter = AppointmentFilter.done;
            break;
          default:
            apptFilter = AppointmentFilter.all;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AppointmentsListScreen(filter: apptFilter),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}