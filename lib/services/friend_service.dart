import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/friendship.dart';

enum FriendRequestOutcome {
  sent,
  alreadyFriends,
  pendingSent,
  pendingIncoming,
  recentlyDeclined,
  self,
}

class FriendRequestResult {
  final FriendRequestOutcome outcome;
  final String message;

  const FriendRequestResult({required this.outcome, required this.message});

  bool get didSend =>
      outcome == FriendRequestOutcome.sent ||
      outcome == FriendRequestOutcome.recentlyDeclined;
}

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
    final controller = StreamController<List<Friendship>>();
    final items = <String, Friendship>{};
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? participantsSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? senderSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? recipientSub;

    void emit() {
      if (controller.isClosed) return;
      final sorted = items.values.toList()
        ..sort((a, b) {
          final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return right.compareTo(left);
        });
      controller.add(sorted);
    }

    void onData(QuerySnapshot<Map<String, dynamic>> snapshot) {
      for (final document in snapshot.docs) {
        items[document.id] = Friendship.fromMap(document.data(), document.id);
      }
      emit();
    }

    void onError(Object error, StackTrace stack) {
      if (!controller.isClosed) controller.addError(error, stack);
    }

    controller.onCancel = () async {
      await participantsSub?.cancel();
      await senderSub?.cancel();
      await recipientSub?.cancel();
    };

    participantsSub = _collection
        .where('participants', arrayContains: _uid)
        .snapshots()
        .listen(onData, onError: onError);
    senderSub = _collection
        .where('userId', isEqualTo: _uid)
        .snapshots()
        .listen(onData, onError: onError);
    recipientSub = _collection
        .where('friendId', isEqualTo: _uid)
        .snapshots()
        .listen(onData, onError: onError);

    return controller.stream;
  }

  static Stream<List<Friendship>> incoming() => relationships().map(
        (items) => items.where((item) => item.isIncoming(_uid)).toList(),
      );

  static Stream<List<Friendship>> outgoing() => relationships().map(
        (items) => items.where((item) => item.isOutgoing(_uid)).toList(),
      );

  static Stream<List<Friendship>> friends() => relationships().map(
        (items) => items.where((item) => item.isAccepted).toList(),
      );

  static Stream<List<String>> acceptedFriendIds() => friends().map(
        (items) => items.map((item) => item.otherUser(_uid)).toList(),
      );

  static Future<bool> isFriend(String otherUid) async {
    if (otherUid == _uid) return false;

    final document = await _collection
        .doc(friendshipPairId(_uid, otherUid))
        .get(const GetOptions(source: Source.server));
    return document.exists && document.get('status') == 'accepted';
  }

  static Future<FriendRequestResult> sendRequest(String friendUid) async {
    if (friendUid == _uid) {
      return const FriendRequestResult(
        outcome: FriendRequestOutcome.self,
        message: 'That is your own account.',
      );
    }

    final id = friendshipPairId(_uid, friendUid);
    final document = _collection.doc(id);
    final participants = [_uid, friendUid]..sort();
    final fresh = <String, dynamic>{
      'userId': _uid,
      'friendId': friendUid,
      'participants': participants,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final result = await _db.runTransaction<FriendRequestResult>((transaction) async {
      final snapshot = await transaction.get(document);
      if (!snapshot.exists) {
        transaction.set(document, fresh);
        return const FriendRequestResult(
          outcome: FriendRequestOutcome.sent,
          message: 'Friend request sent.',
        );
      }

      final data = snapshot.data()!;
      final status = data['status'] as String?;
      if (status == 'accepted') {
        return const FriendRequestResult(
          outcome: FriendRequestOutcome.alreadyFriends,
          message: 'You are already friends.',
        );
      }
      if (status == 'pending') {
        if (data['userId'] == _uid) {
          return const FriendRequestResult(
            outcome: FriendRequestOutcome.pendingSent,
            message: 'A friend request is already pending.',
          );
        }
        return const FriendRequestResult(
          outcome: FriendRequestOutcome.pendingIncoming,
          message: 'This person already sent you a request. Check your requests.',
        );
      }
      if (status == 'declined' || status == 'cancelled') {
        transaction.update(document, {
          ...fresh,
          'responderUid': FieldValue.delete(),
          'respondedAt': FieldValue.delete(),
        });
        return const FriendRequestResult(
          outcome: FriendRequestOutcome.recentlyDeclined,
          message: 'Friend request sent again.',
        );
      }

      transaction.set(document, fresh);
      return const FriendRequestResult(
        outcome: FriendRequestOutcome.sent,
        message: 'Friend request sent.',
      );
    });

    if (result.didSend) {
      await _notification(friendUid, id).set({
        'type': 'friend_request',
        'title': 'Friend request',
        'body': 'Someone wants to be friends with you.',
        'actorUid': _uid,
        'friendshipId': id,
        'shareId': id,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    return result;
  }

  static DocumentReference<Map<String, dynamic>> _notification(
    String uid,
    String id,
  ) =>
      _db.collection('users').doc(uid).collection('notifications').doc(id);

  static Future<void> accept(String friendshipId) =>
      _respond(friendshipId, 'accepted', true);

  static Future<void> decline(String friendshipId) =>
      _respond(friendshipId, 'declined', false);

  static Future<void> _respond(
    String friendshipId,
    String status,
    bool accepted,
  ) async {
    final document = _collection.doc(friendshipId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);
      if (!snapshot.exists) {
        throw StateError('This friend request no longer exists.');
      }
      final data = snapshot.data()!;
      if (data['status'] != 'pending') {
        throw StateError('This request has already been answered.');
      }
      if (data['friendId'] != _uid) {
        throw StateError('Only the recipient can answer this request.');
      }

      final senderUid = (data['userId'] as String?) ?? '';
      transaction.update(document, {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        'respondedAt': FieldValue.serverTimestamp(),
        'responderUid': _uid,
      });
      transaction.set(
        _notification(senderUid, '${friendshipId}_response'),
        {
          'type': accepted ? 'friend_accepted' : 'friend_declined',
          'title': accepted ? 'Friend request accepted' : 'Friend request declined',
          'body': accepted
              ? 'Your friend accepted your request.'
              : 'Your friend declined your request.',
          'actorUid': _uid,
          'friendshipId': friendshipId,
          'read': false,
          'timestamp': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  static Future<void> cancel(String friendshipId) async {
    await _db.runTransaction((transaction) async {
      final document = _collection.doc(friendshipId);
      final snapshot = await transaction.get(document);
      if (!snapshot.exists) return;
      final data = snapshot.data()!;
      if (data['userId'] != _uid) {
        throw StateError('Only the sender can cancel this request.');
      }
      transaction.update(document, {
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
        'responderUid': _uid,
        'respondedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> remove(String friendshipId) =>
      _collection.doc(friendshipId).delete();
}
