import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/patient.dart';
import '../models/appointment.dart'; // <--- ADDED THIS IMPORT

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. CREATE: Add a new patient to the database
  Future<void> addPatient(Patient patient) async {
    try {
      await _firestore.collection('patients').doc(patient.id).set(patient.toMap());
    } catch (e) {
      throw Exception('Failed to add patient: $e');
    }
  }

  // 2. READ: Get all patients for a specific CHW (REAL-TIME STREAM)
  Stream<List<Patient>> getPatientsForChw(String chwId) {
    return _firestore
        .collection('patients')
        .where('assignedChwId', isEqualTo: chwId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Patient.fromMap(doc.data(), doc.id)).toList();
        });
  }

  // 3. READ: Get dashboard stats (Total, Critical, Pending, Done) for a CHW
  Future<Map<String, int>> getDashboardStats(String chwId) async {
    try {
      final allQuery = await _firestore
          .collection('patients')
          .where('assignedChwId', isEqualTo: chwId)
          .get();
      
      final criticalQuery = await _firestore
          .collection('patients')
          .where('assignedChwId', isEqualTo: chwId)
          .where('status', isEqualTo: 'Critical')
          .get();

      final followUpQuery = await _firestore
          .collection('patients')
          .where('assignedChwId', isEqualTo: chwId)
          .where('status', isEqualTo: 'Needs Follow-up')
          .get();

      final doneQuery = await _firestore
          .collection('patients')
          .where('assignedChwId', isEqualTo: chwId)
          .where('status', isEqualTo: 'Stable')
          .get();

      return {
        'total': allQuery.docs.length,
        'critical': criticalQuery.docs.length,
        'followUp': followUpQuery.docs.length,
        'done': doneQuery.docs.length, // <--- Added this
      };
    } catch (e) {
      return {'total': 0, 'critical': 0, 'followUp': 0, 'done': 0};
    }
  }

  // --- NEW: 4. DELETE: Remove a patient from the database ---
  Future<void> deletePatient(String patientId) async {
    try {
      await _firestore.collection('patients').doc(patientId).delete();
    } catch (e) {
      throw Exception('Failed to delete patient: $e');
    }
  }

     // 5. READ: Get patients for the Messages page (Only those assigned to this CHW)
  Stream<List<Patient>> getPatientsForMessages(String chwId) {
    return _firestore
        .collection('patients')
        .where('assignedChwId', isEqualTo: chwId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Patient.fromMap(doc.data(), doc.id))
            .toList());
  }

    // 6. READ: Count appointments for a CHW (Dashboard)
  Future<int> getAppointmentsCount(String chwId) async {
    try {
      final querySnapshot = await _firestore
          .collection('appointments')
          .where('chwId', isEqualTo: chwId)
          .get();
      return querySnapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }


    // 7. READ: Get the CHW assigned to a patient
  Stream<List<Map<String, dynamic>>> getAssignedChw(String patientUid) async* {
    final patientQuery = await _firestore
        .collection('patients')
        .where('id', isEqualTo: patientUid)
        .get();
        
    if (patientQuery.docs.isEmpty) {
      yield [];
      return;
    }
    
    final patientData = patientQuery.docs.first.data();
    final assignedChwId = patientData['assignedChwId'] ?? '';
    
    if (assignedChwId.isEmpty) {
      yield [];
      return;
    }
    
    final chwQuery = await _firestore
        .collection('users')
        .where('uid', isEqualTo: assignedChwId)
        .get();
        
    yield chwQuery.docs.map((doc) => doc.data()).toList();
  }


    // 8. READ: Get the patient's own profile
  Future<Patient?> getPatientProfile(String patientUid) async {
    try {
      final doc = await _firestore.collection('patients').doc(patientUid).get();
      if (doc.exists) {
        return Patient.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // 9. READ: Get upcoming appointments for the patient
  Stream<List<Appointment>> getAppointmentsForPatient(String patientId) {
    return _firestore
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Appointment.fromMap(doc.data(), doc.id))
            .toList());
  }
} 