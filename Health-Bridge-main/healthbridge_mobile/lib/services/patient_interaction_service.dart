import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PatientInteractionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> record({
    required String patientId,
    required String patientName,
    required String chwId,
    required String chwName,
    required String type,
    required String summary,
    String? details,
    String? relatedRecordId,
    String? actorId,
    String? actorName,
    String? actorRole,
    List<String> additionalChwIds = const [],
  }) async {
    if (patientId.isEmpty || chwId.isEmpty) {
      throw ArgumentError('Patient and CHW IDs are required for interaction records.');
    }

    await _firestore.collection('patientInteractions').add({
      ..._recordData(
        patientId: patientId,
        patientName: patientName,
        chwId: chwId,
        chwName: chwName,
        type: type,
        summary: summary,
        details: details,
        relatedRecordId: relatedRecordId,
        actorId: actorId,
        actorName: actorName,
        actorRole: actorRole,
        additionalChwIds: additionalChwIds,
      ),
    });
  }

  Future<void> createWithInteraction({
    required DocumentReference<Map<String, dynamic>> document,
    required Map<String, dynamic> data,
    required String patientId,
    required String patientName,
    required String chwId,
    required String chwName,
    required String type,
    required String summary,
    String? details,
  }) async {
    _validateIds(patientId, chwId);
    final batch = _firestore.batch();
    batch.set(document, data);
    batch.set(_firestore.collection('patientInteractions').doc(), _recordData(
      patientId: patientId,
      patientName: patientName,
      chwId: chwId,
      chwName: chwName,
      type: type,
      summary: summary,
      details: details,
      relatedRecordId: document.id,
    ));
    await batch.commit();
  }

  Future<void> updateWithInteraction({
    required DocumentReference<Map<String, dynamic>> document,
    required Map<String, dynamic> updates,
    required String type,
    required String summary,
    String? details,
  }) async {
    final snapshot = await document.get();
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Cannot record an interaction for a missing record.');
    }
    final patientId = data['patientId'] as String? ?? '';
    final patientName = data['patientName'] as String? ?? 'Unknown patient';
    final chwId = data['chwId'] as String? ?? '';
    final chwName = data['chwName'] as String? ?? 'CHW';
    _validateIds(patientId, chwId);

    final batch = _firestore.batch();
    batch.update(document, updates);
    batch.set(
      _firestore.collection('patientInteractions').doc(),
      _recordData(
        patientId: patientId,
        patientName: patientName,
        chwId: chwId,
        chwName: chwName,
        type: type,
        summary: summary,
        details: details,
        relatedRecordId: document.id,
        additionalChwIds: [
          data['secondaryChwId'] as String? ?? '',
          updates['secondaryChwId'] as String? ?? '',
        ],
      ),
    );
    await batch.commit();
  }

  Future<void> updatePatientWithInteraction({
    required DocumentReference<Map<String, dynamic>> document,
    required Map<String, dynamic> updates,
    required String patientId,
    required String patientName,
    String? chwId,
    String? chwName,
    required String summary,
    String? details,
  }) async {
    if (patientId.isEmpty) {
      throw ArgumentError('A patient ID is required for interaction records.');
    }
    if (chwId != null && chwId.isNotEmpty) {
      await updateRelatedRecordWithInteraction(
        document: document,
        updates: updates,
        patientId: patientId,
        patientName: patientName,
        chwId: chwId,
        chwName: chwName ?? 'CHW',
        type: 'patient_record',
        summary: summary,
        details: details,
      );
      return;
    }
    final batch = _firestore.batch();
    batch.update(document, updates);
    await batch.commit();
  }

  Future<void> updateRelatedRecordWithInteraction({
    required DocumentReference<Map<String, dynamic>> document,
    required Map<String, dynamic> updates,
    required String patientId,
    required String patientName,
    required String chwId,
    required String chwName,
    required String type,
    required String summary,
    String? details,
  }) async {
    _validateIds(patientId, chwId);
    final batch = _firestore.batch();
    batch.update(document, updates);
    batch.set(
      _firestore.collection('patientInteractions').doc(),
      _recordData(
        patientId: patientId,
        patientName: patientName,
        chwId: chwId,
        chwName: chwName,
        type: type,
        summary: summary,
        details: details,
        relatedRecordId: document.id,
      ),
    );
    await batch.commit();
  }

  void _validateIds(String patientId, String chwId) {
    if (patientId.isEmpty || chwId.isEmpty) {
      throw ArgumentError(
        'Patient and CHW IDs are required for interaction records.',
      );
    }
  }

  Map<String, dynamic> _recordData({
    required String patientId,
    required String patientName,
    required String chwId,
    required String chwName,
    required String type,
    required String summary,
    String? details,
    String? relatedRecordId,
    String? actorId,
    String? actorName,
    String? actorRole,
    List<String> additionalChwIds = const [],
  }) {
    _validateIds(patientId, chwId);
    final actor = _auth.currentUser;
    final effectiveActorId = actorId ?? actor?.uid ?? chwId;
    return {
      'patientId': patientId,
      'patientName': patientName,
      'chwId': chwId,
      'chwIds': {chwId, ...additionalChwIds.where((id) => id.isNotEmpty)}.toList(),
      'chwName': chwName,
      'actorId': effectiveActorId,
      'actorName': actorName ?? actor?.displayName ?? chwName,
      'actorRole': actorRole ??
          (effectiveActorId == patientId ? 'patient' : 'chw'),
      'type': type,
      'summary': summary,
      'details': details,
      'relatedRecordId': relatedRecordId,
      'source': 'mobile',
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Stream<List<Map<String, dynamic>>> watchForChw(String chwId) {
    return _firestore
        .collection('patientInteractions')
        .where('chwIds', arrayContains: chwId)
        .snapshots()
        .map((snapshot) {
      final records = snapshot.docs.map((doc) {
        return <String, dynamic>{...doc.data(), 'id': doc.id};
      }).toList();
      records.sort((a, b) {
        final aDate = _dateOf(a['createdAt']);
        final bDate = _dateOf(b['createdAt']);
        return bDate.compareTo(aDate);
      });
      return records;
    });
  }

  Future<List<Map<String, dynamic>>> getForChw(String chwId) async {
    final snapshot = await _firestore
        .collection('patientInteractions')
        .where('chwIds', arrayContains: chwId)
        .get();
    final records = snapshot.docs.map((doc) {
      return <String, dynamic>{...doc.data(), 'id': doc.id};
    }).toList();
    records.sort((a, b) {
      final aDate = _dateOf(a['createdAt']);
      final bDate = _dateOf(b['createdAt']);
      return bDate.compareTo(aDate);
    });
    return records;
  }

  DateTime _dateOf(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime(1970);
    return DateTime(1970);
  }
}
