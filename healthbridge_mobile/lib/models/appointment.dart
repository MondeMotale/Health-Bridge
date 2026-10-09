class Appointment {
  final String id;
  final String patientId;
  final String patientName;
  final String chwId;
  final String chwName;
  final DateTime dateTime; // Scheduled start
  final String location;
  final String notes; // Patient's pre-visit note
  final String status;
  // Status values:
  // 'Requested', 'Scheduled', 'Declined', 'EnRoute', 'InProgress',
  // 'Completed', 'Missed', 'Cancelled', 'Rescheduled'

  // NEW — Post-visit & lifecycle tracking
  final String? chwNotes; // CHW's post-visit notes
  final String? cancellationReason;
  final String? missedReason;
  final DateTime? enRouteAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int? visitDurationMinutes; // Auto-calculated
  final String? followUpRequired; // 'None' / 'Days' / 'Weeks' / 'Months'
  final DateTime? nextFollowUpDate;
  final DateTime? notesLockedAt; // When notes were locked (24h after save, or immediately)

  Appointment({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.chwId,
    required this.chwName,
    required this.dateTime,
    required this.location,
    this.notes = '',
    this.status = 'Scheduled',
    this.chwNotes,
    this.cancellationReason,
    this.missedReason,
    this.enRouteAt,
    this.startedAt,
    this.completedAt,
    this.visitDurationMinutes,
    this.followUpRequired,
    this.nextFollowUpDate,
    this.notesLockedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'chwId': chwId,
      'chwName': chwName,
      'dateTime': dateTime.toIso8601String(),
      'location': location,
      'notes': notes,
      'status': status,
      'chwNotes': chwNotes,
      'cancellationReason': cancellationReason,
      'missedReason': missedReason,
      'enRouteAt': enRouteAt?.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'visitDurationMinutes': visitDurationMinutes,
      'followUpRequired': followUpRequired,
      'nextFollowUpDate': nextFollowUpDate?.toIso8601String(),
      'notesLockedAt': notesLockedAt?.toIso8601String(),
    };
  }

  factory Appointment.fromMap(Map<String, dynamic> map, String documentId) {
    return Appointment(
      id: documentId,
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'] ?? 'Unknown',
      chwId: map['chwId'] ?? '',
      chwName: map['chwName'] ?? 'CHW',
      dateTime: DateTime.tryParse(map['dateTime'] ?? '') ?? DateTime.now(),
      location: map['location'] ?? 'N/A',
      notes: map['notes'] ?? '',
      status: map['status'] ?? 'Scheduled',
      chwNotes: map['chwNotes'],
      cancellationReason: map['cancellationReason'],
      missedReason: map['missedReason'],
      enRouteAt: map['enRouteAt'] != null
          ? DateTime.tryParse(map['enRouteAt'])
          : null,
      startedAt: map['startedAt'] != null
          ? DateTime.tryParse(map['startedAt'])
          : null,
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'])
          : null,
      visitDurationMinutes: map['visitDurationMinutes'],
      followUpRequired: map['followUpRequired'],
      nextFollowUpDate: map['nextFollowUpDate'] != null
          ? DateTime.tryParse(map['nextFollowUpDate'])
          : null,
      notesLockedAt: map['notesLockedAt'] != null
          ? DateTime.tryParse(map['notesLockedAt'])
          : null,
    );
  }

  /// Whether the notes are locked and cannot be edited.
  bool get isNotesLocked => notesLockedAt != null;

  /// Helper: is this appointment happening today?
  bool get isToday {
    final now = DateTime.now();
    return dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
  }

  /// Helper: is this appointment upcoming (in the future)?
  bool get isUpcoming => dateTime.isAfter(DateTime.now());
}