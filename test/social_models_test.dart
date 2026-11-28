import 'package:flutter_test/flutter_test.dart';

import 'package:movie_watchlist/models/activity_entry.dart';

void main() {
  test('activity entry reads universal feed fields and counts reactions', () {
    final entry = ActivityEntry.fromMap({
      'type': 'rated',
      'actorUid': 'alice',
      'movieId': 42,
      'title': 'A Movie',
      'poster_path': '/poster.jpg',
      'participants': ['alice', 'bob'],
      'reactions': {'alice': '🍿', 'bob': '🍿', 'carol': '❤️'},
    }, 'activity-1');

    expect(entry.kind, 'rated');
    expect(entry.senderUid, 'alice');
    expect(entry.posterPath, '/poster.jpg');
    expect(entry.participants, ['alice', 'bob']);
    expect(entry.reactionCounts['🍿'], 2);
    expect(entry.reactionCounts['❤️'], 1);
    expect(entry.reactionBy('bob'), '🍿');
  });
}
