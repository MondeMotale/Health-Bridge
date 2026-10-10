import 'package:cloud_firestore/cloud_firestore.dart';

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
    };
  }

  factory Patient.fromMap(Map<String, dynamic> map, String documentId) {
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
      createdAt: _parseDate(map['createdAt']),
    );
  }

  /// Handles all the ways `createdAt` can arrive from Firestore:
  /// - Timestamp (from FieldValue.serverTimestamp or DateTime.now())
  /// - ISO8601 String
  /// - null / missing
  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}