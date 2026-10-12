import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/emergency_alert.dart';
import '../../models/emergency_contact.dart';
import '../../services/emergency_service.dart';
import '../../auth/auth_provider.dart';
import '../../widgets/centered_toast.dart';

class EmergencyAlertDetailScreen extends StatefulWidget {
  final String alertId;
  final String? chwName;

  const EmergencyAlertDetailScreen({
    super.key,
    required this.alertId,
    this.chwName,
  });

  @override
  State<EmergencyAlertDetailScreen> createState() =>
      _EmergencyAlertDetailScreenState();
}

class _EmergencyAlertDetailScreenState
    extends State<EmergencyAlertDetailScreen> {
  final EmergencyService _service = EmergencyService();
  bool _isProcessing = false;

  // ============================================================
  // HELPERS
  // ============================================================
  Future<void> _call(String phone) async {
    final cleaned = phone.replaceAll(' ', '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      showCenterToast(
        context,
        message: 'Could not dial $phone',
        color: const Color(0xFFEF4444),
        icon: Icons.error_outline,
      );
    }
  }

  Future<void> _openInMaps(double lat, double lng) async {
    // Try the native geo: scheme first (Android maps app)
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      return;
    }
    // Fallback: universal Google Maps web URL
    final webUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
      return;
    }
    if (mounted) {
      showCenterToast(
        context,
        message: 'Could not open Maps',
        color: const Color(0xFFEF4444),
        icon: Icons.error_outline,
      );
    }
  }

  // ============================================================
  // ACTIONS
  // ============================================================
  Future<void> _markResponding(String responseType) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final chwName =
          widget.chwName ?? authProvider.user?.displayName ?? 'CHW';

      await _service.markResponding(
        widget.alertId,
        chwName,
        responseType: responseType,
      );

      if (!mounted) return;
      final msg = responseType == 'coming'
          ? 'Patient notified you are on the way'
          : 'Patient notified that help is being sent';
      showCenterToast(
        context,
        message: msg,
        color: responseType == 'coming'
            ? const Color(0xFFF59E0B)
            : const Color(0xFF3B82F6),
        icon: responseType == 'coming'
            ? Icons.directions_run
            : Icons.local_hospital,
        duration: const Duration(seconds: 3),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _resolve() async {
    final notesCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        insetPadding: const EdgeInsets.all(20),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Resolve Emergency',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Describe what happened and what action was taken.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText:
                      'e.g. Patient was experiencing chest pain. Ambulance dispatched, patient stable.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (notesCtrl.text.trim().isEmpty) {
                        showCenterToast(
                          ctx,
                          message: 'Please add a short note before resolving',
                          color: const Color(0xFFEF4444),
                          icon: Icons.error_outline,
                        );
                        return;
                      }
                      Navigator.pop(ctx, true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Mark Resolved'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isProcessing = true);
    try {
      await _service.resolveAlert(
        widget.alertId,
        notes: notesCtrl.text.trim(),
      );
      if (mounted) {
        showCenterToast(
          context,
          message: 'Emergency resolved',
          color: const Color(0xFF10B981),
          icon: Icons.check_circle,
          duration: const Duration(seconds: 3),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Emergency Alert'),
        backgroundColor: const Color.fromARGB(255, 16, 16, 124),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<EmergencyAlert?>(
        stream: _service.watchAlert(widget.alertId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final alert = snapshot.data;
          if (alert == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'This alert no longer exists.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          final isResolved = alert.status == 'resolved' ||
              alert.status == 'cancelled' ||
              alert.status == 'false_alarm';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(alert),
                const SizedBox(height: 16),
                _buildLocationCard(alert),
                const SizedBox(height: 16),
                _buildEmergencyContactsSection(alert),
                const SizedBox(height: 24),

                if (!isResolved)
                  _buildActionButtons(alert),

                if (isResolved) _buildResolvedSummary(alert),

                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // 1. HEADER
  // ============================================================
  Widget _buildHeaderCard(EmergencyAlert alert) {
    final isResponding = alert.status == 'responding';
    final isResolved = alert.status == 'resolved' ||
        alert.status == 'cancelled' ||
        alert.status == 'false_alarm';

    // Color based on response type
    Color statusColor;
    if (isResponding) {
      statusColor = alert.responseType == 'help_sent'
          ? const Color(0xFF3B82F6) // blue
          : const Color(0xFFF59E0B); // orange
    } else if (isResolved) {
      statusColor = const Color(0xFF6B7280);
    } else {
      statusColor = const Color(0xFFEF4444);
    }

    String statusLabel;
    if (isResponding) {
      statusLabel = alert.responseType == 'help_sent'
          ? 'Help sent'
          : 'You are responding';
    } else if (alert.status == 'resolved') {
      statusLabel = 'Resolved';
    } else if (alert.status == 'cancelled') {
      statusLabel = 'Cancelled by patient';
    } else if (alert.status == 'false_alarm') {
      statusLabel = 'False alarm';
    } else {
      statusLabel = 'Active emergency';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: statusColor, width: 5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                alert.patientName.isNotEmpty
                    ? alert.patientName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.patientName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  alert.timeSinceCreated,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 2. LOCATION
  // ============================================================
  Widget _buildLocationCard(EmergencyAlert alert) {
    final hasLocation = alert.latitude != 0.0 || alert.longitude != 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.location_on,
                    color: Color(0xFF1E3A8A), size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Patient Location',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasLocation) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${alert.latitude.toStringAsFixed(5)}, ${alert.longitude.toStringAsFixed(5)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1A1A2E),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: ElevatedButton.icon(
                onPressed: () => _openInMaps(alert.latitude, alert.longitude),
                icon: const Icon(Icons.navigation, size: 18),
                label: const Text('Navigate in Google Maps'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ] else
            const Text(
              'Location not available for this alert.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // 3. EMERGENCY CONTACTS
  // ============================================================
  Widget _buildEmergencyContactsSection(EmergencyAlert alert) {
    return StreamBuilder<List<EmergencyContact>>(
      stream: _service.watchContacts(alert.patientId),
      builder: (context, snapshot) {
        final contacts = snapshot.data ?? [];

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.contact_emergency,
                        color: Color(0xFF1E3A8A), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Emergency Contacts',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap a contact to call them',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 14),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (contacts.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'No emergency contacts on file for this patient.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                )
              else
                ...contacts.map(_buildContactTile),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContactTile(EmergencyContact c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _call(c.phone),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(12),
              border: c.isPrimary
                  ? Border.all(
                      color: const Color(0xFF1E3A8A).withValues(alpha: 0.35),
                      width: 1.5,
                    )
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
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
                                fontSize: 14,
                                color: Color(0xFF1A1A2E),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (c.isPrimary) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3A8A)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'PRIMARY',
                                style: TextStyle(
                                  color: Color(0xFF1E3A8A),
                                  fontSize: 9,
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
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phone,
                      color: Color(0xFF10B981), size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 4. ACTION BUTTONS
  // ============================================================
  Widget _buildActionButtons(EmergencyAlert alert) {
    // State: active → two options (coming / help sent)
    if (alert.status == 'active') {
      return Column(
        children: [
          const Text(
            'How are you responding?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              _responseButton(
                icon: Icons.directions_run,
                label: "I'M COMING",
                color: const Color(0xFFF59E0B),
                onTap: _isProcessing
                    ? null
                    : () => _markResponding('coming'),
              ),
              _responseButton(
                icon: Icons.local_hospital,
                label: 'HELP SENT',
                color: const Color(0xFF3B82F6),
                onTap: _isProcessing
                    ? null
                    : () => _markResponding('help_sent'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Patient will see which option you chose.',
            style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
        ],
      );
    }

    // State: responding → Mark as Resolved
    if (alert.status == 'responding') {
      return Center(
        child: ElevatedButton.icon(
          onPressed: _isProcessing ? null : _resolve,
          icon: const Icon(Icons.check_circle, size: 20),
          label: const Text(
            'MARK AS RESOLVED',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            elevation: 3,
            shadowColor: const Color(0xFF10B981).withValues(alpha: 0.4),
            padding: const EdgeInsets.symmetric(
              horizontal: 28,
              vertical: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _responseButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 3,
        shadowColor: color.withValues(alpha: 0.4),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  // ============================================================
  // 5. RESOLVED SUMMARY
  // ============================================================
  Widget _buildResolvedSummary(EmergencyAlert alert) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    color: Color(0xFF10B981), size: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                'Alert Resolved',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          if (alert.resolutionNotes != null &&
              alert.resolutionNotes!.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Notes',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              alert.resolutionNotes!,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1A1A2E),
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}