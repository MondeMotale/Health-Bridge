import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/emergency_contact.dart';

class EmergencyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ---------- READ ----------
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

  // ---------- WRITE ----------
  /// Replace the entire list. Also enforces "only one primary":
  /// if multiple have isPrimary=true, only the first is kept as primary.
  Future<void> saveContacts(
    String patientId,
    List<EmergencyContact> contacts,
  ) async {
    final normalised = _enforceSinglePrimary(contacts);
    await _firestore.collection('patients').doc(patientId).update({
      'emergencyContacts': normalised.map((c) => c.toMap()).toList(),
    });
  }

  Future<void> addContact(
    String patientId,
    EmergencyContact contact,
  ) async {
    final current = await getContacts(patientId);
    // If this is the first contact, force it primary
    final toAdd = current.isEmpty ? contact.copyWith(isPrimary: true) : contact;
    // If the new one is primary, unset the others
    final updated = toAdd.isPrimary
        ? current.map((c) => c.copyWith(isPrimary: false)).toList()
        : current;
    updated.add(toAdd);
    await saveContacts(patientId, updated);
  }

  Future<void> updateContact(
    String patientId,
    EmergencyContact contact,
  ) async {
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
    // If we deleted the primary, promote the first remaining contact
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

  /// Ensures at most one contact has `isPrimary == true`.
  /// If none have it and the list is non-empty, the first becomes primary.
  List<EmergencyContact> _enforceSinglePrimary(
    List<EmergencyContact> contacts,
  ) {
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
}