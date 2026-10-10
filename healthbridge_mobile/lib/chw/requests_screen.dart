import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../auth/auth_provider.dart';
import '../../models/appointment.dart';
import '../../services/appointment_service.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  /// Predefined reason options the CHW can pick from
  static const List<String> _rejectionReasons = [
    'Not available at that time',
    'Outside my working hours',
    'Emergency with another patient',
    'Please pick a different date',
    'Other',
  ];

  // ---------------- APPROVE ----------------
  Future<void> _approveRequest(Map<String, dynamic> requestData) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chwId = authProvider.user?.uid ?? '';
    final chwName = authProvider.user?.displayName ?? 'CHW';

    // ---- FIX: don't trust requestData['patientName'] blindly ----
    String patientName = (requestData['patientName'] as String?)?.trim() ?? '';

    if (patientName.isEmpty ||
        patientName == 'Patient' ||
        patientName == 'Unknown Patient' ||
        patientName == 'Unknown') {
      try {
        final patientDoc = await FirebaseFirestore.instance
            .collection('patients')
            .doc(requestData['patientId'])
            .get();
        final realName = (patientDoc.data()?['name'] as String?)?.trim() ?? '';
        if (realName.isNotEmpty) {
          patientName = realName;
        }
      } catch (_) {
        // leave as-is; falls back below
      }
    }

    if (patientName.isEmpty) {
      patientName = 'Unknown Patient';
    }

    final appointment = Appointment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      patientId: requestData['patientId'],
      patientName: patientName,
      chwId: chwId,
      chwName: chwName,
      dateTime: DateTime.parse(requestData['requestedDate']),
      location: requestData['location'] ?? '',
      notes: 'Requested by Patient',
      status: 'Scheduled',
    );

    await AppointmentService().bookAppointment(appointment);

    await FirebaseFirestore.instance
        .collection('appointment_requests')
        .doc(requestData['requestId'])
        .update({
      'status': 'Approved',
      'approvedAt': FieldValue.serverTimestamp(),
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment approved!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ---------------- DECLINE (with reason dialog) ----------------
  Future<void> _showDeclineDialog(Map<String, dynamic> requestData) async {
    String? selectedReason;
    final TextEditingController customController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Why are you declining?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'The patient will see this reason.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),

                    ..._rejectionReasons.map((reason) {
                      return RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        value: reason,
                        groupValue: selectedReason,
                        onChanged: (val) {
                          setState(() => selectedReason = val);
                        },
                        title: Text(reason),
                        activeColor: const Color(0xFF1E3A8A),
                      );
                    }),

                    if (selectedReason == 'Other') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: customController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Enter your reason...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade200,
                              foregroundColor: Colors.black87,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (selectedReason == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please pick a reason'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              if (selectedReason == 'Other' &&
                                  customController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please type your reason'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              Navigator.pop(ctx, true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Decline Request'),
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

    if (result == true && selectedReason != null) {
      final finalReason = selectedReason == 'Other'
          ? customController.text.trim()
          : selectedReason;

      await _declineRequest(
        requestId: requestData['requestId'],
        reason: finalReason!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request declined.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    customController.dispose();
  }

  Future<void> _declineRequest({
    required String requestId,
    required String reason,
  }) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chwId = authProvider.user?.uid ?? '';

    await FirebaseFirestore.instance
        .collection('appointment_requests')
        .doc(requestId)
        .update({
      'status': 'Declined',
      'declinedReason': reason,
      'declinedAt': FieldValue.serverTimestamp(),
      'declinedBy': chwId,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Pending Requests'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('appointment_requests')
            .where('status', isEqualTo: 'Pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final requests = snapshot.data?.docs ?? [];

          if (requests.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_available, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No pending requests.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final request = requests[index];
              final data = request.data() as Map<String, dynamic>;
              data['requestId'] = request.id;

              return _buildRequestCard(data);
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> data) {
    return Container(
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
            children: [
              const Icon(Icons.person, color: Color(0xFF1E3A8A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data['patientName'] ?? 'Unknown Patient',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoLine(Icons.calendar_today, 'Date',
              _formatDate(data['requestedDate'])),
          const SizedBox(height: 6),
          _buildInfoLine(Icons.access_time, 'Time',
              data['requestedTime'] ?? 'Not specified'),
          const SizedBox(height: 6),
          _buildInfoLine(Icons.location_on, 'Location',
              data['location'] ?? 'Not specified'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _approveRequest(data),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Approve'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showDeclineDialog(data),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Decline'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoLine(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6B7280)),
        const SizedBox(width: 8),
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
            style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 13),
          ),
        ),
      ],
    );
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return 'Not specified';
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return isoDate;
    }
  }
}