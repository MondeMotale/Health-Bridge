import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chw_availability.dart';

class AvailabilityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch a CHW's availability. Returns defaults if none exist yet.
  Future<ChwAvailability> getAvailability(String chwId) async {
    try {
      final doc = await _firestore
          .collection('chw_availability')
          .doc(chwId)
          .get();

      if (doc.exists && doc.data() != null) {
        return ChwAvailability.fromMap(doc.data()!);
      }
      return ChwAvailability.defaults(chwId);
    } catch (e) {
      // On any error, fall back to defaults so the UI never breaks
      return ChwAvailability.defaults(chwId);
    }
  }

  /// Stream availability for realtime updates.
  Stream<ChwAvailability> streamAvailability(String chwId) {
    return _firestore
        .collection('chw_availability')
        .doc(chwId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return ChwAvailability.fromMap(doc.data()!);
      }
      return ChwAvailability.defaults(chwId);
    });
  }

  /// Save the availability to Firestore.
  Future<void> saveAvailability(ChwAvailability availability) async {
    await _firestore
        .collection('chw_availability')
        .doc(availability.chwId)
        .set(availability.toMap(), SetOptions(merge: true));
  }
}