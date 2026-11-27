import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WatchlistService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String get _uid {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('You must be logged in to use your watchlist.');
    }

    return user.uid;
  }

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(_uid).collection('watchlist');

  static Future<void> add(Map<String, dynamic> movie) async {
    final id = movie['id'];

    if (id == null) {
      throw ArgumentError('Movie ID is missing.');
    }

    await _col.doc(id.toString()).set({
      'tmdb_id': id,
      'title': movie['title'] ?? 'Untitled',
      'poster_path': movie['poster_path'] ?? '',
      'media_type': movie['media_type'] ?? 'movie',
      'visibility': 'public',
      'watched': false,
      'added_at': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> setReviewFlags(
    int tmdbId, {
    required bool watched,
    required String visibility,
    int? rating,
  }) async {
    final data = <String, dynamic>{
      'watched': watched,
      'visibility': visibility,
    };
    if (rating != null) data['rating'] = rating;

    final document = _col.doc(tmdbId.toString());
    final snapshot = await document.get();
    if (!snapshot.exists) return;

    await document.set(data, SetOptions(merge: true));
  }

  static Future<void> remove(int tmdbId) async {
    await _col.doc(tmdbId.toString()).delete();
  }

  static Stream<List<Map<String, dynamic>>> watchlist() {
    return _col
        .orderBy('added_at', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((document) => document.data()).toList(),
        );
  }

  static Future<bool> isInWatchlist(int tmdbId) async {
    final document = await _col.doc(tmdbId.toString()).get();
    return document.exists;
  }
}
