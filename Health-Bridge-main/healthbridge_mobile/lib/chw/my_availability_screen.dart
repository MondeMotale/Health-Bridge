import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/auth_provider.dart';
import '../../models/chw_availability.dart';
import '../../services/availability_service.dart';

class MyAvailabilityScreen extends StatefulWidget {
  const MyAvailabilityScreen({super.key});

  @override
  State<MyAvailabilityScreen> createState() => _MyAvailabilityScreenState();
}

class _MyAvailabilityScreenState extends State<MyAvailabilityScreen> {
  final AvailabilityService _service = AvailabilityService();

  ChwAvailability? _availability;
  bool _isLoading = true;
  bool _isSaving = false;

  static const List<String> _dayOrder = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  static const Map<String, String> _dayLabels = {
    'mon': 'Monday',
    'tue': 'Tuesday',
    'wed': 'Wednesday',
    'thu': 'Thursday',
    'fri': 'Friday',
    'sat': 'Saturday',
    'sun': 'Sunday',
  };

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = authProvider.user?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    final availability = await _service.getAvailability(uid);
    if (mounted) {
      setState(() {
        _availability = availability;
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_availability == null) return;

    setState(() => _isSaving = true);
    try {
      await _service.saveAvailability(_availability!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Availability saved!'),
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
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ---------- ADD TIME SLOT ----------
  Future<void> _addSlot(String day) async {
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Pick START time',
    );
    if (start == null) return;

    final end = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 17, minute: 0),
      helpText: 'Pick END time',
    );
    if (end == null) return;

    // Validate: start < end
    final startMin = start.hour * 60 + start.minute;
    final endMin = end.hour * 60 + end.minute;
    if (endMin <= startMin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('End time must be after start time'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final slot = TimeSlot(
      start: _formatTime(start),
      end: _formatTime(end),
    );

    setState(() {
      final current = _availability!.weekly[day] ?? [];
      _availability!.weekly[day] = [...current, slot];
    });
  }

  // ---------- REMOVE TIME SLOT ----------
  void _removeSlot(String day, int index) {
    setState(() {
      final list = _availability!.weekly[day] ?? [];
      if (index >= 0 && index < list.length) {
        list.removeAt(index);
        _availability!.weekly[day] = list;
      }
    });
  }

  // ---------- ADD EXCEPTION DATE ----------
  Future<void> _addException() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;

    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Reason'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'e.g. Public holiday, Personal leave',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (reason == null || reason.isEmpty) return;

    final dateKey =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';

    setState(() {
      _availability!.exceptions.add(
        ExceptionDate(date: dateKey, reason: reason),
      );
    });
  }

  // ---------- REMOVE EXCEPTION ----------
  void _removeException(int index) {
    setState(() {
      _availability!.exceptions.removeAt(index);
    });
  }

  // ---------- SLOT DURATION DROPDOWN ----------
  void _changeSlotDuration(int? value) {
    if (value == null) return;
    setState(() {
      _availability!.slotDurationMinutes = value;
    });
  }

  String _formatTime(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('My Availability'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _availability == null
              ? const Center(child: Text('Could not load availability.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoBanner(),
                      const SizedBox(height: 20),
                      _buildSlotDurationCard(),
                      const SizedBox(height: 20),
                      const Text(
                        '📅 Weekly Schedule',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._dayOrder.map(_buildDayCard),
                      const SizedBox(height: 24),
                      _buildExceptionsSection(),
                      const SizedBox(height: 24),
                      _buildSaveButton(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  // ---------- Info banner ----------
  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E3A8A).withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF1E3A8A)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Patients can only book appointments during these hours. '
              'Leave a day empty to mark it as unavailable.',
              style: TextStyle(color: Colors.grey.shade800, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Slot duration ----------
  Widget _buildSlotDurationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: Color(0xFF1E3A8A)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Slot Duration',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          DropdownButton<int>(
            value: _availability!.slotDurationMinutes,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 15, child: Text('15 min')),
              DropdownMenuItem(value: 30, child: Text('30 min')),
              DropdownMenuItem(value: 45, child: Text('45 min')),
              DropdownMenuItem(value: 60, child: Text('1 hour')),
            ],
            onChanged: _changeSlotDuration,
          ),
        ],
      ),
    );
  }

  // ---------- Day card ----------
  Widget _buildDayCard(String day) {
    final slots = _availability!.weekly[day] ?? [];
    final isClosed = slots.isEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _dayLabels[day] ?? day,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isClosed ? Colors.grey : const Color(0xFF1A1A2E),
                  ),
                ),
              ),
              if (isClosed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Closed',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          if (slots.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...List.generate(slots.length, (i) {
              final slot = slots[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 16, color: Color(0xFF6B7280)),
                    const SizedBox(width: 8),
                    Text(
                      '${slot.start} – ${slot.end}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      color: Colors.red,
                      onPressed: () => _removeSlot(day, i),
                      tooltip: 'Remove slot',
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _addSlot(day),
            icon: const Icon(Icons.add, size: 18),
            label: Text(slots.isEmpty ? 'Add time slot' : 'Add another slot'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1E3A8A),
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Exceptions section ----------
  Widget _buildExceptionsSection() {
    final exceptions = _availability!.exceptions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🗓️ Date Exceptions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Days off — holidays, personal leave, etc.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (exceptions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No exceptions set.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                )
              else
                ...List.generate(exceptions.length, (i) {
                  final ex = exceptions[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.event_busy,
                            size: 18, color: Color(0xFF6B7280)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ex.date,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                ex.reason,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          color: Colors.red,
                          onPressed: () => _removeException(i),
                          tooltip: 'Remove',
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _addException,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add exception date'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1E3A8A),
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- Save button ----------
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _save,
        icon: _isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.save),
        label: Text(_isSaving ? 'Saving...' : 'Save Availability'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}