import 'package:cloud_firestore/cloud_firestore.dart';

class CallService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new call doc. Returns the callId.
  Future<String> startCall({
    required String callerId,
    required String receiverId,
    required String channelName,
    required String callType,
  }) async {
    final docRef = await _firestore.collection('calls').add({
      'callerId': callerId,
      'receiverId': receiverId,
      'channelName': channelName,
      'callType': callType,
      'status': 'ringing',
      'endReason': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
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
    await _firestore.collection('calls').doc(callId).update({
      'status': 'active',
      'answeredAt': FieldValue.serverTimestamp(),
    });
  }

  // Receiver declines.
  Future<void> declineCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': 'ended',
        'endReason': 'declined',
        'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // Caller hangs up before answer, or either side ends after connect.
  Future<void> endCall(String callId, {String? reason}) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': 'ended',
        'endReason': reason,
        'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}