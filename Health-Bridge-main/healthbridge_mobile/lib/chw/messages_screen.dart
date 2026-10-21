import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/patient.dart';
import '../../services/firestore_service.dart';
import '../../auth/auth_provider.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final String? chwId = authProvider.user?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: chwId == null
          ? const Center(child: Text('User not logged in'))
          : StreamBuilder<List<Patient>>(
              stream: FirestoreService().getPatientsForMessages(chwId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final patients = snapshot.data ?? [];

                if (patients.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No patients assigned to you yet.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: patients.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final patient = patients[index];
                    return _buildPatientCard(patient);
                  },
                );
              },
            ),
    );
  }

  Widget _buildPatientCard(Patient patient) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatWithId: patient.id, // <--- Uses the patient's UNIQUE UID!
              chatWithName: patient.name,
            ),
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
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
              child: Text(
                patient.name.isNotEmpty ? patient.name[0] : '?',
                style: const TextStyle(
                  color: Color(0xFF1E3A8A),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
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
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${patient.age} yrs • ${patient.condition}',
                    style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
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
}