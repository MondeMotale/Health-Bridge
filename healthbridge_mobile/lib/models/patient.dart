class Patient {
  final String id;
  final String name;
  final int age;
  final String phone;
  final String address;
  final String condition;
  final String status; // 'Stable', 'Needs Follow-up', 'Critical'
  final String notes;
  final String assignedChwId; // The ID of the CHW who created this
  final DateTime createdAt;

  Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.phone,
    required this.address,
    required this.condition,
    required this.status,
    required this.notes,
    required this.assignedChwId,
    required this.createdAt,
  });

  // Convert a Patient object into a Map (for Firebase)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'phone': phone,
      'address': address,
      'condition': condition,
      'status': status,
      'notes': notes,
      'assignedChwId': assignedChwId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create a Patient object from a Map (from Firebase)
  factory Patient.fromMap(Map<String, dynamic> map, String documentId) {
    return Patient(
      id: documentId,
      name: map['name'] ?? '',
      age: map['age'] ?? 0,
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      condition: map['condition'] ?? '',
      status: map['status'] ?? 'Stable',
      notes: map['notes'] ?? '',
      assignedChwId: map['assignedChwId'] ?? '',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}