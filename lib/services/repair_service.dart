import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/model_helpers.dart';
import 'review_service.dart';
import 'taste_service.dart';
import 'user_service.dart';
import 'watchlist_service.dart';

class RepairService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> run() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    UserService.clearCache();
    var profile = await UserService.fetchProfile(uid);
    if (profile == null) {
      await UserService.ensureProfile();
      profile = await UserService.fetchProfile(uid);
    }
    if (profile == null) {
      throw StateError('Could not create your profile.');
    }
    if (profile.schemaVersion >= 2) return;

    final reviews = await ReviewService.allReviews();
    final entries = await WatchlistService.allEntries().first;
    final entryIds = <String>{
      for (final entry in entries)
        if (entry['tmdb_id'] is num) (entry['tmdb_id'] as num).toInt().toString(),
    };
    final writes = <({DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> data})>[];

    for (final review in reviews) {
      if (review.tmdbId <= 0) continue;
      final id = review.tmdbId.toString();
      writes.add((
        ref: WatchlistService.entryRef(review.tmdbId),
        data: WatchlistService.moviePayload(
          review.movieSnapshot,
          watched: review.watched,
          visibility: review.visibility,
          rating: review.rating,
          includeCreatedAt: !entryIds.contains(id),
        ),
      ));
      entryIds.add(id);
    }

    for (final entry in entries) {
      final rawId = entry['tmdb_id'];
      if (rawId is! num) continue;
      final data = <String, dynamic>{
        'tmdb_id': rawId.toInt(),
        'title': entry['title'] ?? 'Untitled',
        'poster_path': entry['poster_path'] ?? '',
        'media_type': entry['media_type'] ?? 'movie',
        'visibility': entry['visibility'] ?? 'private',
        'watched': entry['watched'] == true,
        if (parseDate(entry['added_at']) == null)
          'added_at': FieldValue.serverTimestamp(),
      };
      if (entry['rating'] is num) data['rating'] = entry['rating'];
      writes.add((ref: WatchlistService.entryRef(rawId.toInt()), data: data));
    }

    final userRef = _db.collection('users').doc(uid);
    final profileWrite = <String, dynamic>{
      'schemaVersion': 2,
      'tasteShared': profile.tasteShared,
      'discoverable': profile.discoverable,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (writes.isEmpty) {
      await userRef.set(profileWrite, SetOptions(merge: true));
    } else {
      for (var start = 0; start < writes.length; start += 450) {
        final batch = _db.batch();
        final end = (start + 450 < writes.length) ? start + 450 : writes.length;
        for (final write in writes.sublist(start, end)) {
          batch.set(write.ref, write.data, SetOptions(merge: true));
        }
        if (end == writes.length) {
          batch.set(userRef, profileWrite, SetOptions(merge: true));
        }
        await batch.commit();
      }
    }

    UserService.clearCache();
    await TasteService.recompute();
  }
}
