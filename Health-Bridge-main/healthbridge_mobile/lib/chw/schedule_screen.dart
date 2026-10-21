import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/appointment.dart';
import '../../services/appointment_service.dart';
import '../../auth/auth_provider.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final AppointmentService _service = AppointmentService();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final String? chwId = authProvider.user?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Today's Schedule"),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: chwId == null
          ? const Center(child: Text('User not logged in'))
          : StreamBuilder<List<Appointment>>(
              stream: _service.getAppointmentsForChw(chwId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final all = snapshot.data ?? [];

                // ---- Filter: today only, not yet finished ----
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final tomorrow = today.add(const Duration(days: 1));

                final todayAppointments = all.where((a) {
                  final d = DateTime(
                    a.dateTime.year,
                    a.dateTime.month,
                    a.dateTime.day,
                  );
                  final isToday = d.isAtSameMomentAs(today) ||
                      (d.isAfter(today) && d.isBefore(tomorrow));
                  final notFinished = a.status != 'Completed' &&
                      a.status != 'Missed' &&
                      a.status != 'Cancelled';
                  return isToday && notFinished;
                }).toList();

                if (todayAppointments.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_available,
                          size: 80,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No appointments scheduled for today.',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Check the Appointments tab for upcoming visits.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // Sort by time (earliest first)
                todayAppointments.sort(
                  (a, b) => a.dateTime.compareTo(b.dateTime),
                );

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: todayAppointments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _buildScheduleCard(todayAppointments[index]);
                  },
                );
              },
            ),
    );
  }

  Widget _buildScheduleCard(Appointment appointment) {
    final color = _statusColor(appointment.status);

    return InkWell(
      onTap: () {},
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
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    appointment.patientName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(appointment.status),
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  color: Color(0xFF1E3A8A),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('h:mm a').format(appointment.dateTime),
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: Color(0xFF6B7280),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    appointment.location,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'EnRoute':
        return const Color(0xFF3B82F6);
      case 'InProgress':
        return const Color(0xFFF59E0B);
      case 'Completed':
        return const Color(0xFF10B981);
      case 'Missed':
        return const Color(0xFFEF4444);
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
}