import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/appointment.dart';
import '../../models/chw_availability.dart';
import '../../services/firestore_service.dart';
import '../../services/availability_service.dart';
import '../../services/slot_service.dart';
import '../../auth/auth_provider.dart';

class PatientAppointmentsScreen extends StatefulWidget {
  const PatientAppointmentsScreen({super.key});

  @override
  State<PatientAppointmentsScreen> createState() =>
      _PatientAppointmentsScreenState();
}

class _PatientAppointmentsScreenState extends State<PatientAppointmentsScreen> {
  // ---------- REQUEST APPOINTMENT (SLOT-BASED) ----------
  void _showRequestAppointmentDialog(String patientUid) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final String patientName = authProvider.user?.displayName ?? 'Patient';

    // Fetch the patient doc to find the assigned CHW
    final patientSnap = await FirebaseFirestore.instance
        .collection('patients')
        .doc(patientUid)
        .get();

    if (!patientSnap.exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No CHW assigned to you yet.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final chwId = patientSnap.data()?['assignedChwId'] ?? '';
    if (chwId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No CHW assigned to you yet.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Load CHW availability
    final availability = await AvailabilityService().getAvailability(chwId);

    final hasAnyWindow = availability.weekly.values.any((s) => s.isNotEmpty);
    if (!hasAnyWindow) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Your CHW is not accepting appointments at the moment.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _SlotPickerDialog(
        chwId: chwId,
        availability: availability,
        onSubmit: (DateTime chosenSlot) async {
          Navigator.pop(ctx);
          await _submitRequest(
            patientUid: patientUid,
            patientName: patientName,
            requestedDateTime: chosenSlot,
          );
        },
      ),
    );
  }

  Future<void> _submitRequest({
    required String patientUid,
    required String patientName,
    required DateTime requestedDateTime,
  }) async {
    try {
      final location = await _askLocation();
      if (location == null || location.isEmpty) return;

      await FirebaseFirestore.instance.collection('appointment_requests').add({
        'patientId': patientUid,
        'patientName': patientName,
        'requestedDate': requestedDateTime.toIso8601String(),
        'requestedTime': _formatTime(requestedDateTime),
        'location': location,
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request sent! Your CHW will confirm.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<String?> _askLocation() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Where should the CHW meet you?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. 12 Main Street, Soweto',
            prefixIcon: Icon(Icons.location_on),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Confirm Request'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime d) {
    final h = d.hour;
    final m = d.minute.toString().padLeft(2, '0');
    final ampm = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:$m $ampm';
  }

  // ---------- DISMISS DECLINED REQUEST ----------
  Future<void> _dismissDeclined(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove this request?'),
        content: const Text(
            'This will hide it from your list. The CHW still has a record of declining it.'),
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

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('appointment_requests')
          .doc(docId)
          .update({'patientDismissed': true});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from your list.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ---------- BUILD ----------
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
                  // ---------- CONFIRMED ----------
                  const Text('📅 My Appointments',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      )),
                  const SizedBox(height: 12),
                  StreamBuilder<List<Appointment>>(
                    stream: FirestoreService()
                        .getAppointmentsForPatient(patientUid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final appointments = snapshot.data ?? [];
                      if (appointments.isEmpty) {
                        return _emptyCard('No upcoming appointments.');
                      }
                      return Column(
                        children: appointments
                            .map((a) => _appointmentCard(a))
                            .toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // ---------- PENDING ----------
                  const Text('⏳ Pending Requests',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      )),
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
                        return _emptyCard('No pending requests.');
                      }
                      return Column(
                        children: pending
                            .map((d) =>
                                _pendingCard(d.data() as Map<String, dynamic>))
                            .toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // ---------- DECLINED ----------
                  const Text('❌ Declined Requests',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      )),
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
                      final declined = (snapshot.data?.docs ?? [])
                          .where((d) {
                            final data = d.data() as Map<String, dynamic>;
                            return data['patientDismissed'] != true;
                          })
                          .toList();
                      if (declined.isEmpty) {
                        return _emptyCard('No declined requests. 🎉');
                      }
                      return Column(
                        children: declined
                            .map((d) => _declinedCard(
                                d.data() as Map<String, dynamic>, d.id))
                            .toList(),
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

  // ---------- CARD BUILDERS ----------
  Widget _emptyCard(String text) {
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

  Widget _pendingCard(Map<String, dynamic> data) {
    final dt = data['requestedDate'] != null
        ? DateTime.tryParse(data['requestedDate'])
        : null;
    final dateStr =
        dt != null ? DateFormat('MMM d, yyyy').format(dt) : 'Unknown date';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: Colors.orange.shade400, width: 4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time, color: Colors.orange, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$dateStr at ${data['requestedTime'] ?? ''}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(data['location'] ?? '',
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
                style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _declinedCard(Map<String, dynamic> data, String docId) {
    final dt = data['requestedDate'] != null
        ? DateTime.tryParse(data['requestedDate'])
        : null;
    final dateStr =
        dt != null ? DateFormat('MMM d, yyyy').format(dt) : 'Unknown date';
    final reason = data['declinedReason'] ?? 'No reason provided';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: Colors.red.shade400, width: 4)),
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
                    Text('$dateStr at ${data['requestedTime'] ?? ''}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(data['location'] ?? '',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                color: Colors.grey.shade500,
                tooltip: 'Dismiss',
                onPressed: () => _dismissDeclined(docId),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
                const Text('Reason:',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.red)),
                const SizedBox(height: 4),
                Text(reason,
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFF1A1A2E))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _appointmentCard(Appointment appointment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today,
              color: Color(0xFF1E3A8A), size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${DateFormat('MMM d, yyyy').format(appointment.dateTime)} at ${DateFormat('h:mm a').format(appointment.dateTime)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(appointment.location,
                    style: const TextStyle(color: Colors.grey)),
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
            child: Text(appointment.status,
                style: TextStyle(
                  color: appointment.status == 'Scheduled'
                      ? Colors.green
                      : Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// SLOT PICKER DIALOG
// ================================================================
class _SlotPickerDialog extends StatefulWidget {
  final String chwId;
  final ChwAvailability availability;
  final void Function(DateTime chosenSlot) onSubmit;

  const _SlotPickerDialog({
    required this.chwId,
    required this.availability,
    required this.onSubmit,
  });

  @override
  State<_SlotPickerDialog> createState() => _SlotPickerDialogState();
}

class _SlotPickerDialogState extends State<_SlotPickerDialog> {
  late DateTime _selectedDate;
  List<BookableSlot> _slots = [];
  BookableSlot? _selectedSlot;
  bool _isLoadingSlots = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = _nextBookableDate(DateTime.now());
    _loadSlotsForDate(_selectedDate);
  }

  DateTime _nextBookableDate(DateTime from) {
    var d = DateTime(from.year, from.month, from.day);
    for (int i = 0; i < 60; i++) {
      if (!widget.availability.isExceptionDate(d)) {
        final key = _dayKey(d.weekday);
        if ((widget.availability.weekly[key] ?? []).isNotEmpty) {
          return d;
        }
      }
      d = d.add(const Duration(days: 1));
    }
    return DateTime(from.year, from.month, from.day);
  }

  Future<void> _loadSlotsForDate(DateTime date) async {
    setState(() {
      _isLoadingSlots = true;
      _selectedSlot = null;
    });
    final slots = await SlotService().computeSlotsForDate(
      chwId: widget.chwId,
      date: date,
      availability: widget.availability,
    );
    if (mounted) {
      setState(() {
        _slots = slots;
        _isLoadingSlots = false;
      });
    }
  }

  bool _isDateOpen(DateTime date) {
    if (widget.availability.isExceptionDate(date)) return false;
    final key = _dayKey(date.weekday);
    return (widget.availability.weekly[key] ?? []).isNotEmpty;
  }

  String _dayKey(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'mon';
      case DateTime.tuesday:
        return 'tue';
      case DateTime.wednesday:
        return 'wed';
      case DateTime.thursday:
        return 'thu';
      case DateTime.friday:
        return 'fri';
      case DateTime.saturday:
        return 'sat';
      case DateTime.sunday:
        return 'sun';
      default:
        return 'mon';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxHeight: 650),
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Request Appointment',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E))),
            const SizedBox(height: 4),
            Text('Pick an available slot below',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 16),

            _buildCalendar(),
            const SizedBox(height: 16),

            Text(
              'Available slots on ${DateFormat('EEE, MMM d').format(_selectedDate)}',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildSlotsList()),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedSlot == null
                        ? null
                        : () => widget.onSubmit(_selectedSlot!.start),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Request Slot'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    final today = DateTime.now();
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 30,
        itemBuilder: (context, i) {
          final date = DateTime(today.year, today.month, today.day)
              .add(Duration(days: i));
          final isOpen = _isDateOpen(date);
          final isSelected = date.year == _selectedDate.year &&
              date.month == _selectedDate.month &&
              date.day == _selectedDate.day;

          return GestureDetector(
            onTap: isOpen
                ? () {
                    setState(() => _selectedDate = date);
                    _loadSlotsForDate(date);
                  }
                : null,
            child: Container(
              width: 60,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF1E3A8A)
                    : isOpen
                        ? Colors.white
                        : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1E3A8A)
                      : Colors.grey.shade300,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(date),
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? Colors.white70
                          : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : isOpen
                              ? const Color(0xFF1A1A2E)
                              : Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('MMM').format(date),
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected
                          ? Colors.white70
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlotsList() {
    if (_isLoadingSlots) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_slots.isEmpty) {
      return Center(
        child: Text(
          'No slots available on this day.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return ListView.builder(
      itemCount: _slots.length,
      itemBuilder: (context, i) {
        final slot = _slots[i];
        final isSelected = _selectedSlot?.start == slot.start;

        return Opacity(
          opacity: slot.isTaken ? 0.4 : 1.0,
          child: GestureDetector(
            onTap: slot.isTaken
                ? null
                : () => setState(() => _selectedSlot = slot),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1E3A8A) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1E3A8A)
                      : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: isSelected
                        ? Colors.white
                        : const Color(0xFF1E3A8A),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    slot.label,
                    style: TextStyle(
                      color:
                          isSelected ? Colors.white : const Color(0xFF1A1A2E),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (slot.isTaken)
                    const Text('Booked',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}