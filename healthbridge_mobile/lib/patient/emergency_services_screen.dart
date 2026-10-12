import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../auth/auth_provider.dart';
import '../../models/emergency_contact.dart';
import '../../services/emergency_service.dart';
import 'widgets/sos_button.dart';

class EmergencyServicesScreen extends StatelessWidget {
  const EmergencyServicesScreen({super.key});

  static const List<Map<String, String>> _nationalNumbers = [
    {'label': 'Ambulance', 'number': '10177', 'icon': 'ambulance'},
    {'label': 'Police', 'number': '10111', 'icon': 'police'},
    {'label': 'Emergency (Cell)', 'number': '112', 'icon': 'emergency'},
    {'label': 'Fire', 'number': '10177', 'icon': 'fire'},
    {'label': 'Poison Helpline', 'number': '0861 555 777', 'icon': 'poison'},
  ];

  Future<void> _call(BuildContext context, String number) async {
    final cleaned = number.replaceAll(' ', '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not dial $number')),
        );
      }
    }
  }

  IconData _iconFor(String key) {
    switch (key) {
      case 'ambulance':
        return Icons.local_hospital;
      case 'police':
        return Icons.local_police;
      case 'fire':
        return Icons.local_fire_department;
      case 'poison':
        return Icons.warning_amber_rounded;
      default:
        return Icons.emergency;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = Provider.of<AuthProvider>(context).user?.uid;
    final service = EmergencyService();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Emergency Services'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: uid == null
          ? const Center(child: Text('Not logged in'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---------- SOS CARD ----------
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.sos,
                          size: 36,
                          color: Color(0xFF1E3A8A),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Trigger Emergency SOS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Notifies your CHW and emergency contacts.\nShares your location automatically.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        // ---- Centered, smaller SOS button ----
                        SizedBox(
                          width: 240,
                          height: 56,
                          child: const SosButton(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ---------- MY CONTACTS ----------
                  const Text(
                    'My Emergency Contacts',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<List<EmergencyContact>>(
                    stream: service.watchContacts(uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final contacts = snapshot.data ?? [];
                      if (contacts.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFF59E0B)
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: Color(0xFFF59E0B)),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'No emergency contacts yet. Add one from your Profile.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return Column(
                        children: contacts
                            .map((c) => _buildContactRow(context, c))
                            .toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // ---------- NATIONAL NUMBERS ----------
                  const Text(
                    'National Emergency Numbers',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._nationalNumbers
                      .map((e) => _buildNationalRow(context, e)),

                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildContactRow(BuildContext context, EmergencyContact c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(
            color: const Color(0xFF1E3A8A),
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
            child: Text(
              c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Color(0xFF1E3A8A),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        c.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (c.isPrimary) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A8A)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'PRIMARY',
                          style: TextStyle(
                            color: Color(0xFF1E3A8A),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (c.relationship.isNotEmpty)
                  Text(
                    c.relationship,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.phone, color: Color(0xFF10B981)),
            onPressed: () => _call(context, c.phone),
          ),
        ],
      ),
    );
  }

  Widget _buildNationalRow(BuildContext context, Map<String, String> entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _iconFor(entry['icon']!),
              color: const Color(0xFF1E3A8A),
            ),
          ),
          title: Text(
            entry['label']!,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            entry['number']!,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: const Icon(Icons.phone, color: Color(0xFF10B981)),
          onTap: () => _call(context, entry['number']!),
        ),
      ),
    );
  }
}