import 'package:flutter_test/flutter_test.dart';

import 'package:movie_watchlist/models/activity_entry.dart';
import 'package:movie_watchlist/utils/activity_notes.dart';

void main() {
  ActivityEntry share({String note = ''}) {
    return ActivityEntry.fromMap({
      'senderUid': 'friend-1',
      'recipientUid': 'me',
      'movieId': 42,
      'title': 'A Movie',
      'note': note,
    }, 'share-1');
  }

  test('keeps only shares with note text', () {
    final notes = filterNotesWithText([
      share(note: '  Loved it  '),
      share(note: '   '),
      ActivityEntry.fromMap({'message': 'From a friend'}, 'share-2'),
    ]);

    expect(notes.length, 2);
    expect(notes.first.note, '  Loved it  ');
    expect(notes.last.note, 'From a friend');
  });

  test('returns an empty list when no note text exists', () {
    expect(filterNotesWithText([share(note: '\n')]), isEmpty);
    expect(filterNotesWithText(const <ActivityEntry>[]), isEmpty);
  });
}
