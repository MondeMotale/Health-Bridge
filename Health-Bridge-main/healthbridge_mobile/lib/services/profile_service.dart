import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get the CHW profile from the 'users' collection
  Future<ChwProfile?> getProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return ChwProfile.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Save or Update the CHW profile into the 'users' collection
  Future<void> saveProfile(ChwProfile profile) async {
    await _firestore.collection('users').doc(profile.uid).set(profile.toMap(), SetOptions(merge: true));
  }
}