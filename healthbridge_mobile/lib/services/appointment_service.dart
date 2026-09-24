import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment.dart';

class AppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // CREATE: Book a new appointment
  Future<void> bookAppointment(Appointment appointment) async {
    try {
      await _firestore.collection('appointments').doc(appointment.id).set(appointment.toMap());
    } catch (e) {
      throw Exception('Failed to book appointment: $e');
    }
  }

    // READ (CHW): Get appointments for a specific CHW (NO SORTING ON FIREBASE)
  Stream<List<Appointment>> getAppointmentsForChw(String chwId) {
    return _firestore
        .collection('appointments')
        .where('chwId', isEqualTo: chwId)
        // REMOVED THE .orderBy LINE COMPLETELY
        .snapshots()
        .map((snapshot) {
          // Fetch the list
          List<Appointment> appointments = snapshot.docs
              .map((doc) => Appointment.fromMap(doc.data(), doc.id))
              .toList();
          
          // SORT THE LIST INSIDE THE APP (No index required!)
          appointments.sort((a, b) => b.dateTime.compareTo(a.dateTime));
          
          return appointments;
        });
  }

    // READ (PATIENT): Get appointments for a specific patient
  Stream<List<Appointment>> getAppointmentsForPatient(String patientId) {
    return _firestore
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snapshot) {
          List<Appointment> appointments = snapshot.docs
              .map((doc) => Appointment.fromMap(doc.data(), doc.id))
              .toList();
          
          appointments.sort((a, b) => b.dateTime.compareTo(a.dateTime));
          
          return appointments;
        });
  }

  // UPDATE STATUS: Mark as Completed or Cancelled
  Future<void> updateStatus(String appointmentId, String newStatus) async {
    await _firestore.collection('appointments').doc(appointmentId).update({
      'status': newStatus,
    });
  }
}
