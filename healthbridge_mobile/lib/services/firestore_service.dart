import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/patient.dart';
import '../models/appointment.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // 1. CREATE: Add a new patient to the database
  // ============================================================
  Future<void> addPatient(Patient patient) async {
    try {
      await _firestore
          .collection('patients')
          .doc(patient.id)
          .set(patient.toMap());
    } catch (e) {
      throw Exception('Failed to add patient: $e');
    }
  }

  // ============================================================
  // 2. READ: Get all patients for a specific CHW (REAL-TIME STREAM)
  // ============================================================
  Stream<List<Patient>> getPatientsForChw(String chwId) {
    return _firestore
        .collection('patients')
        .where('assignedChwId', isEqualTo: chwId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Patient.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // ============================================================
  // 3. READ: Get dashboard stats for a CHW
  //
  // Returns:
  //   - total      = active patients assigned to this CHW
  //   - critical   = patients with status 'Critical'
  //   - followUp   = appointments in the next 7 days (not yet done)
  //   - done       = completed + missed appointments (all time)
  // ============================================================
  Future<Map<String, int>> getDashboardStats(String chwId) async {
    try {
      // ---- Patients (for total + critical counts) ----
      final allQuery = await _firestore
          .collection('patients')
          .where('assignedChwId', isEqualTo: chwId)
          .get();

      final criticalQuery = await _firestore
          .collection('patients')
          .where('assignedChwId', isEqualTo: chwId)
          .where('status', isEqualTo: 'Critical')
          .get();

      // ---- Appointments (for pending + done counts) ----
      final appointmentsQuery = await _firestore
          .collection('appointments')
          .where('chwId', isEqualTo: chwId)
          .get();

      final now = DateTime.now();
      final weekFromNow = now.add(const Duration(days: 7));

      int pendingCount = 0;
      int doneCount = 0;

      for (final doc in appointmentsQuery.docs) {
        final data = doc.data();
        final status = (data['status'] as String?) ?? '';
        final dateTimeRaw = data['dateTime'] as String?;
        if (dateTimeRaw == null) continue;

        final dt = DateTime.tryParse(dateTimeRaw);
        if (dt == null) continue;

        // ---- Pending Visits: appointments in the next 7 days, not yet finished ----
        final isUpcoming = dt.isAfter(now.subtract(const Duration(hours: 1))) &&
            dt.isBefore(weekFromNow);
        final isNotFinished = status != 'Completed' &&
            status != 'Missed' &&
            status != 'Cancelled';

        if (isUpcoming && isNotFinished) {
          pendingCount++;
        }

        // ---- Done Visits: completed or missed (all time) ----
        if (status == 'Completed' || status == 'Missed') {
          doneCount++;
        }
      }

      return {
        'total': allQuery.docs.length,
        'critical': criticalQuery.docs.length,
        'followUp': pendingCount,
        'done': doneCount,
      };
    } catch (e) {
      return {'total': 0, 'critical': 0, 'followUp': 0, 'done': 0};
    }
  }

  // ============================================================
  // 4. DELETE: Remove a patient from the database
  // ============================================================
  Future<void> deletePatient(String patientId) async {
    try {
      await _firestore.collection('patients').doc(patientId).delete();
    } catch (e) {
      throw Exception('Failed to delete patient: $e');
    }
  }

  // ============================================================
  // 5. READ: Get patients for the Messages page
  // ============================================================
  Stream<List<Patient>> getPatientsForMessages(String chwId) {
    return _firestore
        .collection('patients')
        .where('assignedChwId', isEqualTo: chwId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Patient.fromMap(doc.data(), doc.id))
            .toList());
  }

  // ============================================================
  // 6. READ: Count TODAY's appointments for a CHW (Dashboard "Scheduled" card)
  //
  // Counts only appointments scheduled for today that are NOT yet
  // completed, missed, or cancelled.
  // ============================================================
  Future<int> getAppointmentsCount(String chwId) async {
    try {
      final querySnapshot = await _firestore
          .collection('appointments')
          .where('chwId', isEqualTo: chwId)
          .get();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      int todayCount = 0;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final status = (data['status'] as String?) ?? '';
        final dateTimeRaw = data['dateTime'] as String?;
        if (dateTimeRaw == null) continue;

        final dt = DateTime.tryParse(dateTimeRaw);
        if (dt == null) continue;

        final d = DateTime(dt.year, dt.month, dt.day);
        final isToday =
            d.isAtSameMomentAs(today) ||
                (d.isAfter(today) && d.isBefore(tomorrow));

        final isNotFinished = status != 'Completed' &&
            status != 'Missed' &&
            status != 'Cancelled';

        if (isToday && isNotFinished) {
          todayCount++;
        }
      }

      return todayCount;
    } catch (e) {
      return 0;
    }
  }

  // ============================================================
  // 7. READ: Get the CHW assigned to a patient
  // ============================================================
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

  // ============================================================
  // 8. READ: Get the patient's own profile
  // ============================================================
  Future<Patient?> getPatientProfile(String patientUid) async {
    try {
      final doc = await _firestore
          .collection('patients')
          .doc(patientUid)
          .get();
      if (doc.exists) {
        return Patient.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // 9. READ: Get upcoming appointments for the patient
  // ============================================================
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