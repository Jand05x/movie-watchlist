import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/review.dart';

class TasteService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('You must be logged in to build a taste profile.');
    }
    return user.uid;
  }

  static Future<void> recompute() async {
    try {
      final uid = _uid;
      final snapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('reviews')
          .limit(500)
          .get();

      final reviews = snapshot.docs
          .map((document) => Review.fromMap(document.data()))
          .toList();

      final genreCounts = <String, int>{};
      final genreIds = <String, int>{};
      for (final review in reviews) {
        for (final genre in review.genres) {
          if (genre.name.isEmpty) continue;
          genreCounts[genre.name] = (genreCounts[genre.name] ?? 0) + 1;
          if (genre.id != 0) genreIds[genre.name] = genre.id;
        }
      }

      final genres = genreCounts.entries.toList()
        ..sort(
          (a, b) => b.value == a.value
              ? a.key.compareTo(b.key)
              : b.value.compareTo(a.value),
        );

      final rated = reviews.where((review) => review.rating != null).toList()
        ..sort((a, b) => b.rating!.compareTo(a.rating!));

      await _db.collection('taste').doc(uid).set({
        'uid': uid,
        'genreScores': genres.take(5).map((entry) {
          return {
            'id': genreIds[entry.key] ?? 0,
            'name': entry.key,
            'count': entry.value,
          };
        }).toList(),
        'watchedIds': reviews
            .where((review) => review.watched)
            .map((review) => review.tmdbId)
            .toList(),
        'favoriteIds': rated
            .where((review) => review.rating! >= 4)
            .map((review) => review.tmdbId)
            .toList(),
        'topRated': rated.take(5).map((review) {
          return {
            'movieId': review.tmdbId,
            'title': review.title,
            'posterPath': review.posterPath,
            'rating': review.rating,
          };
        }).toList(),
        'ratedCount': rated.length,
        'watchedCount': reviews.where((review) => review.watched).length,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> forUser(String uid) async {
    final document = await _db.collection('taste').doc(uid).get();
    return document.exists ? document.data() : null;
  }
}
