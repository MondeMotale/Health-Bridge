import 'package:cloud_firestore/cloud_firestore.dart';
import 'emergency_contact.dart';

class Patient {
  final String id;
  final String name;
  final int age;
  final String phone;
  final String address;
  final String condition;      // Human-readable condition name
  final String? icd10Code;     // e.g. "I10", "E11.9"
  final String saIdNumber;     // South African ID number (13 digits)
  final String status;         // 'Stable', 'Needs Follow-up', 'Critical'
  final String notes;
  final String assignedChwId;
  final DateTime createdAt;
  final List<EmergencyContact> emergencyContacts;

  Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.phone,
    required this.address,
    required this.condition,
    this.icd10Code,
    this.saIdNumber = '',
    required this.status,
    required this.notes,
    required this.assignedChwId,
    required this.createdAt,
    this.emergencyContacts = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'phone': phone,
      'address': address,
      'condition': condition,
      'icd10Code': icd10Code,
      'saIdNumber': saIdNumber,
      'status': status,
      'notes': notes,
      'assignedChwId': assignedChwId,
      'createdAt': createdAt.toIso8601String(),
      'emergencyContacts':
          emergencyContacts.map((c) => c.toMap()).toList(),
    };
  }

  factory Patient.fromMap(Map<String, dynamic> map, String documentId) {
    final rawContacts = map['emergencyContacts'];
    List<EmergencyContact> contacts = [];
    if (rawContacts is List) {
      contacts = rawContacts
          .whereType<Map>()
          .map((e) => EmergencyContact.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }

    return Patient(
      id: documentId,
      name: map['name'] ?? '',
      age: map['age'] ?? 0,
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      condition: map['condition'] ?? '',
      icd10Code: map['icd10Code'],
      saIdNumber: map['saIdNumber'] ?? '',
      status: map['status'] ?? 'Stable',
      notes: map['notes'] ?? '',
      assignedChwId: map['assignedChwId'] ?? '',
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      emergencyContacts: contacts,
    );
  }

  Patient copyWith({
    String? id,
    String? name,
    int? age,
    String? phone,
    String? address,
    String? condition,
    String? icd10Code,
    String? saIdNumber,
    String? status,
    String? notes,
    String? assignedChwId,
    DateTime? createdAt,
    List<EmergencyContact>? emergencyContacts,
  }) {
    return Patient(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      condition: condition ?? this.condition,
      icd10Code: icd10Code ?? this.icd10Code,
      saIdNumber: saIdNumber ?? this.saIdNumber,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      assignedChwId: assignedChwId ?? this.assignedChwId,
      createdAt: createdAt ?? this.createdAt,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}