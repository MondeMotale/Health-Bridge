import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment.dart';
import 'patient_interaction_service.dart';

class AppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PatientInteractionService _interactions = PatientInteractionService();

  Future<void> _updateAppointmentAction(
    String appointmentId, {
    required Map<String, dynamic> updates,
    required String summary,
    String? details,
  }) async {
    await _interactions.updateWithInteraction(
      document: _firestore.collection('appointments').doc(appointmentId),
      updates: updates,
      type: 'appointment',
      summary: summary,
      details: details,
    );
  }

  // CREATE: Book a new appointment
  Future<void> bookAppointment(Appointment appointment) async {
    try {
      await _interactions.createWithInteraction(
        document:
            _firestore.collection('appointments').doc(appointment.id),
        data: appointment.toMap(),
        patientId: appointment.patientId,
        patientName: appointment.patientName,
        chwId: appointment.chwId,
        chwName: appointment.chwName,
        type: 'appointment',
        summary: 'Appointment scheduled',
        details: appointment.notes.isEmpty ? null : appointment.notes,
      );
    } catch (e) {
      throw Exception('Failed to book appointment: $e');
    }
  }

  // READ (CHW): Get appointments for a specific CHW
  Stream<List<Appointment>> getAppointmentsForChw(String chwId) {
    return _firestore
        .collection('appointments')
        .where('chwId', isEqualTo: chwId)
        .snapshots()
        .map((snapshot) {
          List<Appointment> appointments = snapshot.docs
              .map((doc) => Appointment.fromMap(doc.data(), doc.id))
              .toList();

          // Sort by date — upcoming first, then recent history
          appointments.sort((a, b) => b.dateTime.compareTo(a.dateTime));
          return appointments;
        });
  }

  // READ (CHW): Get today's appointments only
  Stream<List<Appointment>> getTodaysAppointmentsForChw(String chwId) {
    return getAppointmentsForChw(chwId).map((appointments) {
      return appointments.where((a) => a.isToday).toList();
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

  // ============================================================
  // LIFECYCLE — status transitions
  // ============================================================

  /// CHW starts the trip → status becomes 'EnRoute'
  Future<void> markEnRoute(String appointmentId) async {
    await _updateAppointmentAction(
      appointmentId,
      updates: {
        'status': 'EnRoute',
        'enRouteAt': DateTime.now().toIso8601String(),
      },
      summary: 'CHW en route',
    );
  }

  /// CHW has arrived → status becomes 'InProgress'
  Future<void> markArrived(String appointmentId) async {
    await _updateAppointmentAction(
      appointmentId,
      updates: {
        'status': 'InProgress',
        'startedAt': DateTime.now().toIso8601String(),
      },
      summary: 'Patient visit started',
    );
  }

  /// CHW completes the visit → status becomes 'Completed'
  /// Saves CHW notes, calculates duration, locks notes.
  /// Optionally sets up follow-up.
  Future<void> markCompleted({
    required String appointmentId,
    required String chwNotes,
    required DateTime startedAt,
    String? followUpRequired,
    DateTime? nextFollowUpDate,
  }) async {
    final now = DateTime.now();
    final duration = now.difference(startedAt).inMinutes;

    await _updateAppointmentAction(
      appointmentId,
      updates: {
        'status': 'Completed',
        'chwNotes': chwNotes,
        'completedAt': now.toIso8601String(),
        'visitDurationMinutes': duration,
        'followUpRequired': followUpRequired,
        'nextFollowUpDate': nextFollowUpDate?.toIso8601String(),
        'notesLockedAt': now.toIso8601String(),
      },
      summary: 'Patient visit completed',
      details: [
        if (chwNotes.trim().isNotEmpty) 'Care notes: ${chwNotes.trim()}',
        if (followUpRequired != null && followUpRequired.isNotEmpty)
          'Follow-up: $followUpRequired',
        if (nextFollowUpDate != null)
          'Next follow-up: ${nextFollowUpDate.toIso8601String()}',
      ].join('\n'),
    );
  }

  /// CHW marks the patient as missed (not home, didn't show)
  Future<void> markMissed({
    required String appointmentId,
    required String reason,
  }) async {
    await _updateAppointmentAction(
      appointmentId,
      updates: {
        'status': 'Missed',
        'missedReason': reason,
        'completedAt': DateTime.now().toIso8601String(),
      },
      summary: 'Visit marked missed',
      details: reason,
    );
  }

  /// Cancel the appointment (either party)
  Future<void> cancelAppointment({
    required String appointmentId,
    required String reason,
  }) async {
    await _updateAppointmentAction(
      appointmentId,
      updates: {
        'status': 'Cancelled',
        'cancellationReason': reason,
      },
      summary: 'Appointment cancelled',
      details: reason,
    );
  }

  // ============================================================
  // LEGACY — kept for backward compatibility
  // ============================================================

  /// Simple status update — used if a screen just needs to change status
  Future<void> updateStatus(String appointmentId, String newStatus) async {
    await _updateAppointmentAction(
      appointmentId,
      updates: {'status': newStatus},
      summary: 'Appointment status changed to $newStatus',
    );
  }
}