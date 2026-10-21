class ChwProfile {
  final String uid;
  final String email;
  final String displayName;
  final String phoneNumber;
  final String address;
  final String bio;
  final String profileImageUrl;

  ChwProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.phoneNumber = '',
    this.address = '',
    this.bio = '',
    this.profileImageUrl = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'address': address,
      'bio': bio,
      'profileImageUrl': profileImageUrl,
    };
  }

  factory ChwProfile.fromMap(Map<String, dynamic> map) {
    return ChwProfile(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? 'CHW User',
      phoneNumber: map['phoneNumber'] ?? '',
      address: map['address'] ?? '',
      bio: map['bio'] ?? '',
      profileImageUrl: map['profileImageUrl'] ?? '',
    );
  }
}