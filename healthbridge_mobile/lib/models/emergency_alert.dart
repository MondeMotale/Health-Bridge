import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyAlert {
  final String id;
  final String patientId;
  final String patientName;
  final String? chwId;
  final String? chwName;
  final double latitude;
  final double longitude;
  final String? address;
  final String status;
  // 'active' | 'responding' | 'resolved' | 'false_alarm' | 'cancelled'
  final String? responseType;
  // 'coming' | 'help_sent' | null
  final DateTime createdAt;
  final DateTime? respondedAt;
  final DateTime? resolvedAt;
  final String? resolutionNotes;

  EmergencyAlert({
    required this.id,
    required this.patientId,
    required this.patientName,
    this.chwId,
    this.chwName,
    required this.latitude,
    required this.longitude,
    this.address,
    this.status = 'active',
    this.responseType,
    required this.createdAt,
    this.respondedAt,
    this.resolvedAt,
    this.resolutionNotes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'patientId': patientId,
        'patientName': patientName,
        'chwId': chwId,
        'chwName': chwName,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'status': status,
        'responseType': responseType,
        'createdAt': createdAt.toIso8601String(),
        'respondedAt': respondedAt?.toIso8601String(),
        'resolvedAt': resolvedAt?.toIso8601String(),
        'resolutionNotes': resolutionNotes,
      };

  factory EmergencyAlert.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return EmergencyAlert(
      id: documentId,
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'] ?? 'Unknown',
      chwId: map['chwId'],
      chwName: map['chwName'],
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      address: map['address'],
      status: map['status'] ?? 'active',
      responseType: map['responseType'],
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      respondedAt: _parseDate(map['respondedAt']),
      resolvedAt: _parseDate(map['resolvedAt']),
      resolutionNotes: map['resolutionNotes'],
    );
  }

  EmergencyAlert copyWith({
    String? id,
    String? patientId,
    String? patientName,
    String? chwId,
    String? chwName,
    double? latitude,
    double? longitude,
    String? address,
    String? status,
    String? responseType,
    DateTime? createdAt,
    DateTime? respondedAt,
    DateTime? resolvedAt,
    String? resolutionNotes,
  }) {
    return EmergencyAlert(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      chwId: chwId ?? this.chwId,
      chwName: chwName ?? this.chwName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      status: status ?? this.status,
      responseType: responseType ?? this.responseType,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
    );
  }

  bool get isActive => status == 'active' || status == 'responding';
  bool get isResolved =>
      status == 'resolved' || status == 'cancelled' || status == 'false_alarm';

  String get timeSinceCreated {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes == 1) return '1 min ago';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inHours == 1) return '1 hour ago';
    return '${diff.inHours} hours ago';
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}