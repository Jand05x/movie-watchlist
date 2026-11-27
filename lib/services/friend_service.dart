import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/friendship.dart';

class FriendService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('You must be logged in to use friends.');
    }
    return user.uid;
  }

  static CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('friendships');

  static Stream<List<Friendship>> relationships() {
    return _collection
        .where('participants', arrayContains: _uid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) =>
                    Friendship.fromMap(document.data(), document.id),
              )
              .toList()
            ..sort(
              (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                  .compareTo(
                    a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                  ),
            ),
        );
  }

  static Stream<List<Friendship>> incoming() {
    return relationships().map(
      (items) => items.where((item) => item.isIncoming(_uid)).toList(),
    );
  }

  static Stream<List<Friendship>> outgoing() {
    return relationships().map(
      (items) => items.where((item) => item.isOutgoing(_uid)).toList(),
    );
  }

  static Stream<List<Friendship>> friends() {
    return relationships().map(
      (items) => items.where((item) => item.isAccepted).toList(),
    );
  }

  static Stream<List<String>> acceptedFriendIds() {
    return friends().map(
      (items) => items.map((item) => item.otherUser(_uid)).toList(),
    );
  }

  static Future<void> sendRequest(String friendUid) async {
    if (friendUid == _uid) {
      throw ArgumentError('You cannot add yourself as a friend.');
    }

    final id = friendshipPairId(_uid, friendUid);
    final existing = await _collection.doc(id).get();

    if (existing.exists) {
      final status = existing.get('status') as String?;
      if (status == 'accepted') {
        throw StateError('You are already friends.');
      }
      if (existing.get('userId') == _uid) {
        throw StateError('Request already pending.');
      }
      throw StateError('They already sent you a request. Check your requests.');
    }

    final participants = [_uid, friendUid]..sort();
    await _collection.doc(id).set({
      'userId': _uid,
      'friendId': friendUid,
      'participants': participants,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> accept(String friendshipId) async {
    await _collection.doc(friendshipId).update({
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> remove(String friendshipId) async {
    await _collection.doc(friendshipId).delete();
  }
}
