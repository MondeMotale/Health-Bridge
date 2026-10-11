import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/patient.dart';
import '../../models/appointment.dart';
import '../../services/firestore_service.dart';
import '../../auth/auth_provider.dart';
import 'emergency_services_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  static void Function(int)? bottomNavCallback;

  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final String? patientUid = authProvider.user?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: patientUid == null
          ? const Center(child: Text('User not logged in'))
          : FutureBuilder<Patient?>(
              future: FirestoreService().getPatientProfile(patientUid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final patient = snapshot.data;
                final firstName = _firstName(patient?.name ?? 'Patient');

                return RefreshIndicator(
                  onRefresh: () async {
                    await Future.delayed(const Duration(milliseconds: 500));
                    setState(() {});
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildGreeting(firstName),
                        const SizedBox(height: 20),

                        _buildNextAppointmentSection(patientUid),
                        const SizedBox(height: 24),

                        _buildQuickActions(),
                        const SizedBox(height: 24),

                        _buildHealthTip(),
                        const SizedBox(height: 16),

                        if (patient != null && patient.condition.isNotEmpty)
                          _buildConditionCard(patient),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _firstName(String fullName) {
    final parts = fullName.trim().split(' ');
    return parts.isNotEmpty ? parts[0] : 'Patient';
  }

  // ---------- GREETING ----------
  Widget _buildGreeting(String firstName) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, $firstName',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('EEEE, MMMM d').format(DateTime.now()),
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- NEXT APPOINTMENT ----------
  Widget _buildNextAppointmentSection(String patientUid) {
    return StreamBuilder<List<Appointment>>(
      stream: FirestoreService().getAppointmentsForPatient(patientUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final appointments = snapshot.data ?? [];
        final tomorrow = DateTime.now().add(const Duration(days: 1));

        final tomorrowAppointments = appointments.where((a) {
          return a.dateTime.year == tomorrow.year &&
              a.dateTime.month == tomorrow.month &&
              a.dateTime.day == tomorrow.day &&
              a.status == 'Scheduled';
        }).toList();

        if (tomorrowAppointments.isEmpty) {
          return _buildEmptyAppointmentCard();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📅 Tomorrow',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 10),
            ...tomorrowAppointments.map(_buildTomorrowCard),
          ],
        );
      },
    );
  }

  Widget _buildEmptyAppointmentCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.event_available,
              color: Color(0xFF10B981),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No appointment tomorrow',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Tap Appointments to schedule a visit',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTomorrowCard(Appointment appointment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.access_time_filled,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('h:mm a').format(appointment.dateTime),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Tomorrow',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  appointment.location,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.person, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                'with ${appointment.chwName}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- QUICK ACTIONS ----------
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                icon: Icons.calendar_month,
                label: 'Appointments',
                color: const Color(0xFF1E3A8A),
                onTap: () => PatientHomeScreen.bottomNavCallback?.call(1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionTile(
                icon: Icons.chat_bubble_outline,
                label: 'Messages',
                color: const Color(0xFF1E3A8A),
                onTap: () => PatientHomeScreen.bottomNavCallback?.call(3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                icon: Icons.medical_services_outlined,
                label: 'My CHW',
                color: const Color(0xFF1E3A8A),
                onTap: () => _showChwSheet(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionTile(
                icon: Icons.emergency,
                label: 'Emergency',
                color: const Color(0xFF1E3A8A),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EmergencyServicesScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- MY CHW (centered dialog) ----------
  void _showChwSheet() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = authProvider.user?.uid;
    if (uid == null) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          width: double.infinity,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: FirestoreService().getAssignedChw(uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final chwList = snapshot.data ?? [];
              if (chwList.isEmpty) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_off, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text(
                      'No CHW assigned yet',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You will be notified once a community health worker is assigned to you.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                );
              }

              final chw = chwList.first;
              final name = chw['displayName'] ?? 'Your CHW';
              final phone = chw['phoneNumber'] ?? chw['phone'] ?? '';
              final email = chw['email'] ?? '';
              final bio = chw['bio'] ?? '';

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1E3A8A),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Your Community Health Worker',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFF6B7280)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (phone.isNotEmpty)
                    _chwInfoRow(Icons.phone, 'Phone', phone),
                  if (email.isNotEmpty)
                    _chwInfoRow(Icons.email, 'Email', email),
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        bio,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF6B7280)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _chwInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF6B7280)),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF1A1A2E),
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- HEALTH TIP ----------
  Widget _buildHealthTip() {
    final tips = [
      '💧 Drink at least 8 glasses of water today.',
      '🚶 A 30-minute walk helps lower blood pressure.',
      '🥗 Add a fruit or vegetable to every meal.',
      '😴 Aim for 7–8 hours of sleep tonight.',
      '🧘 Take 5 minutes to breathe deeply and relax.',
      '💊 Remember to take your medication on time.',
    ];
    final tip = tips[DateTime.now().day % tips.length];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.lightbulb_outline,
              color: Color(0xFFF59E0B),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Health Tip',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tip,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1A1A2E),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- YOUR HEALTH CONDITION ----------
  Widget _buildConditionCard(Patient patient) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.medical_information,
              color: Color(0xFF1E3A8A),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Health Condition',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  patient.condition,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}