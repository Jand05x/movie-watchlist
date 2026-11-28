import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/activity_entry.dart';
import '../utils/activity_notes.dart';
import 'friend_service.dart';

class ActivityService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('You must be logged in to share movies.');
    }
    return user.uid;
  }

  static CollectionReference<Map<String, dynamic>> get _shares =>
      _db.collection('shares');

  static CollectionReference<Map<String, dynamic>> get _activities =>
      _db.collection('activities');

  static CollectionReference<Map<String, dynamic>> _feed(String uid) =>
      _db.collection('users').doc(uid).collection('feed');

  static List<String> _participants(String otherUid) {
    final ids = [_uid, otherUid]..sort();
    return ids;
  }

  static Map<String, dynamic> _movieData(Map<String, dynamic> movie) {
    final id = movie['id'] ?? movie['tmdbId'] ?? movie['tmdb_id'];
    if (id is! num) throw ArgumentError('Movie ID is missing.');

    return {
      'movieId': id.toInt(),
      'title': movie['title'] ?? movie['name'] ?? 'Untitled',
      'posterPath': movie['poster_path'] ?? movie['posterPath'] ?? '',
      'mediaType': movie['media_type'] ?? movie['mediaType'] ?? 'movie',
      'rating': movie['rating'],
    };
  }

  static Map<String, dynamic> _feedStub(
    String activityId,
    String viewerUid, {
    required String actorUid,
    required String status,
  }) {
    return {
      'activityId': activityId,
      'viewerUid': viewerUid,
      'actorUid': actorUid,
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  static Future<void> share(
    Map<String, dynamic> movie, {
    required String friendUid,
    String kind = 'movie',
    String note = '',
  }) async {
    if (!await FriendService.isFriend(friendUid)) {
      throw StateError('You can only share with accepted friends.');
    }

    final data = _movieData(movie);
    final shareId = _shares.doc().id;
    final isInvite = kind == 'watch_together';
    final type = isInvite ? 'watch_invite' : 'shared_movie';
    final participants = _participants(friendUid);
    final payload = <String, dynamic>{
      ...data,
      'activityId': shareId,
      'type': type,
      'kind': kind,
      'senderUid': _uid,
      'actorUid': _uid,
      'recipientUid': friendUid,
      'participants': participants,
      'note': note.trim(),
      'message': note.trim(),
      'status': 'sent',
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': <String, String>{},
    };

    final batch = _db.batch();
    batch.set(_shares.doc(shareId), payload);
    batch.set(_activities.doc(shareId), payload);
    batch.set(_feed(friendUid).doc(shareId), _feedStub(
      shareId,
      friendUid,
      actorUid: _uid,
      status: 'sent',
    ));
    batch.set(_feed(_uid).doc(shareId), _feedStub(
      shareId,
      _uid,
      actorUid: _uid,
      status: 'sent',
    ));
    batch.set(
      _db.collection('users').doc(friendUid).collection('notifications').doc(shareId),
      {
        'type': isInvite ? 'watch_invite' : 'shared_movie',
        'title': isInvite ? 'Watch this with me' : 'A movie for you',
        'body': '${data['title']}${note.trim().isEmpty ? '' : ' — ${note.trim()}'}',
        'actorUid': _uid,
        'shareId': shareId,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  static Future<int> shareWithFriends(
    Map<String, dynamic> movie, {
    required List<String> friendUids,
    String kind = 'movie',
    String note = '',
  }) async {
    final recipients = friendUids.toSet().where((uid) => uid != _uid).toList();
    final errors = <String>[];
    var sent = 0;

    for (final uid in recipients) {
      try {
        await share(movie, friendUid: uid, kind: kind, note: note);
        sent += 1;
      } catch (error) {
        errors.add('$uid: $error');
      }
    }

    if (sent == 0 && errors.isNotEmpty) {
      throw StateError('Could not send: ${errors.join('; ')}');
    }
    return sent;
  }

  static Future<void> postToFriends(
    String type,
    Map<String, dynamic> movie, {
    String note = '',
    double? rating,
    String sourceId = '',
  }) async {
    final friends = await FriendService.acceptedFriendIds().first;
    if (friends.isEmpty) return;

    final activityId = _activities.doc().id;
    final participants = <String>{_uid, ...friends}.toList()..sort();
    final data = _movieData(movie);
    final payload = <String, dynamic>{
      ...data,
      'activityId': activityId,
      'type': type,
      'kind': type,
      'senderUid': _uid,
      'actorUid': _uid,
      'participants': participants,
      'note': note.trim(),
      'status': 'sent',
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': <String, String>{},
      'sourceId': sourceId,
      'rating': ?rating,
    };

    final batch = _db.batch();
    batch.set(_activities.doc(activityId), payload);
    for (final viewerUid in participants) {
      batch.set(
        _feed(viewerUid).doc(activityId),
        _feedStub(
          activityId,
          viewerUid,
          actorUid: _uid,
          status: 'sent',
        ),
      );
    }
    await batch.commit();
  }

  static Stream<List<ActivityEntry>> feed() {
    return _feed(_uid)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .asyncMap((snapshot) async {
      final refs = snapshot.docs
          .map((document) {
            final activityId =
                (document.get('activityId') as String?) ?? document.id;
            return _activities.doc(activityId);
          })
          .toList();
      final sources = await Future.wait(refs.map((ref) => ref.get()));

      final entries = <ActivityEntry>[];
      for (var index = 0; index < snapshot.docs.length; index++) {
        final document = snapshot.docs[index];
        final source = sources[index];
        if (source.exists) {
          entries.add(ActivityEntry.fromMap(source.data()!, source.id));
        } else {
          entries.add(ActivityEntry.fromMap(document.data(), document.id));
        }
      }
      return entries.where((entry) => entry.status != 'declined').toList();
    });
  }

  static Stream<List<ActivityEntry>> inbox() {
    return _shares
        .where('recipientUid', isEqualTo: _uid)
        .orderBy('timestamp', descending: true)
        .limit(50)
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
  }

  static Stream<List<ActivityEntry>> notesFromFriends() {
    return inbox().map((entries) => filterNotesWithText(entries));
  }

  static Stream<List<ActivityEntry>> sent() {
    return _shares
        .where('senderUid', isEqualTo: _uid)
        .orderBy('timestamp', descending: true)
        .limit(50)
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
  }

  static Future<ActivityEntry?> shareById(String shareId) async {
    final document = await _shares
        .doc(shareId)
        .get(const GetOptions(source: Source.server));
    if (!document.exists) return null;
    return ActivityEntry.fromMap(document.data()!, document.id);
  }

}
