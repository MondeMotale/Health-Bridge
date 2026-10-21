import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/referral.dart';
import 'patient_interaction_service.dart';

class ReferralService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PatientInteractionService _interactions = PatientInteractionService();

  // CREATE: Submit a new referral
  Future<void> submitReferral(Referral referral) async {
    try {
      await _interactions.createWithInteraction(
        document: _firestore.collection('referrals').doc(referral.id),
        data: referral.toMap(),
        patientId: referral.patientId,
        patientName: referral.patientName,
        chwId: referral.chwId,
        chwName: referral.chwName,
        type: 'referral',
        summary: 'Referral submitted to ${referral.department}',
        details: [
          'Condition: ${referral.condition}',
          'Urgency: ${referral.urgency}',
          'Location: ${referral.location}',
        ].join('\n'),
      );
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
    await _interactions.updateWithInteraction(
      document: _firestore.collection('referrals').doc(referralId),
      updates: {'status': newStatus},
      type: 'referral',
      summary: 'Referral status changed to $newStatus',
    );
  }
}