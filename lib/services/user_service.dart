import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';

class UserService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  static String normalize(String value) => value.trim().toLowerCase();

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
    if (name.isEmpty) {
      throw ArgumentError('Choose a username.');
    }
    if (await isUsernameTaken(name)) {
      throw StateError('That username is already taken.');
    }

    final batch = _db.batch();
    batch.set(_db.collection('usernames').doc(name), {'uid': user.uid});
    batch.set(_users.doc(user.uid), {
      'uid': user.uid,
      'email': normalize(user.email ?? ''),
      'username': name,
      'displayName': name,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  static Future<UserProfile?> ensureProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final document = await _users.doc(user.uid).get();
    if (!document.exists) {
      final base = normalize(user.email?.split('@').first ?? 'movie')
          .replaceAll(RegExp(r'[^a-z0-9_]'), '');
      final root = base.isEmpty ? 'movie' : base;

      var candidate = root;
      var suffix = 0;
      while (await isUsernameTaken(candidate)) {
        suffix += 1;
        candidate = '$root$suffix';
      }
      await createProfile(username: candidate);
    }

    return profile(user.uid);
  }

  static Future<UserProfile?> profile(String uid) async {
    final document = await _users.doc(uid).get();
    if (!document.exists) return null;
    return UserProfile.fromMap(document.data()!, document.id);
  }

  static Future<UserProfile?> findByEmail(String email) async {
    final address = normalize(email);
    if (address.isEmpty) return null;

    final snapshot = await _users
        .where('email', isEqualTo: address)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;

    final document = snapshot.docs.first;
    return UserProfile.fromMap(document.data(), document.id);
  }

  static Future<UserProfile?> findByUsername(String username) async {
    final name = normalize(username).replaceFirst(RegExp(r'^@'), '');
    if (name.isEmpty) return null;

    final reservation = await _db.collection('usernames').doc(name).get();
    if (!reservation.exists) return null;

    final uid = reservation.get('uid') as String?;
    if (uid == null) return null;
    return profile(uid);
  }
}
