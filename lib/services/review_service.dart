import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/review.dart';
import 'taste_service.dart';
import 'watchlist_service.dart';

class ReviewService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const Map<int, String> _genreNames = {
    12: 'Adventure',
    14: 'Fantasy',
    16: 'Animation',
    18: 'Drama',
    27: 'Horror',
    28: 'Action',
    35: 'Comedy',
    36: 'History',
    37: 'Western',
    53: 'Thriller',
    80: 'Crime',
    99: 'Documentary',
    878: 'Science Fiction',
    9648: 'Mystery',
    10402: 'Music',
    10749: 'Romance',
    10751: 'Family',
    10752: 'War',
    10759: 'Action & Adventure',
    10762: 'Kids',
    10763: 'News',
    10764: 'Reality',
    10765: 'Sci-Fi & Fantasy',
    10766: 'Soap',
    10767: 'Talk',
    10768: 'War & Politics',
    10770: 'TV Movie',
  };

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
    final id = movie['id'] ?? movie['tmdbId'] ?? movie['tmdb_id'];
    if (id is! num) throw ArgumentError('Movie ID is missing.');
    return id.toInt();
  }

  static List<Map<String, dynamic>> _genres(Map<String, dynamic> movie) {
    final raw = movie['genres'];
    if (raw is List) {
      return raw.whereType<Map>().map((genre) {
        final id = genre['id'];
        final genreId = id is num ? id.toInt() : 0;
        final name = (genre['name'] as String?)?.trim().isNotEmpty == true
            ? (genre['name'] as String).trim()
            : _genreNames[genreId] ?? '';
        return <String, dynamic>{'id': genreId, 'name': name};
      }).toList();
    }

    final ids = movie['genre_ids'];
    if (ids is List) {
      return ids.whereType<num>().map((rawId) {
        final genreId = rawId.toInt();
        return <String, dynamic>{
          'id': genreId,
          'name': _genreNames[genreId] ?? '',
        };
      }).toList();
    }

    return const [];
  }

  static Map<String, dynamic> _movieData(Map<String, dynamic> movie) {
    return {
      'tmdbId': _id(movie),
      'title': movie['title'] ?? movie['name'] ?? 'Untitled',
      'posterPath': movie['poster_path'] ?? movie['posterPath'] ?? '',
      'mediaType': movie['media_type'] ?? movie['mediaType'] ?? 'movie',
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
    final snapshot = await _reviews.get();
    return snapshot.docs
        .map((document) => Review.fromMap(document.data()))
        .toList();
  }

  static Future<Map<String, dynamic>?> snapshot(int tmdbId) async {
    final document = await _reviews.doc(tmdbId.toString()).get();
    return document.exists ? document.data() : null;
  }

  static Future<void> restore(Map<String, dynamic> review) async {
    final id = review['tmdbId'] ?? review['id'];
    if (id is! num) return;
    await _reviews.doc(id.toInt().toString()).set(review);
    await TasteService.recompute();
  }

  static Future<void> remove(int tmdbId) async {
    await _reviews.doc(tmdbId.toString()).delete();
    await TasteService.recompute();
  }

  static Future<void> _commit({
    required Map<String, dynamic> movie,
    required Map<String, dynamic> reviewData,
    required bool watched,
    String? visibility,
    int? rating,
  }) async {
    final id = _id(movie);
    final watchlistRef = WatchlistService.entryRef(id);
    final existingEntry = await watchlistRef.get();

    final batch = _db.batch();
    batch.set(_reviews.doc(id.toString()), reviewData, SetOptions(merge: true));
    batch.set(
      watchlistRef,
      WatchlistService.moviePayload(
        movie,
        watched: watched,
        visibility: visibility,
        rating: rating,
        includeCreatedAt: !existingEntry.exists,
      ),
      SetOptions(merge: true),
    );
    await batch.commit();
    await TasteService.recompute();
  }

  static Future<void> setWatched(
    Map<String, dynamic> movie, {
    required bool watched,
    required String visibility,
  }) async {
    final id = _id(movie);
    final existing = await _reviews.doc(id.toString()).get();
    final current = existing.exists ? Review.fromMap(existing.data()!) : null;

    final data = <String, dynamic>{
      ..._movieData(movie),
      'watched': watched,
      'visibility': visibility,
      'updatedAt': FieldValue.serverTimestamp(),
      'timestamp': FieldValue.serverTimestamp(),
      if (watched)
        'watchedAt': current?.watchedAt != null
            ? Timestamp.fromDate(current!.watchedAt!)
            : FieldValue.serverTimestamp()
      else
        'watchedAt': FieldValue.delete(),
    };
    await _commit(
      movie: movie,
      reviewData: data,
      watched: watched,
      visibility: visibility,
    );
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
    final existing = await _reviews.doc(id.toString()).get();
    final current = existing.exists ? Review.fromMap(existing.data()!) : null;

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

    await _commit(
      movie: movie,
      reviewData: data,
      watched: true,
      visibility: visibility,
      rating: rating,
    );
  }

  static Future<void> setVisibility(
    int tmdbId, {
    required String visibility,
  }) async {
    final document = _reviews.doc(tmdbId.toString());
    final snapshot = await document.get();
    final data = snapshot.exists ? snapshot.data()! : <String, dynamic>{};
    final watched = data['watched'] == true;
    final rating = data['rating'] is num ? (data['rating'] as num).toInt() : null;

    final batch = _db.batch();
    if (snapshot.exists) {
      batch.set(document, {
        'visibility': visibility,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    final watchlistRef = WatchlistService.entryRef(tmdbId);
    final existingEntry = await watchlistRef.get();
    batch.set(
      watchlistRef,
      {
        'watched': watched,
        'visibility': visibility,
        'rating': ?rating,
        if (!existingEntry.exists) 'added_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
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
