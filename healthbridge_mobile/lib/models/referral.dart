class Referral {
  final String id;
  final String patientId;
  final String patientName;
  final String chwId;
  final String chwName;
  final String condition;
  final String department;
  final String location;
  final String urgency; // 'Low', 'Medium', 'High', 'Critical'
  final String status;  // 'Pending', 'In Review', 'Approved', 'Completed'
  final DateTime createdAt;
  final DateTime? appointmentDate;

  Referral({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.chwId,
    required this.chwName,
    required this.condition,
    required this.department,
    required this.location,
    required this.urgency,
    required this.status,
    required this.createdAt,
    this.appointmentDate,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'chwId': chwId,
      'chwName': chwName,
      'condition': condition,
      'department': department,
      'location': location,
      'urgency': urgency,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'appointmentDate': appointmentDate?.toIso8601String(),
    };
  }

  // Create from Firestore Map
  factory Referral.fromMap(Map<String, dynamic> map, String documentId) {
    return Referral(
      id: documentId,
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'] ?? 'Unknown',
      chwId: map['chwId'] ?? '',
      chwName: map['chwName'] ?? 'CHW',
      condition: map['condition'] ?? '',
      department: map['department'] ?? 'General',
      location: map['location'] ?? 'N/A',
      urgency: map['urgency'] ?? 'Medium',
      status: map['status'] ?? 'Pending',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      appointmentDate: map['appointmentDate'] != null 
          ? DateTime.tryParse(map['appointmentDate']) 
          : null,
    );
  }
}