import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/emergency_contact.dart';
import '../../models/patient.dart';
import '../../services/emergency_service.dart';

class PatientEmergencyContactsView extends StatefulWidget {
  final Patient patient;
  final bool canEdit; // CHW can edit if patient cannot do it themselves

  const PatientEmergencyContactsView({
    super.key,
    required this.patient,
    this.canEdit = true,
  });

  @override
  State<PatientEmergencyContactsView> createState() =>
      _PatientEmergencyContactsViewState();
}

class _PatientEmergencyContactsViewState
    extends State<PatientEmergencyContactsView> {
  final EmergencyService _service = EmergencyService();

  // ---- EDIT DIALOG ----
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
                const SizedBox(height: 4),
                Text(
                  'For ${widget.patient.name}',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
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
                  title: const Text('Primary contact'),
                  subtitle: const Text(
                    'Called first when SOS is triggered',
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
                            await _service.addContact(
                                widget.patient.id, contact);
                          } else {
                            await _service.updateContact(
                                widget.patient.id, contact);
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
        content: Text(
            'Remove ${c.name} from ${widget.patient.name}\'s emergency contacts?'),
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
      await _service.deleteContact(widget.patient.id, c.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('${widget.patient.name}\'s Contacts'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<EmergencyContact>>(
        stream: _service.watchContacts(widget.patient.id),
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
            final emptyHelp = widget.canEdit
                ? 'Add at least one person who can be reached if ${widget.patient.name} is unreachable.'
                : '${widget.patient.name} has not added any emergency contacts yet.';
            return Semantics(
              label: 'No emergency contacts. $emptyHelp',
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const ExcludeSemantics(
                        child: Icon(
                          Icons.contact_emergency,
                          size: 64,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No emergency contacts',
                        style: TextStyle(
                          fontSize: 18,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        emptyHelp,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF4B5563)),
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
      floatingActionButton: widget.canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _openEditDialog(null),
              backgroundColor: const Color(0xFF1E3A8A),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Contact',
                  style: TextStyle(color: Colors.white)),
            )
          : null,
    );
  }

  Widget _buildContactCard(EmergencyContact c) {
    return InkWell(
      onTap: widget.canEdit ? () => _openEditDialog(c) : null,
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
                // Tap-to-call — biggest action
                Material(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.phone, color: Color(0xFF10B981)),
                    onPressed: () => _call(c.phone),
                    tooltip: 'Call ${c.name}',
                  ),
                ),
                if (widget.canEdit) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Color(0xFFEF4444)),
                    onPressed: () => _confirmDelete(c),
                  ),
                ],
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
