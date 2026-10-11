class EmergencyContact {
  final String id;              // unique within the patient's list
  final String name;
  final String relationship;    // 'Son', 'Daughter', 'Neighbour', 'Spouse', etc.
  final String phone;
  final bool isPrimary;         // the first person auto-called on SOS
  final String? notes;          // e.g. "Works night shift", "Speaks English only"

  EmergencyContact({
    required this.id,
    required this.name,
    required this.relationship,
    required this.phone,
    this.isPrimary = false,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'relationship': relationship,
    'phone': phone,
    'isPrimary': isPrimary,
    'notes': notes,
  };

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: map['name'] ?? '',
      relationship: map['relationship'] ?? '',
      phone: map['phone'] ?? '',
      isPrimary: map['isPrimary'] ?? false,
      notes: map['notes'],
    );
  }

  EmergencyContact copyWith({
    String? id,
    String? name,
    String? relationship,
    String? phone,
    bool? isPrimary,
    String? notes,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      phone: phone ?? this.phone,
      isPrimary: isPrimary ?? this.isPrimary,
      notes: notes ?? this.notes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EmergencyContact &&
          other.id == id &&
          other.name == name &&
          other.relationship == relationship &&
          other.phone == phone &&
          other.isPrimary == isPrimary &&
          other.notes == notes);

  @override
  int get hashCode =>
      Object.hash(id, name, relationship, phone, isPrimary, notes);

  @override
  String toString() =>
      'EmergencyContact($name, $relationship, $phone, primary: $isPrimary)';
}