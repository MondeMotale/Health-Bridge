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

  // ============================================================
  // SERIALIZATION
  // ============================================================
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
      name: _parseString(map['name']),
      age: _parseInt(map['age']),
      phone: _parseString(map['phone']),
      address: _parseString(map['address']),
      condition: _parseString(map['condition']),
      icd10Code: map['icd10Code'] as String?,
      saIdNumber: _parseString(map['saIdNumber']),
      status: _parseString(map['status'], fallback: 'Stable'),
      notes: _parseString(map['notes']),
      assignedChwId: _parseString(map['assignedChwId']),
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
    );
  }

  // ============================================================
  // COPY WITH (useful for edits / optimistic updates)
  // ============================================================
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
    );
  }

  // ============================================================
  // EQUALITY (needed for Set, Map keys, List.contains, etc.)
  // ============================================================
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Patient &&
        other.id == id &&
        other.name == name &&
        other.age == age &&
        other.phone == phone &&
        other.address == address &&
        other.condition == condition &&
        other.icd10Code == icd10Code &&
        other.saIdNumber == saIdNumber &&
        other.status == status &&
        other.notes == notes &&
        other.assignedChwId == assignedChwId &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        age,
        phone,
        address,
        condition,
        icd10Code,
        saIdNumber,
        status,
        notes,
        assignedChwId,
        createdAt,
      );

  @override
  String toString() =>
      'Patient(id: $id, name: $name, status: $status, age: $age)';

  // ============================================================
  // TYPE-TOLERANT PARSING HELPERS
  // Every Firestore field could arrive in more than one shape.
  // These normalize them so `fromMap` never throws.
  // ============================================================

  /// Accepts String, num, or null. Returns '' for null/missing.
  static String _parseString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    if (value is String) return value;
    return value.toString();
  }

  /// Accepts int, double, numeric String, or null.
  /// Returns 0 for null/missing/non-numeric.
  static int _parseInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  /// Accepts Timestamp, DateTime, ISO8601 String, or null.
  /// Returns null for anything unparseable.
  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}