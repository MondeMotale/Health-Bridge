import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/appointment_service.dart';
import '../../auth/auth_provider.dart';
import '../../models/appointment.dart';

/// Filter types for this screen
enum AppointmentFilter {
  today, // Today's appointments (not finished)
  pending, // Next 7 days (not finished)
  done, // All completed + missed
  all, // Everything
}

class AppointmentsListScreen extends StatefulWidget {
  final AppointmentFilter filter;

  const AppointmentsListScreen({
    super.key,
    required this.filter,
  });

  @override
  State<AppointmentsListScreen> createState() => _AppointmentsListScreenState();
}

class _AppointmentsListScreenState extends State<AppointmentsListScreen> {
  final AppointmentService _service = AppointmentService();

  String get _title {
    switch (widget.filter) {
      case AppointmentFilter.today:
        return "Today's Appointments";
      case AppointmentFilter.pending:
        return 'Pending Visits (Next 7 Days)';
      case AppointmentFilter.done:
        return 'Completed & Missed Visits';
      case AppointmentFilter.all:
        return 'All Appointments';
    }
  }

  String get _emptyMessage {
    switch (widget.filter) {
      case AppointmentFilter.today:
        return 'No appointments scheduled for today.';
      case AppointmentFilter.pending:
        return 'No upcoming appointments in the next 7 days.';
      case AppointmentFilter.done:
        return 'No completed or missed visits yet.';
      case AppointmentFilter.all:
        return 'No appointments found.';
    }
  }

  // Apply the filter to a list of appointments
  List<Appointment> _applyFilter(List<Appointment> all) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekFromNow = now.add(const Duration(days: 7));

    switch (widget.filter) {
      case AppointmentFilter.today:
        return all.where((a) {
          final d = DateTime(a.dateTime.year, a.dateTime.month, a.dateTime.day);
          final isToday = d.isAtSameMomentAs(today) ||
              (d.isAfter(today) && d.isBefore(tomorrow));
          final notFinished = a.status != 'Completed' &&
              a.status != 'Missed' &&
              a.status != 'Cancelled';
          return isToday && notFinished;
        }).toList();

      case AppointmentFilter.pending:
        return all.where((a) {
          final isUpcoming = a.dateTime.isAfter(
                now.subtract(const Duration(hours: 1)),
              ) &&
              a.dateTime.isBefore(weekFromNow);
          final notFinished = a.status != 'Completed' &&
              a.status != 'Missed' &&
              a.status != 'Cancelled';
          return isUpcoming && notFinished;
        }).toList();

      case AppointmentFilter.done:
        return all
            .where((a) => a.status == 'Completed' || a.status == 'Missed')
            .toList();

      case AppointmentFilter.all:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final String? chwId = authProvider.user?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: chwId == null
          ? const Center(child: Text('User not logged in'))
          : StreamBuilder<List<Appointment>>(
              stream: _service.getAppointmentsForChw(chwId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Semantics(
                      label: 'Loading appointments',
                      liveRegion: true,
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          "Couldn't load appointments. Check your connection.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF1A1A2E)),
                        ),
                      ),
                    ),
                  );
                }

                final all = snapshot.data ?? [];
                final filtered = _applyFilter(all);

                if (filtered.isEmpty) {
                  return Semantics(
                    label: _emptyMessage,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const ExcludeSemantics(
                              child: Icon(
                                Icons.event_busy,
                                size: 64,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _emptyMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF4B5563),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // Sort by date
                filtered.sort((a, b) => b.dateTime.compareTo(a.dateTime));

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _buildAppointmentCard(filtered[index]);
                  },
                );
              },
            ),
    );
  }

  Widget _buildAppointmentCard(Appointment appt) {
    final color = _statusColor(appt.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
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
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _statusIcon(appt.status),
                  color: color,
                  size: 20,
                ),
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
                        fontSize: 16,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('EEE, MMM d • h:mm a').format(appt.dateTime),
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(appt.status),
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.location_on,
                color: Color(0xFF6B7280),
                size: 14,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  appt.location,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // Show CHW notes for completed visits
          if (appt.chwNotes != null && appt.chwNotes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                appt.chwNotes!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1A1A2E),
                  fontSize: 12,
                ),
              ),
            ),
          ],
          if (appt.missedReason != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFFEF4444),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      appt.missedReason!,
                      style: const TextStyle(
                        color: Color(0xFF991B1B),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
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

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Completed':
        return Icons.check_circle;
      case 'Missed':
        return Icons.cancel;
      case 'Cancelled':
        return Icons.block;
      case 'EnRoute':
        return Icons.directions_walk;
      case 'InProgress':
        return Icons.hourglass_top;
      default:
        return Icons.calendar_today;
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
