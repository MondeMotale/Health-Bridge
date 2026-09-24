import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/referral.dart';

class ReferralService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // CREATE: Submit a new referral
  Future<void> submitReferral(Referral referral) async {
    try {
      await _firestore.collection('referrals').doc(referral.id).set(referral.toMap());
    } catch (e) {
      throw Exception('Failed to submit referral: $e');
    }
  }

  // READ (ADMIN): Get all referrals in real-time
  Stream<List<Referral>> getReferrals() {
    return _firestore
        .collection('referrals')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Referral.fromMap(doc.data(), doc.id))
            .toList());
  }

  // UPDATE STATUS: Admin updates the status
  Future<void> updateStatus(String referralId, String newStatus) async {
    await _firestore.collection('referrals').doc(referralId).update({
      'status': newStatus,
    });
  }
}