import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/appointment.dart';
import '../../services/firestore_service.dart';
import '../../auth/auth_provider.dart';

class PatientAppointmentsScreen extends StatefulWidget {
  const PatientAppointmentsScreen({super.key});

  @override
  State<PatientAppointmentsScreen> createState() =>
      _PatientAppointmentsScreenState();
}

class _PatientAppointmentsScreenState
    extends State<PatientAppointmentsScreen> {
  bool _isSubmitting = false;

  // ============================================================
  // REQUEST APPOINTMENT
  // ============================================================
  void _showRequestAppointmentDialog(String patientUid) {
    final TextEditingController locationController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              insetPadding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(24),
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Request Appointment',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.calendar_today,
                          color: Color(0xFF1E3A8A)),
                      title: Text(
                          'Date: ${selectedDate.toLocal().toString().split(' ')[0]}'),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => selectedDate = picked);
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.access_time,
                          color: Color(0xFF1E3A8A)),
                      title: Text('Time: ${selectedTime.format(context)}'),
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setState(() => selectedTime = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                                if (locationController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Please enter a location.'),
                                    ),
                                  );
                                  return;
                                }

                                setState(() => _isSubmitting = true);

                                try {
                                  // ---- FIX: fetch the REAL patient name ----
                                  final patientDoc = await FirebaseFirestore
                                      .instance
                                      .collection('patients')
                                      .doc(patientUid)
                                      .get();

                                  final realName =
                                      (patientDoc.data()?['name'] as String?)
                                              ?.trim() ??
                                          '';

                                  final authProvider =
                                      Provider.of<AuthProvider>(context,
                                          listen: false);
                                  final authName =
                                      authProvider.user?.displayName
                                              ?.trim() ??
                                          '';

                                  final finalName = realName.isNotEmpty
                                      ? realName
                                      : (authName.isNotEmpty
                                          ? authName
                                          : 'Unknown Patient');

                                  await FirebaseFirestore.instance
                                      .collection('appointment_requests')
                                      .add({
                                    'patientId': patientUid,
                                    'patientName': finalName,
                                    'requestedDate':
                                        selectedDate.toIso8601String(),
                                    'requestedTime':
                                        selectedTime.format(context),
                                    'location':
                                        locationController.text.trim(),
                                    'status': 'Pending',
                                    'createdAt':
                                        FieldValue.serverTimestamp(),
                                  });

                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Request sent! Your CHW will confirm.'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } finally {
                                  if (context.mounted) {
                                    setState(() => _isSubmitting = false);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Submit Request'),
                      ),
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
  // DETAILS DIALOG (with CHW notes visible to patient)
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _statusColor(appt.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _statusIcon(appt.status),
                      color: _statusColor(appt.status),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Visit Details',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _statusLabel(appt.status),
                          style: TextStyle(
                            fontSize: 13,
                            color: _statusColor(appt.status),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              _row('With', appt.chwName),
              _row(
                'Date',
                DateFormat('EEEE, MMM d, yyyy').format(appt.dateTime),
              ),
              _row('Time', DateFormat('h:mm a').format(appt.dateTime)),
              _row('Location', appt.location),

              if (appt.startedAt != null && appt.completedAt != null) ...[
                const SizedBox(height: 8),
                _row(
                  'Visit Duration',
                  '${appt.visitDurationMinutes ?? 0} minutes',
                ),
              ],

              if (appt.chwNotes != null && appt.chwNotes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF1E3A8A).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.medical_information,
                            color: Color(0xFF1E3A8A),
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Notes from your CHW',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A8A),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        appt.chwNotes!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1A1A2E),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (appt.followUpRequired != null &&
                  appt.nextFollowUpDate != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_repeat,
                          color: Color(0xFFF59E0B), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Follow-up suggested: ${DateFormat('MMM d, yyyy').format(appt.nextFollowUpDate!)}',
                          style: const TextStyle(
                            color: Color(0xFF92400E),
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (appt.missedReason != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: Color(0xFFEF4444), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Reason: ${appt.missedReason}',
                          style: const TextStyle(
                            color: Color(0xFF991B1B),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
    final String? patientUid = authProvider.user?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('My Appointments'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: patientUid == null
          ? const Center(child: Text('User not logged in'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📅 Upcoming',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<List<Appointment>>(
                    stream: FirestoreService()
                        .getAppointmentsForPatient(patientUid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final all = snapshot.data ?? [];
                      final upcoming = all
                          .where((a) =>
                              a.status != 'Completed' &&
                              a.status != 'Missed' &&
                              a.status != 'Cancelled')
                          .toList();

                      if (upcoming.isEmpty) {
                        return _emptyCard('No upcoming appointments.');
                      }

                      return Column(
                        children:
                            upcoming.map((a) => _upcomingCard(a)).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    '⏳ Pending Requests',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('appointment_requests')
                        .where('patientId', isEqualTo: patientUid)
                        .where('status', isEqualTo: 'Pending')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const SizedBox();
                      }
                      final pending = snapshot.data?.docs ?? [];
                      if (pending.isEmpty) {
                        return _emptyCard('No pending requests.');
                      }
                      return Column(
                        children: pending
                            .map((d) => _pendingCard(
                                d.data() as Map<String, dynamic>))
                            .toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    '❌ Declined Requests',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('appointment_requests')
                        .where('patientId', isEqualTo: patientUid)
                        .where('status', isEqualTo: 'Declined')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const SizedBox();
                      }
                      final declined = (snapshot.data?.docs ?? []).where((d) {
                        final data = d.data() as Map<String, dynamic>;
                        return data['patientDismissed'] != true;
                      }).toList();
                      if (declined.isEmpty) {
                        return _emptyCard('No declined requests. 🎉');
                      }
                      return Column(
                        children: declined
                            .map((d) => _declinedCard(
                                d.data() as Map<String, dynamic>, d.id))
                            .toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    '📜 History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<List<Appointment>>(
                    stream: FirestoreService()
                        .getAppointmentsForPatient(patientUid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const SizedBox();
                      }
                      final all = snapshot.data ?? [];
                      final history = all
                          .where((a) =>
                              a.status == 'Completed' ||
                              a.status == 'Missed' ||
                              a.status == 'Cancelled')
                          .toList();

                      if (history.isEmpty) {
                        return _emptyCard('No past appointments yet.');
                      }

                      return Column(
                        children:
                            history.map((a) => _historyCard(a)).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 60),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'patient_request_fab',
        onPressed: () =>
            _showRequestAppointmentDialog(patientUid ?? ''),
        backgroundColor: const Color(0xFF1E3A8A),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // ============================================================
  // CARD BUILDERS
  // ============================================================
  Widget _emptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(color: Colors.grey)),
    );
  }

  Widget _upcomingCard(Appointment appt) {
    return InkWell(
      onTap: () => _showDetailsDialog(appt),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(color: _statusColor(appt.status), width: 4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, MMM d')
                            .format(appt.dateTime),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat('h:mm a').format(appt.dateTime)} • ${appt.chwName}',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(appt.status)
                        .withValues(alpha: 0.1),
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
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on,
                    color: Color(0xFF6B7280), size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    appt.location,
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 13),
                  ),
                ),
              ],
            ),
            if (appt.status == 'EnRoute') ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.directions_walk,
                        color: Color(0xFF3B82F6), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your CHW is on the way',
                        style: TextStyle(
                          color: Color(0xFF1E40AF),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _historyCard(Appointment appt) {
    return InkWell(
      onTap: () => _showDetailsDialog(appt),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(color: _statusColor(appt.status), width: 4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _statusIcon(appt.status),
                  color: _statusColor(appt.status),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('MMM d, yyyy').format(appt.dateTime),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${appt.chwName} • ${appt.location}',
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
            if (appt.chwNotes != null && appt.chwNotes!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes,
                        color: Color(0xFF1E3A8A), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        appt.chwNotes!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1E3A8A),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        color: Color(0xFFEF4444), size: 16),
                    const SizedBox(width: 8),
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
      ),
    );
  }

  Widget _pendingCard(Map<String, dynamic> data) {
    final dt = data['requestedDate'] != null
        ? DateTime.tryParse(data['requestedDate'])
        : null;
    final dateStr =
        dt != null ? DateFormat('MMM d, yyyy').format(dt) : 'Unknown date';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
            left: BorderSide(color: Colors.orange.shade400, width: 4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time, color: Colors.orange, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$dateStr at ${data['requestedTime'] ?? ''}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  data['location'] ?? '',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Pending',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _declinedCard(Map<String, dynamic> data, String docId) {
    final dt = data['requestedDate'] != null
        ? DateTime.tryParse(data['requestedDate'])
        : null;
    final dateStr =
        dt != null ? DateFormat('MMM d, yyyy').format(dt) : 'Unknown date';
    final reason = data['declinedReason'] ?? 'No reason provided';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
            left: BorderSide(color: Colors.red.shade400, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cancel, color: Colors.red, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$dateStr at ${data['requestedTime'] ?? ''}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['location'] ?? '',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                color: Colors.grey.shade500,
                tooltip: 'Dismiss',
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('appointment_requests')
                      .doc(docId)
                      .update({'patientDismissed': true});
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: Colors.red.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reason:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reason,
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF1A1A2E)),
                ),
              ],
            ),
          ),
        ],
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
        return 'CHW En Route';
      case 'InProgress':
        return 'In Progress';
      default:
        return status;
    }
  }
}