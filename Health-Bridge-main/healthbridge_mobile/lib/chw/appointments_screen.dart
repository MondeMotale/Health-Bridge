import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/appointment_service.dart';
import '../../auth/auth_provider.dart';
import '../../models/appointment.dart';
import 'create_report_screen.dart';
import 'requests_screen.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final AppointmentService _service = AppointmentService();

  // ============================================================
  // POST-VISIT NOTES DIALOG
  // ============================================================
  Future<void> _showCompleteVisitDialog(Appointment appt) async {
    final TextEditingController notesController = TextEditingController();
    String followUp = 'None';
    DateTime? nextFollowUpDate;
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              insetPadding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.check_circle,
                            color: Color(0xFF10B981),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Complete Visit',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appt.patientName,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 16),

                    // ----- NOTES -----
                    const Text(
                      'Clinical Notes',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesController,
                      maxLines: 6,
                      minLines: 4,
                      decoration: InputDecoration(
                        hintText:
                            'Record what you observed, any symptoms, treatment given, patient education, etc.',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '⚠️ Notes cannot be edited after saving.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFEF4444),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ----- FOLLOW-UP -----
                    const Text(
                      'Follow-up needed?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['None', 'Days', 'Weeks', 'Months']
                          .map((opt) => ChoiceChip(
                                label: Text(opt),
                                selected: followUp == opt,
                                onSelected: (selected) {
                                  setState(() {
                                    followUp = opt;
                                    nextFollowUpDate = null;
                                  });
                                },
                                selectedColor: const Color(0xFF1E3A8A)
                                    .withValues(alpha: 0.15),
                                labelStyle: TextStyle(
                                  color: followUp == opt
                                      ? const Color(0xFF1E3A8A)
                                      : Colors.black87,
                                  fontWeight: followUp == opt
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ))
                          .toList(),
                    ),

                    if (followUp != 'None') ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(
                              Duration(
                                days: followUp == 'Days'
                                    ? 7
                                    : followUp == 'Weeks'
                                        ? 14
                                        : 30,
                              ),
                            ),
                            firstDate: DateTime.now().add(const Duration(days: 1)),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(() => nextFollowUpDate = picked);
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          nextFollowUpDate == null
                              ? 'Pick next visit date'
                              : 'Next visit: ${DateFormat('MMM d, yyyy').format(nextFollowUpDate!)}',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1E3A8A),
                          side: const BorderSide(color: Color(0xFF1E3A8A)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // ----- ACTIONS -----
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.pop(ctx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade200,
                              foregroundColor: Colors.black87,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    if (notesController.text.trim().isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Please add some notes before completing'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    setState(() => isSaving = true);

                                    try {
                                      await _service.markCompleted(
                                        appointmentId: appt.id,
                                        chwNotes:
                                            notesController.text.trim(),
                                        startedAt: appt.startedAt ??
                                            DateTime.now(),
                                        followUpRequired:
                                            followUp == 'None' ? null : followUp,
                                        nextFollowUpDate: nextFollowUpDate,
                                      );

                                      if (ctx.mounted) {
                                        Navigator.pop(ctx);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content:
                                                Text('Visit marked complete'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      setState(() => isSaving = false);
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text('Error: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Complete Visit'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // MISSED REASON DIALOG
  // ============================================================
  Future<void> _showMissedDialog(Appointment appt) async {
    final TextEditingController reasonController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Missed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Why was this appointment missed?',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. Patient not home, address not found, etc.',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text(
              'Mark Missed',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );

    if (result == true && reasonController.text.trim().isNotEmpty) {
      try {
        await _service.markMissed(
          appointmentId: appt.id,
          reason: reasonController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Marked as missed'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // ============================================================
  // APPOINTMENT DETAILS POPUP
  // ============================================================
  void _showDetailsDialog(Appointment appt) {
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
              Text(
                appt.patientName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEEE, MMM d, yyyy • h:mm a').format(appt.dateTime),
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              _row('Status', appt.status),
              _row('Location', appt.location),
              if (appt.notes.isNotEmpty) _row('Patient note', appt.notes),
              if (appt.chwNotes != null && appt.chwNotes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Clinical Notes',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(appt.chwNotes!),
              ],
              if (appt.visitDurationMinutes != null) ...[
                const SizedBox(height: 12),
                _row('Duration', '${appt.visitDurationMinutes} minutes'),
              ],
              if (appt.missedReason != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Missed — Reason',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(height: 6),
                Text(appt.missedReason!),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
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

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF1A1A2E),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final String? chwId = authProvider.user?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Appointments'),
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
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final appointments = snapshot.data ?? [];

                if (appointments.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No appointments booked yet.',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // Split: today & active first, then history
                final active = appointments
                    .where((a) =>
                        a.status != 'Completed' &&
                        a.status != 'Missed' &&
                        a.status != 'Cancelled')
                    .toList();
                final history = appointments
                    .where((a) =>
                        a.status == 'Completed' ||
                        a.status == 'Missed' ||
                        a.status == 'Cancelled')
                    .toList();

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (active.isNotEmpty) ...[
                      const Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...active.map(_buildActiveCard),
                      const SizedBox(height: 24),
                    ],
                    if (history.isNotEmpty) ...[
                      const Text(
                        'History',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...history.map(_buildHistoryCard),
                    ],
                  ],
                );
              },
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                heroTag: 'requests_fab',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const RequestsScreen()),
                  );
                },
                backgroundColor: const Color(0xFF1E3A8A),
                child: const Icon(Icons.inbox, color: Colors.white),
              ),
              const SizedBox(height: 4),
              const Text(
                'Requests',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF1E3A8A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                heroTag: 'report_fab',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const CreateReportScreen()),
                  );
                },
                backgroundColor: const Color(0xFF1E3A8A),
                child: const Icon(Icons.description, color: Colors.white),
              ),
              const SizedBox(height: 4),
              const Text(
                'Report',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF1E3A8A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // ============================================================
  // ACTIVE APPOINTMENT CARD — has action buttons
  // ============================================================
  Widget _buildActiveCard(Appointment appt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        border: Border(
          left: BorderSide(
            color: _statusColor(appt.status),
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _statusColor(appt.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.calendar_today,
                  color: _statusColor(appt.status),
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
                  color: _statusColor(appt.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(appt.status),
                  style: TextStyle(
                    color: _statusColor(appt.status),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on,
                  color: Color(0xFF6B7280), size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  appt.location,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          // ---------- ACTION BUTTONS based on status ----------
          Row(
            children: [
              if (appt.status == 'Scheduled' || appt.status == 'Requested')
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _service.markEnRoute(appt.id),
                    icon: const Icon(Icons.directions_walk, size: 18),
                    label: const Text('Start Trip'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              if (appt.status == 'EnRoute')
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _service.markArrived(appt.id),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text("I've Arrived"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              if (appt.status == 'InProgress') ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showCompleteVisitDialog(appt),
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('Complete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _showMissedDialog(appt),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Icon(Icons.close, size: 20),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _showDetailsDialog(appt),
            icon: const Icon(Icons.info_outline, size: 16),
            label: const Text('Details'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1E3A8A),
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HISTORY CARD — read-only
  // ============================================================
  Widget _buildHistoryCard(Appointment appt) {
    return InkWell(
      onTap: () => _showDetailsDialog(appt),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border(
            left: BorderSide(color: _statusColor(appt.status), width: 4),
          ),
        ),
        child: Row(
          children: [
            Icon(_statusIcon(appt.status), color: _statusColor(appt.status)),
            const SizedBox(width: 16),
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
                    DateFormat('MMM d, yyyy • h:mm a').format(appt.dateTime),
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _statusLabel(appt.status),
              style: TextStyle(
                color: _statusColor(appt.status),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================
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