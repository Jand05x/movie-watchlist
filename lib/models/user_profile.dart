class UserProfile {
  final String uid;
  final String email;
  final String username;
  final String displayName;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.username,
    required this.displayName,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map, String documentId) {
    final username = (map['username'] as String?) ?? '';
    return UserProfile(
      uid: (map['uid'] as String?) ?? documentId,
      email: (map['email'] as String?) ?? '',
      username: username,
      displayName: (map['displayName'] as String?) ?? username,
    );
  }

  String get label => displayName.isNotEmpty ? displayName : username;
}
