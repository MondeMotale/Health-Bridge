import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';
import '../../auth/auth_provider.dart';
import '../chw/chat_screen.dart';

class PatientMessagesScreen extends StatefulWidget {
  const PatientMessagesScreen({super.key});

  @override
  State<PatientMessagesScreen> createState() => _PatientMessagesScreenState();
}

class _PatientMessagesScreenState extends State<PatientMessagesScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final String? patientUid = authProvider.user?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: patientUid == null
          ? const Center(child: Text('User not logged in'))
          : _buildChwList(patientUid),
    );
  }

  Widget _buildChwList(String patientUid) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirestoreService().getAssignedChw(patientUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final chwList = snapshot.data ?? [];

        if (chwList.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No CHW assigned to you yet.',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: chwList.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final chw = chwList[index];
            return _buildChwCard(chw);
          },
        );
      },
    );
  }

  Widget _buildChwCard(Map<String, dynamic> chw) {
    final String chwName = chw['displayName'] ?? 'CHW';
    final String chwUid = chw['uid'] ?? '';
    final String chwPhone = chw['phoneNumber'] ?? chw['phone'] ?? '';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatWithId: chwUid,
              chatWithName: chwName,
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
              backgroundColor:
                  const Color(0xFF1E3A8A).withValues(alpha: 0.1),
              child: Text(
                chwName.isNotEmpty ? chwName[0].toUpperCase() : '?',
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
                    chwName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    chwPhone.isNotEmpty
                        ? 'Community Health Worker'
                        : 'Community Health Worker',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 13,
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
}