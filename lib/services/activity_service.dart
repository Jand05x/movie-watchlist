import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/activity_entry.dart';
import 'friend_service.dart';
import 'notification_service.dart';
import 'user_service.dart';

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

  static CollectionReference<Map<String, dynamic>> _feed(String uid) =>
      _db.collection('users').doc(uid).collection('feed');

  static List<String> _participants(String otherUid) {
    final ids = [_uid, otherUid]..sort();
    return ids;
  }

  static Map<String, dynamic> _movieData(Map<String, dynamic> movie) {
    final id = movie['id'] ?? movie['tmdbId'];
    if (id is! num) throw ArgumentError('Movie ID is missing.');

    return {
      'movieId': id.toInt(),
      'title': movie['title'] ?? movie['name'] ?? 'Untitled',
      'posterPath': movie['poster_path'] ?? movie['posterPath'] ?? '',
      'mediaType': movie['media_type'] ?? movie['mediaType'] ?? 'movie',
      'rating': movie['rating'],
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
    final payload = <String, dynamic>{
      ...data,
      'senderUid': _uid,
      'recipientUid': friendUid,
      'participants': _participants(friendUid),
      'kind': kind,
      'note': note.trim(),
      'message': note.trim(),
      'status': 'sent',
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': <String, String>{},
    };

    final batch = _db.batch();
    batch.set(_shares.doc(shareId), payload);
    batch.set(_feed(friendUid).doc(shareId), payload);
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
    );
    await batch.commit();
  }

  static Future<void> shareWithFriends(
    Map<String, dynamic> movie, {
    required List<String> friendUids,
    String kind = 'movie',
    String note = '',
  }) async {
    final recipients = friendUids.toSet().where((uid) => uid != _uid).toList();
    for (final uid in recipients) {
      await share(movie, friendUid: uid, kind: kind, note: note);
    }
  }

  static Stream<List<ActivityEntry>> feed() {
    return _feed(_uid)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .where((document) => document.get('status') != 'declined')
              .map(
                (document) => ActivityEntry.fromMap(
                  document.data(),
                  document.id,
                ),
              )
              .toList(),
        );
  }

  static Stream<List<ActivityEntry>> inbox() {
    return _shares
        .where('recipientUid', isEqualTo: _uid)
        .where('status', isEqualTo: 'sent')
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

  static Future<void> respond(String shareId, bool accepted) async {
    final document = _shares.doc(shareId);
    final snapshot = await document.get();
    if (!snapshot.exists) return;

    final data = snapshot.data()!;
    final senderUid = (data['senderUid'] as String?) ?? '';
    final recipientUid = (data['recipientUid'] as String?) ?? '';
    final title = (data['title'] as String?) ?? 'this movie';
    final status = accepted ? 'accepted' : 'declined';
    final isInvite = data['kind'] == 'watch_together';

    final batch = _db.batch();
    batch.update(document, {
      'status': status,
      'respondedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_feed(recipientUid).doc(shareId), {
      'status': status,
    }, SetOptions(merge: true));
    await batch.commit();

    final profile = await UserService.profile(_uid);
    final name = profile?.displayName ?? 'Your friend';
    await NotificationService.push(
      senderUid,
      type: isInvite ? 'watch_reply' : 'share_reply',
      title: isInvite ? 'Watch night set' : 'Share reply',
      body: accepted
          ? '$name said yes to $title'
          : '$name passed on $title',
      shareId: shareId,
    );
  }

  static Future<void> react(String shareId, String emoji) async {
    final document = _shares.doc(shareId);
    final snapshot = await document.get();
    if (!snapshot.exists) return;

    final recipientUid = (snapshot.get('recipientUid') as String?) ?? '';
    final reactions = Map<String, dynamic>.from(
      snapshot.get('reactions') as Map? ?? const {},
    );
    reactions[_uid] = emoji;

    final batch = _db.batch();
    batch.set(document, {'reactions': reactions}, SetOptions(merge: true));
    batch.set(_feed(recipientUid).doc(shareId), {
      'reactions': reactions,
    }, SetOptions(merge: true));
    await batch.commit();
  }
}
