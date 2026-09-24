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
  Future<void> _approveRequest(Map<String, dynamic> requestData) async {
    // 1. Get the CHW's UID
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chwId = authProvider.user?.uid ?? '';

    // 2. Create the real Appointment object
    final appointment = Appointment(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // Simple unique ID
      patientId: requestData['patientId'],
      patientName: requestData['patientName'],
      chwId: chwId,
      chwName: 'CHW', // You can make this dynamic later
      dateTime: DateTime.parse(requestData['requestedDate']),
      location: requestData['location'],
      notes: 'Requested by Patient',
      status: 'Scheduled',
    );

    // 3. Save the appointment to Firestore
    await AppointmentService().bookAppointment(appointment);

    // 4. Update the request status to 'Approved'
    await FirebaseFirestore.instance.collection('appointment_requests').doc(requestData['requestId']).update({
      'status': 'Approved',
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment approved!'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _declineRequest(String requestId) async {
    await FirebaseFirestore.instance.collection('appointment_requests').doc(requestId).update({
      'status': 'Declined',
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request declined.'), backgroundColor: Colors.red),
      );
    }
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
                  Text('No pending requests.', style: TextStyle(fontSize: 18, color: Colors.grey)),
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

              return Container(
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
                      children: [
                        const Icon(Icons.person, color: Color(0xFF1E3A8A)),
                        const SizedBox(width: 8),
                        Text(
                          data['patientName'] ?? 'Unknown Patient',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('📅 Date: ${data['requestedDate']}'),
                    Text('🕒 Time: ${data['requestedTime']}'),
                    Text('📍 Location: ${data['location'] ?? 'Not specified'}'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _approveRequest(data),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Approve'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _declineRequest(request.id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Decline'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}