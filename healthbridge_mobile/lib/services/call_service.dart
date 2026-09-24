import 'package:cloud_firestore/cloud_firestore.dart';

class CallService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Save the call info so the other user knows to join.
  // RETURNS the auto-generated callId.
  Future<String> startCall({
    required String callerId,
    required String receiverId,
    required String channelName,
    required String callType, // 'video' or 'voice'
  }) async {
    final docRef = await _firestore.collection('calls').add({
      'callerId': callerId,
      'receiverId': receiverId,
      'channelName': channelName,
      'callType': callType,
      'status': 'ringing',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // Listen for incoming calls for a specific user.
  // Emits a map that INCLUDES 'callId'.
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
          data['callId'] = doc.id; // <--- inject callId
          return data;
        });
  }

  // Look up the caller's display name for the incoming call UI.
  Future<String> getCallerName(String callerId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(callerId).get();
      if (userDoc.exists && userDoc.data() != null) {
        final name = userDoc.data()!['displayName'];
        if (name != null && name.toString().isNotEmpty) return name.toString();
      }
      final patientDoc = await _firestore.collection('patients').doc(callerId).get();
      if (patientDoc.exists && patientDoc.data() != null) {
        final name = patientDoc.data()!['name'];
        if (name != null && name.toString().isNotEmpty) return name.toString();
      }
      return 'Unknown Caller';
    } catch (_) {
      return 'Unknown Caller';
    }
  }

  // Update the call status when the receiver joins
  Future<void> answerCall(String callId) async {
    await _firestore.collection('calls').doc(callId).update({
      'status': 'active',
      'answeredAt': FieldValue.serverTimestamp(),
    });
  }

  // End the call (update status)
  Future<void> endCall(String callId) async {
    await _firestore.collection('calls').doc(callId).update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
    });
  }
}