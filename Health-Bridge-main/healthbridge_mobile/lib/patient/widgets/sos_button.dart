import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/auth_provider.dart';
import '../../models/emergency_contact.dart';
import '../../services/emergency_service.dart';
import '../../services/location_service.dart';

class SosButton extends StatefulWidget {
  const SosButton({super.key});

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> {
  final EmergencyService _service = EmergencyService();
  bool _isProcessing = false;

  Future<void> _onPressed() async {
    if (_isProcessing) return;
    final confirmed = await _showCountdownDialog();
    if (!confirmed) return;
    if (!mounted) return;

    setState(() => _isProcessing = true);
    try {
      await _triggerSos();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<bool> _showCountdownDialog() async {
    int secondsLeft = 5;
    Timer? ticker;

    try {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              ticker ??= Timer.periodic(const Duration(seconds: 1), (t) {
                if (!context.mounted) {
                  t.cancel();
                  return;
                }
                if (secondsLeft > 1) {
                  setDialogState(() => secondsLeft--);
                } else {
                  t.cancel();
                  if (Navigator.of(ctx).canPop()) {
                    Navigator.of(ctx).pop(true);
                  }
                }
              });

              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                backgroundColor: const Color(0xFFEF4444),
                insetPadding: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.white, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'Sending SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your CHW and emergency contacts will be notified.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        child: Center(
                          child: Text(
                            '$secondsLeft',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 52,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            ticker?.cancel();
                            if (Navigator.of(ctx).canPop()) {
                              Navigator.of(ctx).pop(false);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(
                                color: Colors.white, width: 2),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'CANCEL',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
      return result ?? false;
    } finally {
      ticker?.cancel();
    }
  }

  Future<void> _triggerSos() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = authProvider.user?.uid;
    if (uid == null) return;

    // Get the real patient name
    String name = 'Unknown Patient';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(uid)
          .get();
      final realName = (doc.data()?['name'] as String?)?.trim() ?? '';
      if (realName.isNotEmpty) {
        name = realName;
      } else {
        name = authProvider.user?.displayName ?? 'Unknown Patient';
      }
    } catch (_) {
      name = authProvider.user?.displayName ?? 'Unknown Patient';
    }

    // Fetch location with proper error handling
    final loc = await LocationService.fetch();
    final lat = loc.latitude ?? 0.0;
    final lng = loc.longitude ?? 0.0;
    final address = loc.hasLocation
        ? LocationService.formatLatLng(lat, lng)
        : null;

    if (!mounted) return;

    // Warn if no location — but STILL send the SOS
    if (!loc.hasLocation && loc.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('SOS sent without location: ${loc.error}'),
          backgroundColor: const Color(0xFFF59E0B),
          duration: const Duration(seconds: 5),
        ),
      );
    }

    String? alertId;
    try {
      alertId = await _service.triggerAlert(
        patientId: uid,
        patientName: name,
        latitude: lat,
        longitude: lng,
        address: address,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send SOS: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }

    if (!mounted) return;

    final contacts = await _service.getContacts(uid);
    EmergencyContact? primary;
    if (contacts.isNotEmpty) {
      primary = contacts.firstWhere(
        (c) => c.isPrimary,
        orElse: () => contacts.first,
      );
    }

    if (!mounted) return;

    _showSentDialog(
      alertId: alertId,
      primary: primary,
      lat: lat,
      lng: lng,
      hasLocation: loc.hasLocation,
    );

    if (primary != null) {
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) _call(primary.phone);
    }
  }

  void _showSentDialog({
    required String alertId,
    required EmergencyContact? primary,
    required double lat,
    required double lng,
    required bool hasLocation,
  }) {
    final primaryPhone = primary?.phone;
    final primaryName = primary?.name ?? '';
    final primaryRelationship = primary?.relationship ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle,
                        color: Color(0xFF10B981), size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SOS sent',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A2E))),
                        SizedBox(height: 2),
                        Text('Help is on the way',
                            style: TextStyle(
                                fontSize: 14, color: Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your location',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF1A1A2E))),
                    const SizedBox(height: 4),
                    Text(
                      hasLocation
                          ? LocationService.formatLatLng(lat, lng)
                          : 'Not available — CHW has been notified',
                      style: TextStyle(
                        color: hasLocation
                            ? const Color(0xFF6B7280)
                            : const Color(0xFFF59E0B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (primary != null) ...[
                const Text('If you can, stay on the line with:',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _call(primaryPhone!),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF10B981)
                              .withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.phone, color: Color(0xFF10B981)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(primaryName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                              if (primaryRelationship.isNotEmpty)
                                Text(primaryRelationship,
                                    style: const TextStyle(
                                        color: Color(0xFF6B7280),
                                        fontSize: 12)),
                            ],
                          ),
                        ),
                        const Text('Call',
                            style: TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final cancel = await _confirmCancel();
                    if (cancel == true) {
                      await _service.cancelAlert(alertId,
                          reason: 'Patient confirmed they are OK');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('SOS cancelled'),
                              backgroundColor: Colors.grey),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("I'm OK — Cancel SOS"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmCancel() async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel SOS?'),
        content: const Text(
            'Only cancel if you are safe. Your CHW will be told you cancelled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep SOS active'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, cancel',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEF4444),
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: const Color(0xFFEF4444).withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: _isProcessing
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sos, size: 24, color: Colors.white),
                  SizedBox(width: 10),
                  Text('SEND SOS',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          letterSpacing: 1.0,
                          color: Colors.white)),
                ],
              ),
      ),
    );
  }
}