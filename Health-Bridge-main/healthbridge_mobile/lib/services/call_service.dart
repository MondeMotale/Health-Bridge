import 'package:cloud_firestore/cloud_firestore.dart';
import 'patient_interaction_service.dart';

class CallService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PatientInteractionService _interactions = PatientInteractionService();

  Future<void> _recordCallAction(
    String callId, {
    required Map<String, dynamic> updates,
    required String summary,
    String? details,
  }) async {
    final callRef = _firestore.collection('calls').doc(callId);
    final snapshot = await callRef.get();
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Call $callId was not found.');
    }
    final patientId = data['patientId'] as String? ?? '';
    final chwId = data['chwId'] as String? ?? '';
    if (patientId.isEmpty || chwId.isEmpty) {
      await callRef.update(updates);
    } else {
      await _interactions.updateWithInteraction(
        document: callRef,
        updates: updates,
        type: 'call',
        summary: summary,
        details: details,
      );
    }
  }

  // Create a new call doc. Returns the callId.
  Future<String> startCall({
    required String callerId,
    required String receiverId,
    required String channelName,
    required String callType,
    String? patientId,
    String? patientName,
    String? chwId,
    String? chwName,
  }) async {
    final docRef = _firestore.collection('calls').doc();
    final data = <String, dynamic>{
      'callerId': callerId,
      'receiverId': receiverId,
      'channelName': channelName,
      'callType': callType,
      'patientId': patientId,
      'patientName': patientName,
      'chwId': chwId,
      'chwName': chwName,
      'status': 'ringing',
      'endReason': null,
      'createdAt': FieldValue.serverTimestamp(),
    };
    final batch = _firestore.batch();
    batch.set(docRef, data);
    if (patientId != null &&
        patientId.isNotEmpty &&
        chwId != null &&
        chwId.isNotEmpty) {
      final callerIsPatient = callerId == patientId;
      final interactionRef =
          _firestore.collection('patientInteractions').doc();
      batch.set(interactionRef, {
        'patientId': patientId,
        'patientName': patientName ?? 'Unknown patient',
        'chwId': chwId,
        'chwIds': [chwId],
        'chwName': chwName ?? 'CHW',
        'actorId': callerId,
        'actorName': callerIsPatient
            ? patientName ?? 'Patient'
            : chwName ?? 'CHW',
        'actorRole': callerIsPatient ? 'patient' : 'chw',
        'type': 'call',
        'summary': callerIsPatient
            ? 'Incoming $callType call started'
            : 'Outgoing $callType call started',
        'relatedRecordId': docRef.id,
        'source': 'mobile',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    return docRef.id;
  }

  // Stream incoming ringing calls for a user.
  Stream<Map<String, dynamic>?> listenForIncomingCalls(String userId) {
    return _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.last;
      final data = doc.data();
      data['callId'] = doc.id;
      return data;
    });
  }

  // Watch a specific call's data (status, endReason, etc.).
  Stream<Map<String, dynamic>?> watchCall(String callId) {
    return _firestore
        .collection('calls')
        .doc(callId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      final data = doc.data()!;
      data['callId'] = doc.id;
      return data;
    });
  }

  Future<String> getCallerName(String callerId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(callerId).get();
      if (userDoc.exists && userDoc.data() != null) {
        final name = userDoc.data()!['displayName'];
        if (name != null && name.toString().isNotEmpty) return name.toString();
      }
      final patientDoc =
          await _firestore.collection('patients').doc(callerId).get();
      if (patientDoc.exists && patientDoc.data() != null) {
        final name = patientDoc.data()!['name'];
        if (name != null && name.toString().isNotEmpty) return name.toString();
      }
      return 'Unknown Caller';
    } catch (_) {
      return 'Unknown Caller';
    }
  }

  // Receiver accepts.
  Future<void> answerCall(String callId) async {
    await _recordCallAction(
      callId,
      updates: {
        'status': 'active',
        'answeredAt': FieldValue.serverTimestamp(),
      },
      summary: 'Call answered',
    );
  }

  // Receiver declines.
  Future<void> declineCall(String callId) async {
    await _recordCallAction(
      callId,
      updates: {
        'status': 'ended',
        'endReason': 'declined',
        'endedAt': FieldValue.serverTimestamp(),
      },
      summary: 'Call declined',
      details: 'declined',
    );
  }

  // Caller hangs up before answer, or either side ends after connect.
  Future<void> endCall(String callId, {String? reason}) async {
    await _recordCallAction(
      callId,
      updates: {
        'status': 'ended',
        'endReason': reason,
        'endedAt': FieldValue.serverTimestamp(),
      },
      summary: 'Call ended',
      details: reason,
    );
  }
}