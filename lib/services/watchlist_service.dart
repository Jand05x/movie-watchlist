import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/model_helpers.dart';
import 'activity_service.dart';

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

  static DocumentReference<Map<String, dynamic>> entryRef(int tmdbId) =>
      _col.doc(tmdbId.toString());

  static Map<String, dynamic> moviePayload(
    Map<String, dynamic> movie, {
    required bool watched,
    String? visibility,
    int? rating,
    bool includeCreatedAt = false,
  }) {
    final id = movie['id'] ?? movie['tmdb_id'] ?? movie['tmdbId'];
    if (id is! num) throw ArgumentError('Movie ID is missing.');

    return {
      'tmdb_id': id.toInt(),
      'title': movie['title'] ?? movie['name'] ?? 'Untitled',
      'poster_path': movie['poster_path'] ?? movie['posterPath'] ?? '',
      'media_type': movie['media_type'] ?? movie['mediaType'] ?? 'movie',
      'visibility': visibility ?? 'private',
      'watched': watched,
      'rating': ?rating,
      if (includeCreatedAt) 'added_at': FieldValue.serverTimestamp(),
    };
  }

  static Future<void> add(
    Map<String, dynamic> movie, {
    bool? watched,
    String? visibility,
    int? rating,
  }) async {
    final payload = moviePayload(
      movie,
      watched: watched ?? false,
      visibility: visibility,
      rating: rating,
      includeCreatedAt: true,
    );
    final id = payload['tmdb_id'] as int;
    final document = _col.doc(id.toString());
    final existing = await document.get();

    if (existing.exists) {
      final data = existing.data()!;
      await document.set({
        'title': data['title'] ?? payload['title'],
        'poster_path': data['poster_path'] ?? payload['poster_path'],
        'media_type': data['media_type'] ?? payload['media_type'],
        'visibility': data['visibility'] ?? payload['visibility'],
        'watched': data['watched'] ?? payload['watched'],
        if (data['rating'] != null || rating != null)
          'rating': data['rating'] ?? rating,
        if (parseDate(data['added_at']) == null)
          'added_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (visibility == 'public') {
        try {
          await ActivityService.postToFriends('watchlist_add', movie, sourceId: id.toString());
        } catch (_) {}
      }
      return;
    }

    await document.set(payload);
    if (visibility == 'public') {
      try {
        await ActivityService.postToFriends('watchlist_add', movie, sourceId: id.toString());
      } catch (_) {}
    }
  }

  static Future<void> restore(Map<String, dynamic> entry) async {
    final id = entry['tmdb_id'];
    if (id == null) return;

    final data = Map<String, dynamic>.from(entry);
    if (parseDate(data['added_at']) == null) {
      data['added_at'] = FieldValue.serverTimestamp();
    }
    await _col.doc(id.toString()).set(data, SetOptions(merge: true));
  }

  static Future<void> remove(int tmdbId) async {
    await _col.doc(tmdbId.toString()).delete();
  }

  static Stream<List<Map<String, dynamic>>> allEntries() =>
      _col.snapshots().map(
            (snapshot) => snapshot.docs
                .map((document) => document.data())
                .toList(),
          );

  static Stream<List<Map<String, dynamic>>> watchlist({
    String sort = 'recent',
  }) {
    return allEntries().map((entries) {
      final items = List<Map<String, dynamic>>.from(entries);
      items.sort((a, b) {
        if (sort == 'title') {
          final left = (a['title'] as String?) ?? 'Untitled';
          final right = (b['title'] as String?) ?? 'Untitled';
          return left.toLowerCase().compareTo(right.toLowerCase());
        }

        final left = parseDate(a['added_at']);
        final right = parseDate(b['added_at']);
        if (left == null && right == null) return 0;
        if (left == null) return 1;
        if (right == null) return -1;
        return right.compareTo(left);
      });
      return items;
    });
  }

  static Stream<Map<String, dynamic>?> entry(int tmdbId) {
    return _col.doc(tmdbId.toString()).snapshots().map(
          (snapshot) => snapshot.exists ? snapshot.data() : null,
        );
  }

  static Future<bool> isInWatchlist(int tmdbId) async {
    final document = await _col.doc(tmdbId.toString()).get();
    return document.exists;
  }

  static Future<void> setReviewFlags(
    int tmdbId, {
    required bool watched,
    String? visibility,
    int? rating,
  }) async {
    final document = _col.doc(tmdbId.toString());
    final data = <String, dynamic>{'watched': watched};
    if (visibility != null) data['visibility'] = visibility;
    if (rating != null) data['rating'] = rating;

    await document.set(data, SetOptions(merge: true));
    if (visibility == 'public' && watched) {
      try {
        final saved = await document.get(const GetOptions(source: Source.server));
        await ActivityService.postToFriends(
          'watched',
          saved.data() ?? {'id': tmdbId},
          sourceId: tmdbId.toString(),
        );
      } catch (_) {}
    }
  }
}
