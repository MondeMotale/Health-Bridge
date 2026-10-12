import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/emergency_contact.dart';
import '../models/emergency_alert.dart';

class EmergencyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    await _firestore.collection('patients').doc(patientId).update({
      'emergencyContacts': normalised.map((c) => c.toMap()).toList(),
    });
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

  Future<void> updateContact(
      String patientId, EmergencyContact contact) async {
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
    final updated = current
        .map((c) => c.copyWith(isPrimary: c.id == contactId))
        .toList();
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
          final chwDoc =
              await _firestore.collection('users').doc(chwId).get();
          if (chwDoc.exists) {
            chwName = chwDoc.data()?['displayName'] as String?;
          }
        }
      }
    } catch (_) {
      // non-fatal — alert still goes out
    }

    final docRef = await _firestore.collection('emergencyAlerts').add({
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

    return docRef.id;
  }

  /// Patient cancels their own alert before the CHW responds.
  Future<void> cancelAlert(String alertId, {String? reason}) async {
    await _firestore.collection('emergencyAlerts').doc(alertId).update({
      'status': 'cancelled',
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolutionNotes': reason ?? 'Cancelled by patient',
    });
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
    await _firestore.collection('emergencyAlerts').doc(alertId).update({
      'status': 'responding',
      'responseType': responseType, // 'coming' | 'help_sent'
      'respondedAt': FieldValue.serverTimestamp(),
      'chwName': chwName,
    });
  }

  /// CHW marks the emergency as resolved.
  Future<void> resolveAlert(String alertId, {String? notes}) async {
    await _firestore.collection('emergencyAlerts').doc(alertId).update({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolutionNotes': notes,
    });
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
        .where('status', whereIn: ['active', 'responding'])
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