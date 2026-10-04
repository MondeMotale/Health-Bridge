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
  State<PatientAppointmentsScreen> createState() => _PatientAppointmentsScreenState();
}

class _PatientAppointmentsScreenState extends State<PatientAppointmentsScreen> {
  bool _isSubmitting = false;

  // --- REQUEST APPOINTMENT POP-UP ---
  void _showRequestAppointmentDialog(String patientUid) {
    final TextEditingController locationController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final String patientName = authProvider.user?.displayName ?? 'Patient';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                    ),
                    const SizedBox(height: 16),

                    ListTile(
                      leading: const Icon(Icons.calendar_today, color: Color(0xFF1E3A8A)),
                      title: Text('Date: ${selectedDate.toLocal().toString().split(' ')[0]}'),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => selectedDate = picked);
                        }
                      },
                    ),

                    ListTile(
                      leading: const Icon(Icons.access_time, color: Color(0xFF1E3A8A)),
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
                                    const SnackBar(content: Text('Please enter a location.')),
                                  );
                                  return;
                                }

                                setState(() => _isSubmitting = true);

                                try {
                                  await FirebaseFirestore.instance.collection('appointment_requests').add({
                                    'patientId': patientUid,
                                    'patientName': patientName,
                                    'requestedDate': selectedDate.toIso8601String(),
                                    'requestedTime': selectedTime.format(context),
                                    'location': locationController.text.trim(),
                                    'status': 'Pending',
                                    'createdAt': FieldValue.serverTimestamp(),
                                  });

                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Request sent! Your CHW will confirm.'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
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
                  // ---------- SECTION 1: CONFIRMED APPOINTMENTS ----------
                  const Text(
                    '📅 My Appointments',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<List<Appointment>>(
                    stream: FirestoreService().getAppointmentsForPatient(patientUid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ));
                      }

                      final appointments = snapshot.data ?? [];

                      if (appointments.isEmpty) {
                        return _buildEmptyCard('No upcoming appointments.');
                      }

                      return Column(
                        children: appointments
                            .map((appt) => _buildAppointmentCard(appt))
                            .toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // ---------- SECTION 2: PENDING REQUESTS ----------
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
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox();
                      }

                      final pending = snapshot.data?.docs ?? [];
                      if (pending.isEmpty) {
                        return _buildEmptyCard('No pending requests.');
                      }

                      return Column(
                        children: pending.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return _buildPendingCard(data);
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // ---------- SECTION 3: DECLINED REQUESTS ----------
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
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox();
                      }

                      final declined = snapshot.data?.docs ?? [];
                      if (declined.isEmpty) {
                        return _buildEmptyCard('No declined requests. 🎉');
                      }

                      return Column(
                        children: declined.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return _buildDeclinedCard(data);
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'patient_request_fab',
        onPressed: () => _showRequestAppointmentDialog(patientUid ?? ''),
        backgroundColor: const Color(0xFF1E3A8A),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // ---------- Empty placeholder card ----------
  Widget _buildEmptyCard(String text) {
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

  // ---------- Pending request card ----------
  Widget _buildPendingCard(Map<String, dynamic> data) {
    final DateTime? dt = data['requestedDate'] != null
        ? DateTime.tryParse(data['requestedDate'])
        : null;
    final String dateStr = dt != null ? DateFormat('MMM d, yyyy').format(dt) : 'Unknown date';
    final String timeStr = data['requestedTime'] ?? 'Unknown time';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: Colors.orange.shade400, width: 4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time, color: Colors.orange, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$dateStr at $timeStr',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(data['location'] ?? 'No location',
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Pending',
                style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ---------- Declined request card ----------
  Widget _buildDeclinedCard(Map<String, dynamic> data) {
    final DateTime? dt = data['requestedDate'] != null
        ? DateTime.tryParse(data['requestedDate'])
        : null;
    final String dateStr = dt != null ? DateFormat('MMM d, yyyy').format(dt) : 'Unknown date';
    final String timeStr = data['requestedTime'] ?? 'Unknown time';
    final String reason = data['declinedReason'] ?? 'No reason provided';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: Colors.red.shade400, width: 4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2)),
        ],
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
                    Text('$dateStr at $timeStr',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(data['location'] ?? 'No location',
                        style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
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
                  style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Confirmed appointment card (existing style) ----------
  Widget _buildAppointmentCard(Appointment appointment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: Color(0xFF1E3A8A), size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${DateFormat('MMM d, yyyy').format(appointment.dateTime)} at ${DateFormat('h:mm a').format(appointment.dateTime)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  appointment.location,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: appointment.status == 'Scheduled'
                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              appointment.status,
              style: TextStyle(
                color: appointment.status == 'Scheduled' ? Colors.green : Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}