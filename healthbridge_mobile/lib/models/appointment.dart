class Appointment {
  final String id;
  final String patientId;
  final String patientName;
  final String chwId;
  final String chwName;
  final DateTime dateTime;
  final String location;
  final String notes;
  final String status; // 'Scheduled', 'Completed', 'Cancelled'

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
    );
  }
}