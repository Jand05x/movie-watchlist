import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';
import '../models/friendship.dart';
import 'friend_service.dart';

class UserService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static final Map<String, UserProfile> _cache = {};

  static CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  static String normalize(String value) {
    return value.trim().toLowerCase().replaceFirst(RegExp(r'^@'), '');
  }

  static void clearCache() => _cache.clear();

  static Future<bool> canDiscover(UserProfile profile) async {
    if (profile.uid == _auth.currentUser?.uid) return true;
    if (profile.discoverable) return true;
    return FriendService.isFriend(profile.uid);
  }

  static bool usernameMatchesProfile(String requested, UserProfile profile) {
    return normalize(requested) == normalize(profile.username);
  }

  static bool isValidUsername(String value) {
    final name = normalize(value);
    return RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(name);
  }

  static Future<bool> isUsernameTaken(String username) async {
    final name = normalize(username);
    if (name.isEmpty) return false;

    final document = await _db.collection('usernames').doc(name).get();
    return document.exists;
  }

  static Future<void> createProfile({required String username}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be logged in to create a profile.');
    }

    final name = normalize(username);
    if (!isValidUsername(name)) {
      throw ArgumentError('Choose a 3-20 character username (letters, numbers, _).');
    }

    final reservation = _db.collection('usernames').doc(name);
    await _db.runTransaction((transaction) async {
      final existing = await transaction.get(reservation);
      if (existing.exists) {
        throw StateError('That username is already taken.');
      }

      transaction.set(reservation, {'uid': user.uid});
      transaction.set(_users.doc(user.uid), {
        'uid': user.uid,
        'email': normalize(user.email ?? ''),
        'username': name,
        'displayName': name,
        'bio': '',
        'avatarUrl': '',
        'discoverable': true,
        'tasteShared': true,
        'schemaVersion': 2,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<UserProfile?> ensureProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final document = await _users.doc(user.uid).get();
    if (!document.exists) {
      final base = normalize(user.email?.split('@').first ?? 'movie')
          .replaceAll(RegExp(r'[^a-z0-9_]'), '');
      var root = base.length >= 3 ? base.substring(0, 20) : 'movie';
      if (root.length < 3) root = 'movie';

      var candidate = root;
      var suffix = 0;
      while (await isUsernameTaken(candidate)) {
        suffix += 1;
        final suffixText = suffix.toString();
        candidate = suffixText.length >= 20
            ? suffixText.substring(0, 20)
            : '$root$suffixText';
        if (candidate.length > 20) {
          candidate =
              '${root.substring(0, 20 - suffixText.length)}$suffixText';
        }
      }
      await createProfile(username: candidate);
    }

    return profile(user.uid);
  }

  static Future<UserProfile?> profile(String uid) async {
    final cached = _cache[uid];
    if (cached != null) return cached;

    return fetchProfile(uid);
  }

  static Future<UserProfile?> fetchProfile(String uid) async {
    final document = await _users
        .doc(uid)
        .get(const GetOptions(source: Source.server));
    if (!document.exists) return null;

    final result = UserProfile.fromMap(document.data()!, document.id);
    _cache[uid] = result;
    return result;
  }

  static Stream<UserProfile?> profileStream(String uid) {
    return _users.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      final result = UserProfile.fromMap(snapshot.data()!, snapshot.id);
      _cache[uid] = result;
      return result;
    });
  }

  static Future<void> updateProfile({
    required String displayName,
    required String bio,
    required String avatarUrl,
    required bool discoverable,
    required bool tasteShared,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('You must be logged in to edit your profile.');
    }

    await _users.doc(uid).set({
      'displayName': displayName.trim().isEmpty ? 'Movie fan' : displayName.trim(),
      'bio': bio.trim(),
      'avatarUrl': avatarUrl.trim(),
      'discoverable': discoverable,
      'tasteShared': tasteShared,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _cache.remove(uid);
  }

  static Future<UserProfile?> findByEmail(String email) async {
    final address = normalize(email);
    if (address.isEmpty) return null;

    final snapshot = await _users
        .where('email', isEqualTo: address)
        .where('discoverable', isEqualTo: true)
        .limit(1)
        .get(const GetOptions(source: Source.server));
    if (snapshot.docs.isEmpty) return null;

    final document = snapshot.docs.first;
    final profile = UserProfile.fromMap(document.data(), document.id);
    return await canDiscover(profile) ? profile : null;
  }

  static Future<UserProfile?> findByUsername(String username) async {
    final name = normalize(username);
    if (name.isEmpty) return null;

    try {
      final reservation = await _db
          .collection('usernames')
          .doc(name)
          .get(const GetOptions(source: Source.server));
      if (reservation.exists) {
        final uid = reservation.get('uid') as String?;
        if (uid != null) {
          final profile = await fetchProfile(uid);
          if (profile != null &&
              usernameMatchesProfile(name, profile) &&
              await canDiscover(profile)) {
            return profile;
          }
        }
      }
    } catch (_) {}

    final byProfile = await _users
        .where('username', isEqualTo: name)
        .where('discoverable', isEqualTo: true)
        .limit(1)
        .get(const GetOptions(source: Source.server));
    if (byProfile.docs.isEmpty) return null;

    final document = byProfile.docs.first;
    final profile = UserProfile.fromMap(document.data(), document.id);
    return usernameMatchesProfile(name, profile) && await canDiscover(profile)
        ? profile
        : null;
  }

  static Future<List<UserProfile>> search(String query) async {
    final text = query.trim();
    if (text.isEmpty) return const [];

    final results = <String, UserProfile>{};
    if (text.contains('@')) {
      final byEmail = await findByEmail(text);
      if (byEmail != null) results[byEmail.uid] = byEmail;
    }

    final byUsername = await findByUsername(text);
    if (byUsername != null) results[byUsername.uid] = byUsername;

    final byName = await _users
        .where('displayName', isEqualTo: text)
        .where('discoverable', isEqualTo: true)
        .limit(5)
        .get();
    for (final document in byName.docs) {
      results[document.id] = UserProfile.fromMap(document.data(), document.id);
    }

    results.remove(_auth.currentUser?.uid);
    final visible = <String, UserProfile>{};
    for (final entry in results.entries) {
      if (await canDiscover(entry.value)) visible[entry.key] = entry.value;
    }
    return visible.values.toList();
  }

  static Future<List<UserProfile>> suggestions() async {
    final uid = _auth.currentUser?.uid;
    final snapshot = await _users
        .where('discoverable', isEqualTo: true)
        .limit(12)
        .get();

    return snapshot.docs
        .map((document) => UserProfile.fromMap(document.data(), document.id))
        .where((profile) => profile.uid != uid)
        .toList();
  }

  static Future<int> mutualFriendCount(String otherUid) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid == otherUid) return 0;

    final snapshot = await _db
        .collection('friendships')
        .where('participants', arrayContains: uid)
        .where('status', isEqualTo: 'accepted')
        .limit(50)
        .get();

    var count = 0;
    for (final document in snapshot.docs) {
      final friendship = Friendship.fromMap(document.data(), document.id);
      final candidate = friendship.otherUser(uid);
      if (candidate == otherUid) continue;

      final pair = _db
          .collection('friendships')
          .doc(friendshipPairId(candidate, otherUid));
      final mutual = await pair.get();
      if (mutual.exists && mutual.get('status') == 'accepted') count += 1;
    }
    return count;
  }
}
