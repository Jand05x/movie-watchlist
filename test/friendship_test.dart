import 'package:flutter_test/flutter_test.dart';

import 'package:movie_watchlist/models/friendship.dart';

void main() {
  test('friendship parses decline metadata', () {
    final friendship = Friendship.fromMap(
      {
        'userId': 'alice',
        'friendId': 'bob',
        'status': 'declined',
        'responderUid': 'bob',
        'respondedAt': '2026-11-27T00:00:00.000Z',
      },
      'alice_bob',
    );

    expect(friendship.isDeclined, isTrue);
    expect(friendship.wasDeclinedFor('alice'), isTrue);
    expect(friendship.wasDeclinedBy('bob'), isTrue);
    expect(friendship.respondedAt, isNotNull);
  });

  test('legacy friendship falls back to participants for other user', () {
    final friendship = Friendship.fromMap(
      {
        'participants': ['alice', 'bob'],
        'status': 'accepted',
      },
      'alice_bob',
    );

    expect(friendship.isAccepted, isTrue);
    expect(friendship.otherUser('alice'), 'bob');
    expect(friendship.otherUser('bob'), 'alice');
  });

  test('pending request direction is derived from recipient', () {
    final friendship = Friendship(
      id: 'alice_bob',
      userId: 'alice',
      friendId: 'bob',
      status: 'pending',
    );

    expect(friendship.isIncoming('bob'), isTrue);
    expect(friendship.isOutgoing('alice'), isTrue);
    expect(friendship.isIncoming('alice'), isFalse);
  });
}
