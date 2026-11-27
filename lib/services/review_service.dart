import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/review.dart';
import 'activity_service.dart';
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

  static Future<Review?> forMovie(int tmdbId) async {
    final document = await _reviews.doc(tmdbId.toString()).get();
    if (!document.exists) return null;
    return Review.fromMap(document.data()!);
  }

  static Future<void> markWatched(
    Map<String, dynamic> movie, {
    required bool watched,
    required String visibility,
  }) async {
    final id = _id(movie);
    final document = await _reviews.doc(id.toString()).get();
    final wasWatched = document.exists && document.get('watched') == true;

    await _reviews.doc(id.toString()).set({
      ..._movieData(movie),
      'watched': watched,
      'visibility': visibility,
      'timestamp': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await WatchlistService.setReviewFlags(
      id,
      watched: watched,
      visibility: visibility,
    );

    if (watched && !wasWatched) {
      await ActivityService.record(
        type: 'watched',
        movieId: id,
        movie: movie,
        visibility: visibility,
      );
    }
  }

  static Future<void> saveRating(
    Map<String, dynamic> movie, {
    required int rating,
    required String visibility,
  }) async {
    final id = _id(movie);

    await _reviews.doc(id.toString()).set({
      ..._movieData(movie),
      'watched': true,
      'rating': rating,
      'visibility': visibility,
      'timestamp': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await WatchlistService.setReviewFlags(
      id,
      watched: true,
      rating: rating,
      visibility: visibility,
    );

    await ActivityService.record(
      type: 'rated',
      movieId: id,
      movie: movie,
      rating: rating.toDouble(),
      visibility: visibility,
    );
  }

  static Future<void> setVisibility(
    int tmdbId, {
    required String visibility,
  }) async {
    await _reviews.doc(tmdbId.toString()).set({
      'visibility': visibility,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await WatchlistService.setReviewFlags(
      tmdbId,
      watched: true,
      visibility: visibility,
    );

    final snapshot = await _db
        .collection('activity')
        .where('userId', isEqualTo: _uid)
        .where('movieId', isEqualTo: tmdbId)
        .get();

    final batch = _db.batch();
    for (final document in snapshot.docs) {
      batch.update(document.reference, {'visibility': visibility});
    }
    await batch.commit();
  }

  static Future<List<Review>> inMonth(DateTime start, DateTime end) async {
    final snapshot = await _reviews
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where('timestamp', isLessThan: Timestamp.fromDate(end))
        .get();

    return snapshot.docs.map((document) {
      return Review.fromMap(document.data());
    }).toList();
  }
}
