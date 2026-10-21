import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chw_availability.dart';

/// A single bookable slot on a specific date.
class BookableSlot {
  final DateTime start;
  final DateTime end;
  final bool isTaken;

  BookableSlot({
    required this.start,
    required this.end,
    required this.isTaken,
  });

  String get label {
    return '${_two(start.hour)}:${_two(start.minute)} – '
        '${_two(end.hour)}:${_two(end.minute)}';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

class SlotService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Compute all bookable slots for a specific date + CHW.
  Future<List<BookableSlot>> computeSlotsForDate({
    required String chwId,
    required DateTime date,
    required ChwAvailability availability,
  }) async {
    // Normalize to midnight
    final day = DateTime(date.year, date.month, date.day);

    // Step 1: Exceptions block the whole day
    if (availability.isExceptionDate(day)) return [];

    // Step 2: Weekly windows for this weekday
    final weekdayIndex = day.weekday; // 1 = Mon ... 7 = Sun
    final dayKey = _weekdayKey(weekdayIndex);
    final windows = availability.weekly[dayKey] ?? [];
    if (windows.isEmpty) return [];

    // Step 3: Fetch existing appointments for that day
    final takenRanges = await _fetchTakenRanges(chwId: chwId, day: day);

    // Step 4: Generate slots
    final duration = availability.slotDurationMinutes;
    final slots = <BookableSlot>[];

    for (final window in windows) {
      final windowStartMin = _toMinutes(window.start);
      final windowEndMin = _toMinutes(window.end);

      int cursor = windowStartMin;
      while (cursor + duration <= windowEndMin) {
        final slotStart = day.add(Duration(minutes: cursor));
        final slotEnd = slotStart.add(Duration(minutes: duration));

        final taken = takenRanges.any((r) =>
            slotStart.isBefore(r.end) && slotEnd.isAfter(r.start));

        // Skip slots in the past for today
        final now = DateTime.now();
        if (slotEnd.isAfter(now)) {
          slots.add(BookableSlot(
            start: slotStart,
            end: slotEnd,
            isTaken: taken,
          ));
        }

        cursor += duration;
      }
    }

    // Sort by start time
    slots.sort((a, b) => a.start.compareTo(b.start));
    return slots;
  }

  /// Fetch today's existing appointments so we can mark those slots taken.
  Future<List<DateTimeRange>> _fetchTakenRanges({
    required String chwId,
    required DateTime day,
  }) async {
    try {
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final snap = await _firestore
          .collection('appointments')
          .where('chwId', isEqualTo: chwId)
          .where('status', whereIn: ['Scheduled', 'Completed'])
          .get();

      final ranges = <DateTimeRange>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final dtRaw = data['dateTime'];
        if (dtRaw == null) continue;

        DateTime? dt;
        if (dtRaw is Timestamp) {
          dt = dtRaw.toDate();
        } else if (dtRaw is String) {
          dt = DateTime.tryParse(dtRaw);
        }
        if (dt == null) continue;

        // Only keep appointments on this day
        if (dt.isBefore(dayStart) || dt.isAfter(dayEnd)) continue;

        // Assume appointments last one slot duration — we don't store end time.
        ranges.add(DateTimeRange(
          start: dt,
          end: dt.add(const Duration(minutes: 30)),
        ));
      }
      return ranges;
    } catch (_) {
      return [];
    }
  }

  static int _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  static String _weekdayKey(int weekday) {
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
}