import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/emergency_contact.dart';
import '../models/emergency_alert.dart';
import 'patient_interaction_service.dart';

class EmergencyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PatientInteractionService _interactions = PatientInteractionService();

  Future<void> _recordAlertAction(
    String alertId, {
    required Map<String, dynamic> updates,
    required String summary,
    String? details,
  }) async {
    final alertRef = _firestore.collection('emergencyAlerts').doc(alertId);
    final snapshot = await alertRef.get();
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Emergency alert $alertId was not found for logging.');
    }
    final patientId = data['patientId'] as String? ?? '';
    final chwId = data['chwId'] as String? ?? '';
    if (patientId.isEmpty || chwId.isEmpty) {
      await alertRef.update(updates);
      return;
    }
    await _interactions.updateWithInteraction(
      document: alertRef,
      updates: updates,
      type: 'emergency',
      summary: summary,
      details: details,
    );
  }

  // ============================================================
  // EMERGENCY CONTACTS (Phase 1 — unchanged)
  // ============================================================
  Future<List<EmergencyContact>> getContacts(String patientId) async {
    final doc = await _firestore.collection('patients').doc(patientId).get();
    if (!doc.exists) return [];
    final raw = doc.data()?['emergencyContacts'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => EmergencyContact.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Stream<List<EmergencyContact>> watchContacts(String patientId) {
    return _firestore
        .collection('patients')
        .doc(patientId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return <EmergencyContact>[];
      final raw = doc.data()?['emergencyContacts'];
      if (raw is! List) return <EmergencyContact>[];
      return raw
          .whereType<Map>()
          .map((e) => EmergencyContact.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    });
  }

  Future<void> saveContacts(
    String patientId,
    List<EmergencyContact> contacts,
  ) async {
    final normalised = _enforceSinglePrimary(contacts);
    final patientRef = _firestore.collection('patients').doc(patientId);
    final patientSnapshot = await patientRef.get();
    final patientData = patientSnapshot.data();
    if (patientData == null) {
      throw StateError('Patient $patientId was not found.');
    }
    await _interactions.updatePatientWithInteraction(
      document: patientRef,
      updates: {
        'emergencyContacts': normalised.map((c) => c.toMap()).toList(),
      },
      patientId: patientId,
      patientName: patientData['name'] as String? ?? 'Unknown patient',
      chwId: patientData['assignedChwId'] as String?,
      chwName: patientData['assignedChwName'] as String? ?? 'CHW',
      summary: 'Emergency contacts updated',
      details: 'Number of contacts: ${normalised.length}',
    );
  }

  Future<void> addContact(String patientId, EmergencyContact contact) async {
    final current = await getContacts(patientId);
    final toAdd = current.isEmpty ? contact.copyWith(isPrimary: true) : contact;
    final updated = toAdd.isPrimary
        ? current.map((c) => c.copyWith(isPrimary: false)).toList()
        : current;
    updated.add(toAdd);
    await saveContacts(patientId, updated);
  }

  Future<void> updateContact(String patientId, EmergencyContact contact) async {
    final current = await getContacts(patientId);
    final updated = current.map((c) {
      if (c.id == contact.id) return contact;
      if (contact.isPrimary) return c.copyWith(isPrimary: false);
      return c;
    }).toList();
    await saveContacts(patientId, updated);
  }

  Future<void> deleteContact(String patientId, String contactId) async {
    final current = await getContacts(patientId);
    final updated = current.where((c) => c.id != contactId).toList();
    if (updated.isNotEmpty && !updated.any((c) => c.isPrimary)) {
      updated[0] = updated[0].copyWith(isPrimary: true);
    }
    await saveContacts(patientId, updated);
  }

  Future<void> setPrimaryContact(String patientId, String contactId) async {
    final current = await getContacts(patientId);
    final updated =
        current.map((c) => c.copyWith(isPrimary: c.id == contactId)).toList();
    await saveContacts(patientId, updated);
  }

  List<EmergencyContact> _enforceSinglePrimary(
      List<EmergencyContact> contacts) {
    if (contacts.isEmpty) return contacts;
    final primaryIndex = contacts.indexWhere((c) => c.isPrimary);
    if (primaryIndex == -1) {
      return [
        contacts[0].copyWith(isPrimary: true),
        ...contacts.skip(1).map((c) => c.copyWith(isPrimary: false)),
      ];
    }
    return [
      for (int i = 0; i < contacts.length; i++)
        contacts[i].copyWith(isPrimary: i == primaryIndex),
    ];
  }

  // ============================================================
  // EMERGENCY ALERTS (Phase 2)
  // ============================================================

  /// Create a new SOS alert. Returns the new alert ID.
  /// Also looks up the patient's assigned CHW and stamps it on the doc
  /// so the CHW-side listener can pick it up immediately (without
  /// waiting for a Cloud Function).
  Future<String> triggerAlert({
    required String patientId,
    required String patientName,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    // Look up the patient's assigned CHW
    String? chwId;
    String? chwName;
    try {
      final patientDoc =
          await _firestore.collection('patients').doc(patientId).get();
      if (patientDoc.exists) {
        chwId = patientDoc.data()?['assignedChwId'] as String?;
        if (chwId != null && chwId.isNotEmpty) {
          final chwDoc = await _firestore.collection('users').doc(chwId).get();
          if (chwDoc.exists) {
            chwName = chwDoc.data()?['displayName'] as String?;
          }
        }
      }
    } catch (_) {
      // non-fatal — alert still goes out
    }

    final docRef = _firestore.collection('emergencyAlerts').doc();
    final interactionRef = _firestore.collection('patientInteractions').doc();
    final batch = _firestore.batch();
    batch.set(docRef, {
      'patientId': patientId,
      'patientName': patientName,
      'chwId': chwId,
      'chwName': chwName,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'status': 'active',
      'responseType': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (chwId != null && chwId.isNotEmpty) {
      batch.set(interactionRef, {
        'patientId': patientId,
        'patientName': patientName,
        'chwId': chwId,
        'chwIds': [chwId],
        'chwName': chwName ?? 'CHW',
        'actorId': patientId,
        'actorName': patientName,
        'actorRole': 'patient',
        'type': 'emergency',
        'summary': 'Patient triggered an SOS alert',
        'details': address,
        'relatedRecordId': docRef.id,
        'source': 'mobile',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    return docRef.id;
  }

  /// Patient cancels their own alert before the CHW responds.
  Future<void> cancelAlert(String alertId, {String? reason}) async {
    await _recordAlertAction(
      alertId,
      updates: {
        'status': 'cancelled',
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolutionNotes': reason ?? 'Cancelled by patient',
      },
      summary: 'Patient cancelled SOS alert',
      details: reason,
    );
  }

  /// CHW marks the alert as being responded to.
  ///
  /// [responseType] must be either:
  ///   - 'coming' → CHW is on the way personally
  ///   - 'help_sent' → CHW has dispatched help (ambulance, family, etc.)
  Future<void> markResponding(
    String alertId,
    String chwName, {
    required String responseType,
  }) async {
    await _recordAlertAction(
      alertId,
      updates: {
        'status': 'responding',
        'responseType': responseType,
        'respondedAt': FieldValue.serverTimestamp(),
        'chwName': chwName,
      },
      summary: responseType == 'coming'
          ? 'CHW responded: on the way'
          : 'CHW responded: help dispatched',
    );
  }

  /// CHW marks the emergency as resolved.
  Future<void> resolveAlert(String alertId, {String? notes}) async {
    await _recordAlertAction(
      alertId,
      updates: {
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolutionNotes': notes,
      },
      summary: 'Emergency resolved',
      details: notes,
    );
  }

  /// Escalate the alert to a second CHW when the primary CHW does not
  /// acknowledge it in time. If there is no backup CHW available, the alert is
  /// escalated to the admin queue.
  Future<void> escalateAlertToNextChw(String alertId) async {
    final alertDoc =
        await _firestore.collection('emergencyAlerts').doc(alertId).get();
    if (!alertDoc.exists) return;

    final data = alertDoc.data() ?? {};
    final patientId = data['patientId'] as String?;
    final existingStatus = data['status'] as String? ?? 'active';
    if (existingStatus == 'resolved' || existingStatus == 'cancelled') return;
    if (data['secondaryChwId'] != null &&
        (data['secondaryChwId'] as String).isNotEmpty) {
      await _recordAlertAction(
        alertId,
        updates: {
          'status': 'pending_admin',
          'escalationLevel': 'admin',
          'escalatedAt': FieldValue.serverTimestamp(),
          'adminEscalated': true,
        },
        summary: 'SOS escalated to admin',
        details: 'No secondary CHW is available.',
      );
      return;
    }

    if (patientId == null || patientId.isEmpty) {
      await _recordAlertAction(
        alertId,
        updates: {
          'status': 'pending_admin',
          'escalationLevel': 'admin',
          'escalatedAt': FieldValue.serverTimestamp(),
          'adminEscalated': true,
        },
        summary: 'SOS escalated to admin',
        details: 'Patient and primary CHW details were unavailable.',
      );
      return;
    }

    final patientDoc =
        await _firestore.collection('patients').doc(patientId).get();
    final primaryChwId =
        (data['chwId'] ?? patientDoc.data()?['assignedChwId']) as String?;

    QueryDocumentSnapshot<Map<String, dynamic>>? nextChw;
    final usersSnapshot = await _firestore.collection('users').get();
    for (final doc in usersSnapshot.docs) {
      final raw = doc.data();
      final role = raw['role'];
      final status = raw['status'] as String? ?? 'Active';
      final uid = doc.id;
      final matchesRole =
          role is String ? role == 'chw' : role is List && role.contains('chw');
      final isDifferentChw = uid != primaryChwId;
      if (matchesRole && isDifferentChw && status.toLowerCase() == 'active') {
        nextChw = doc;
        break;
      }
    }

    if (nextChw == null) {
      await _recordAlertAction(
        alertId,
        updates: {
          'status': 'pending_admin',
          'escalationLevel': 'admin',
          'escalatedAt': FieldValue.serverTimestamp(),
          'adminEscalated': true,
        },
        summary: 'SOS escalated to admin',
        details: 'No secondary CHW is available.',
      );
      return;
    }

    final nextChwData = nextChw.data();
    final nextChwName =
        (nextChwData['displayName'] ?? nextChwData['name']) as String? ?? 'CHW';
    await _recordAlertAction(
      alertId,
      updates: {
        'secondaryChwId': nextChw.id,
        'secondaryChwName': nextChwName,
        'status': 'pending_second_chw',
        'escalationLevel': 'second_chw',
        'escalatedAt': FieldValue.serverTimestamp(),
        'adminEscalated': false,
      },
      summary: 'SOS escalated to second CHW',
      details: 'Assigned to $nextChwName.',
    );
  }

  /// If a second CHW does not respond either, the alert is escalated to the
  /// admin team. This is intended to be triggered by a timeout or scheduled job.
  Future<void> escalateAlertToAdmin(String alertId) async {
    await _recordAlertAction(
      alertId,
      updates: {
        'status': 'pending_admin',
        'escalationLevel': 'admin',
        'escalatedAt': FieldValue.serverTimestamp(),
        'adminEscalated': true,
      },
      summary: 'SOS escalated to admin',
    );
  }

  // ============================================================
  // STREAMS (realtime listeners)
  // ============================================================

  /// For the patient: is there an active alert of *mine* right now?
  /// Used to show "help is on the way" banner on the patient side.
  Stream<EmergencyAlert?> watchMyActiveAlert(String patientId) {
    return _firestore
        .collection('emergencyAlerts')
        .where('patientId', isEqualTo: patientId)
        .where('status', whereIn: ['active', 'responding'])
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          // Take the newest
          final docs = snapshot.docs.toList()
            ..sort((a, b) {
              final aT = a.data()['createdAt'];
              final bT = b.data()['createdAt'];
              if (aT is Timestamp && bT is Timestamp) return bT.compareTo(aT);
              return 0;
            });
          final doc = docs.first;
          return EmergencyAlert.fromMap(doc.data(), doc.id);
        });
  }

  /// For the CHW: all active alerts for patients assigned to them.
  Stream<List<EmergencyAlert>> watchActiveAlertsForChw(String chwId) {
    return _firestore
        .collection('emergencyAlerts')
        .where('chwId', isEqualTo: chwId)
        .where('status', whereIn: [
          'active',
          'responding',
          'pending_second_chw',
          'pending_admin',
        ])
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => EmergencyAlert.fromMap(doc.data(), doc.id))
              .toList();
          // Sort newest first
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// For a second CHW: all escalated alerts assigned to them.
  Stream<List<EmergencyAlert>> watchActiveAlertsForSecondaryChw(String chwId) {
    return _firestore
        .collection('emergencyAlerts')
        .where('secondaryChwId', isEqualTo: chwId)
        .where('status', whereIn: [
          'pending_second_chw',
          'responding',
          'pending_admin',
        ])
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => EmergencyAlert.fromMap(doc.data(), doc.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Watch a single alert by ID (for the detail screen).
  Stream<EmergencyAlert?> watchAlert(String alertId) {
    return _firestore
        .collection('emergencyAlerts')
        .doc(alertId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return EmergencyAlert.fromMap(doc.data()!, doc.id);
    });
  }
}
