import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/auth_provider.dart';
import '../../models/emergency_contact.dart';
import '../../services/emergency_service.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final EmergencyService _service = EmergencyService();

  void _openEditDialog(EmergencyContact? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final relationshipCtrl =
        TextEditingController(text: existing?.relationship ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    bool isPrimary = existing?.isPrimary ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
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
                Text(
                  existing == null ? 'Add Emergency Contact' : 'Edit Contact',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 20),
                _field('Name', nameCtrl, Icons.person),
                const SizedBox(height: 12),
                _field('Relationship', relationshipCtrl, Icons.people),
                const SizedBox(height: 12),
                _field('Phone Number', phoneCtrl, Icons.phone,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _field('Notes (optional)', notesCtrl, Icons.notes, maxLines: 2),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Set as primary contact'),
                  subtitle: const Text(
                    'This person is called first when you trigger SOS',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: isPrimary,
                  activeColor: const Color(0xFFEF4444),
                  onChanged: (val) =>
                      setDialogState(() => isPrimary = val ?? false),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (nameCtrl.text.trim().isEmpty ||
                              phoneCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Name and phone are required'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          final authProvider =
                              Provider.of<AuthProvider>(context, listen: false);
                          final uid = authProvider.user?.uid;
                          if (uid == null) return;

                          final contact = EmergencyContact(
                            id: existing?.id ??
                                DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString(),
                            name: nameCtrl.text.trim(),
                            relationship: relationshipCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                            isPrimary: isPrimary,
                            notes: notesCtrl.text.trim().isEmpty
                                ? null
                                : notesCtrl.text.trim(),
                          );

                          if (existing == null) {
                            await _service.addContact(uid, contact);
                          } else {
                            await _service.updateContact(uid, contact);
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(existing == null ? 'Add' : 'Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not call $phone')),
        );
      }
    }
  }

  Future<void> _confirmDelete(EmergencyContact c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove contact?'),
        content: Text('Remove ${c.name} from your emergency contacts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      final uid = Provider.of<AuthProvider>(context, listen: false).user?.uid;
      if (uid != null) await _service.deleteContact(uid, c.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = Provider.of<AuthProvider>(context).user?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: uid == null
          ? const Center(child: Text('Not logged in'))
          : StreamBuilder<List<EmergencyContact>>(
              stream: _service.watchContacts(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Semantics(
                      label: 'Loading emergency contacts',
                      liveRegion: true,
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          "Couldn't load emergency contacts. Check your connection.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF1A1A2E)),
                        ),
                      ),
                    ),
                  );
                }
                final contacts = snapshot.data ?? [];
                if (contacts.isEmpty) {
                  return Semantics(
                    label:
                        'No emergency contacts. Add at least one person we can call if you ever need help.',
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ExcludeSemantics(
                              child: Icon(
                                Icons.contact_emergency,
                                size: 64,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No emergency contacts yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Color(0xFF4B5563),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Add at least one person we can call\nif you ever need help.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF4B5563)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: contacts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _buildContactCard(contacts[i]),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditDialog(null),
        backgroundColor: const Color(0xFF1E3A8A),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Contact', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildContactCard(EmergencyContact c) {
    return InkWell(
      onTap: () => _openEditDialog(c),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(
              color: c.isPrimary
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF1E3A8A),
              width: 4,
            ),
          ),
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
                CircleAvatar(
                  backgroundColor:
                      const Color(0xFF1E3A8A).withValues(alpha: 0.1),
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
                                fontSize: 16,
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
                                color: const Color(0xFFEF4444)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'PRIMARY',
                                style: TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
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
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Call ${c.name}',
                  icon: const Icon(Icons.phone, color: Color(0xFF10B981)),
                  onPressed: () => _call(c.phone),
                ),
                IconButton(
                  tooltip: 'Delete ${c.name}',
                  icon: const Icon(Icons.delete_outline,
                      color: Color(0xFFEF4444)),
                  onPressed: () => _confirmDelete(c),
                ),
              ],
            ),
            if (c.notes != null && c.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  c.notes!,
                  style: const TextStyle(
                    color: Color(0xFF1E3A8A),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
