/// Data model for a CHW's weekly availability + exception dates.
///
/// Stored in Firestore at `chw_availability/{chwUid}`.
class ChwAvailability {
  final String chwId;
  int slotDurationMinutes;
  Map<String, List<TimeSlot>> weekly;
  List<ExceptionDate> exceptions;
  final DateTime? updatedAt;

  ChwAvailability({
    required this.chwId,
    this.slotDurationMinutes = 30,
    required this.weekly,
    List<ExceptionDate>? exceptions,
    this.updatedAt,
  }) : exceptions = exceptions ?? <ExceptionDate>[];

  /// Returns an availability with default business-hours setup:
  /// Mon–Fri 09:00–17:00, Sat 09:00–12:00, Sun closed.
  factory ChwAvailability.defaults(String chwId) {
    return ChwAvailability(
      chwId: chwId,
      weekly: {
        'mon': [TimeSlot(start: '09:00', end: '17:00')],
        'tue': [TimeSlot(start: '09:00', end: '17:00')],
        'wed': [TimeSlot(start: '09:00', end: '17:00')],
        'thu': [TimeSlot(start: '09:00', end: '17:00')],
        'fri': [TimeSlot(start: '09:00', end: '17:00')],
        'sat': [TimeSlot(start: '09:00', end: '12:00')],
        'sun': [],
      },
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chwId': chwId,
      'slotDurationMinutes': slotDurationMinutes,
      'weekly': weekly.map(
        (key, slots) => MapEntry(key, slots.map((s) => s.toMap()).toList()),
      ),
      'exceptions': exceptions.map((e) => e.toMap()).toList(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory ChwAvailability.fromMap(Map<String, dynamic> map) {
    final weeklyRaw = map['weekly'] as Map<String, dynamic>? ?? {};

    final weekly = <String, List<TimeSlot>>{};
    for (final day in ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']) {
      final list = weeklyRaw[day] as List<dynamic>? ?? [];
      weekly[day] = list
          .map((e) => TimeSlot.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }

    final exceptionsRaw = map['exceptions'] as List<dynamic>? ?? [];
    final exceptions = exceptionsRaw
        .map((e) => ExceptionDate.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    return ChwAvailability(
      chwId: map['chwId'] ?? '',
      slotDurationMinutes: map['slotDurationMinutes'] ?? 30,
      weekly: weekly,
      exceptions: exceptions,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'])
          : null,
    );
  }

  /// Returns true if the given date is an exception (CHW not available).
  bool isExceptionDate(DateTime date) {
    final key = _dateKey(date);
    return exceptions.any((e) => e.date == key);
  }

  /// Returns slots for the given weekday (0=Mon, 6=Sun).
  List<TimeSlot> slotsForWeekday(int weekday) {
    final key = _weekdayKey(weekday);
    return weekly[key] ?? [];
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

  static String _dateKey(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

/// A single time slot on a given day (e.g. 09:00–12:00).
class TimeSlot {
  final String start; // "09:00"
  final String end;   // "12:00"

  TimeSlot({required this.start, required this.end});

  Map<String, dynamic> toMap() => {'start': start, 'end': end};

  factory TimeSlot.fromMap(Map<String, dynamic> map) {
    return TimeSlot(
      start: map['start'] ?? '09:00',
      end: map['end'] ?? '17:00',
    );
  }
}

/// An exception date when the CHW is unavailable.
class ExceptionDate {
  final String date;   // "2026-10-15"
  final String reason; // "Public holiday"

  ExceptionDate({required this.date, required this.reason});

  Map<String, dynamic> toMap() => {'date': date, 'reason': reason};

  factory ExceptionDate.fromMap(Map<String, dynamic> map) {
    return ExceptionDate(
      date: map['date'] ?? '',
      reason: map['reason'] ?? '',
    );
  }
}