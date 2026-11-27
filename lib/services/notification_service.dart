import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('You must be logged in to use notifications.');
    }
    return user.uid;
  }

  static CollectionReference<Map<String, dynamic>> _for(String uid) =>
      _db.collection('users').doc(uid).collection('notifications');

  static Stream<List<Map<String, dynamic>>> forMe() {
    return _for(_uid)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((document) {
            return <String, dynamic>{'id': document.id, ...document.data()};
          }).toList(),
        );
  }

  static Future<void> push(
    String recipientUid, {
    required String type,
    required String title,
    required String body,
    String? shareId,
  }) async {
    if (recipientUid == _uid) return;

    await _for(recipientUid).add({
      'type': type,
      'title': title,
      'body': body,
      'actorUid': _uid,
      'shareId': shareId,
      'read': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> pushWithId(
    String recipientUid,
    String id, {
    required String type,
    required String title,
    required String body,
    String? shareId,
  }) async {
    if (recipientUid == _uid) return;

    await _for(recipientUid).doc(id).set({
      'type': type,
      'title': title,
      'body': body,
      'actorUid': _uid,
      'shareId': shareId,
      'read': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> markRead(String id) async {
    await _for(_uid).doc(id).set({
      'read': true,
    }, SetOptions(merge: true));
  }

  static Future<void> markAllRead() async {
    final snapshot = await _for(_uid).where('read', isEqualTo: false).get();
    final batch = _db.batch();
    for (final document in snapshot.docs) {
      batch.update(document.reference, {'read': true});
    }
    await batch.commit();
  }
}
