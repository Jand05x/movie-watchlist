class UserProfile {
  final String uid;
  final String email;
  final String username;
  final String displayName;
  final String bio;
  final String avatarUrl;
  final bool discoverable;
  final bool tasteShared;
  final int schemaVersion;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.username,
    required this.displayName,
    this.bio = '',
    this.avatarUrl = '',
    this.discoverable = true,
    this.tasteShared = true,
    this.schemaVersion = 0,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map, String documentId) {
    final username = (map['username'] as String?) ?? '';
    return UserProfile(
      uid: (map['uid'] as String?) ?? documentId,
      email: (map['email'] as String?) ?? '',
      username: username,
      displayName: (map['displayName'] as String?) ?? username,
      bio: (map['bio'] as String?) ?? '',
      avatarUrl: (map['avatarUrl'] as String?) ?? '',
      discoverable: map['discoverable'] as bool? ?? true,
      tasteShared: map['tasteShared'] as bool? ?? true,
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 0,
    );
  }

  String get label => displayName.isNotEmpty ? displayName : username;
}
