import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/activity_entry.dart';

class ActivityService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('You must be logged in to use activity.');
    }
    return user.uid;
  }

  static CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('activity');

  static Future<void> record({
    required String type,
    required int movieId,
    required Map<String, dynamic> movie,
    double? rating,
    required String visibility,
  }) async {
    await _collection.add({
      'userId': _uid,
      'type': type,
      'movieId': movieId,
      'title': movie['title'] ?? movie['name'] ?? 'Untitled',
      'posterPath': movie['poster_path'] ?? '',
      'mediaType': movie['media_type'] ?? 'movie',
      'rating': rating,
      'visibility': visibility,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  static Stream<List<ActivityEntry>> feed(Stream<List<String>> friendIds) {
    return friendIds.asyncExpand((ids) => _feedFor(ids));
  }

  static Stream<List<ActivityEntry>> _feedFor(List<String> friendIds) {
    if (friendIds.isEmpty) return Stream.value(const []);

    final chunks = <List<String>>[];
    for (var start = 0; start < friendIds.length; start += 10) {
      chunks.add(
        friendIds.sublist(
          start,
          start + 10 > friendIds.length ? friendIds.length : start + 10,
        ),
      );
    }

    final controller = StreamController<List<ActivityEntry>>();
    final cache = List<List<ActivityEntry>>.filled(
      chunks.length,
      const <ActivityEntry>[],
    );
    final subscriptions = <StreamSubscription<dynamic>>[];

    void emit() {
      if (controller.isClosed) return;
      final combined = cache.expand((items) => items).toList()
        ..sort((a, b) {
          final left = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
          final right = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
          return right.compareTo(left);
        });
      controller.add(combined);
    }

    for (var index = 0; index < chunks.length; index++) {
      final stream = _collection
          .where('visibility', isEqualTo: 'public')
          .where('userId', whereIn: chunks[index])
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(
                  (document) => ActivityEntry.fromMap(
                    document.data(),
                    document.id,
                  ),
                )
                .toList(),
          );

      subscriptions.add(
        stream.listen(
          (items) {
            cache[index] = items;
            emit();
          },
          onError: controller.addError,
        ),
      );
    }

    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };

    return controller.stream;
  }
}
