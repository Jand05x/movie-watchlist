import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/review.dart';
import 'taste_service.dart';
import 'watchlist_service.dart';

class ReviewService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('You must be logged in to rate movies.');
    }
    return user.uid;
  }

  static CollectionReference<Map<String, dynamic>> get _reviews =>
      _db.collection('users').doc(_uid).collection('reviews');

  static int _id(Map<String, dynamic> movie) {
    final id = movie['id'];
    if (id is! num) throw ArgumentError('Movie ID is missing.');
    return id.toInt();
  }

  static List<Map<String, dynamic>> _genres(Map<String, dynamic> movie) {
    final raw = movie['genres'];
    if (raw is List) {
      return raw.whereType<Map>().map((genre) {
        return <String, dynamic>{
          'id': genre['id'] ?? 0,
          'name': genre['name'] ?? '',
        };
      }).toList();
    }

    final ids = movie['genre_ids'];
    if (ids is List) {
      return ids
          .map((id) => <String, dynamic>{'id': id, 'name': ''})
          .toList();
    }

    return const [];
  }

  static Map<String, dynamic> _movieData(Map<String, dynamic> movie) {
    return {
      'tmdbId': _id(movie),
      'title': movie['title'] ?? movie['name'] ?? 'Untitled',
      'posterPath': movie['poster_path'] ?? '',
      'mediaType': movie['media_type'] ?? 'movie',
      'genres': _genres(movie),
    };
  }

  static Stream<Review?> forMovieStream(int tmdbId) {
    return _reviews.doc(tmdbId.toString()).snapshots().map((snapshot) {
      return snapshot.exists ? Review.fromMap(snapshot.data()!) : null;
    });
  }

  static Future<Review?> forMovie(int tmdbId) async {
    final document = await _reviews.doc(tmdbId.toString()).get();
    if (!document.exists) return null;
    return Review.fromMap(document.data()!);
  }

  static Future<List<Review>> allReviews() async {
    final snapshot = await _reviews.limit(500).get();
    return snapshot.docs.map((document) {
      return Review.fromMap(document.data());
    }).toList();
  }

  static Future<void> setWatched(
    Map<String, dynamic> movie, {
    required bool watched,
    required String visibility,
  }) async {
    final id = _id(movie);
    final document = _reviews.doc(id.toString());
    final existing = await document.get();
    final current = existing.exists ? Review.fromMap(existing.data()!) : null;

    if (current != null &&
        current.watched == watched &&
        current.visibility == visibility) {
      return;
    }

    final data = <String, dynamic>{
      ..._movieData(movie),
      'watched': watched,
      'visibility': visibility,
      'updatedAt': FieldValue.serverTimestamp(),
      'timestamp': FieldValue.serverTimestamp(),
    };

    if (watched) {
      data['watchedAt'] = current?.watchedAt != null
          ? Timestamp.fromDate(current!.watchedAt!)
          : FieldValue.serverTimestamp();
    } else {
      data['watchedAt'] = FieldValue.delete();
    }

    await document.set(data, SetOptions(merge: true));
    await WatchlistService.setReviewFlags(
      id,
      watched: watched,
      visibility: visibility,
    );
    TasteService.recompute();
  }

  static Future<void> setRating(
    Map<String, dynamic> movie, {
    required int rating,
    required String visibility,
    String? note,
  }) async {
    if (rating < 1 || rating > 5) {
      throw ArgumentError('Rating must be between 1 and 5.');
    }

    final id = _id(movie);
    final document = _reviews.doc(id.toString());
    final existing = await document.get();
    final current = existing.exists ? Review.fromMap(existing.data()!) : null;

    if (current != null &&
        current.rating == rating &&
        current.visibility == visibility &&
        (note == null || current.note == note)) {
      return;
    }

    final data = <String, dynamic>{
      ..._movieData(movie),
      'watched': true,
      'rating': rating,
      'visibility': visibility,
      'ratedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'timestamp': FieldValue.serverTimestamp(),
      'watchedAt': current?.watchedAt != null
          ? Timestamp.fromDate(current!.watchedAt!)
          : FieldValue.serverTimestamp(),
    };
    if (note != null) data['note'] = note;

    await document.set(data, SetOptions(merge: true));
    await WatchlistService.setReviewFlags(
      id,
      watched: true,
      rating: rating,
      visibility: visibility,
    );
    TasteService.recompute();
  }

  static Future<void> setVisibility(
    int tmdbId, {
    required String visibility,
  }) async {
    final document = _reviews.doc(tmdbId.toString());
    final snapshot = await document.get();
    final watched = snapshot.exists && snapshot.get('watched') == true;

    if (snapshot.exists) {
      await document.set({
        'visibility': visibility,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await WatchlistService.setReviewFlags(
      tmdbId,
      watched: watched,
      visibility: visibility,
    );
  }

  static Future<void> setNote(int tmdbId, String note) async {
    await _reviews.doc(tmdbId.toString()).set({
      'note': note,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<List<Review>> inMonth(DateTime start, DateTime end) async {
    final byWatchedAt = await _reviews
        .where(
          'watchedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where('watchedAt', isLessThan: Timestamp.fromDate(end))
        .get();
    final byTimestamp = await _reviews
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where('timestamp', isLessThan: Timestamp.fromDate(end))
        .get();

    final merged = <String, Review>{};
    for (final document in [...byWatchedAt.docs, ...byTimestamp.docs]) {
      merged[document.id] = Review.fromMap(document.data());
    }
    return merged.values.toList();
  }
}
