import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:movie_watchlist/utils/movie_picker.dart';

void main() {
  final movies = [
    {'tmdb_id': 1, 'title': 'One', 'media_type': 'movie'},
    {'tmdb_id': 2, 'title': 'Two', 'media_type': 'movie'},
    {'tmdb_id': 3, 'title': 'Three', 'media_type': 'movie'},
  ];

  test('random picker returns null for an empty list', () {
    expect(pickRandomMovie(const [], Random(1)), isNull);
  });

  test('random picker avoids the previous pick when alternatives exist', () {
    final random = Random(42);
    final first = pickRandomMovie(movies, random)!;
    final lastKey = moviePickKey(first);

    for (var index = 0; index < 10; index++) {
      final next = pickRandomMovie(movies, random, lastKey: lastKey)!;
      expect(moviePickKey(next), isNot(lastKey));
    }
  });

  test('random picker falls back when only one option exists', () {
    final single = [movies.first];
    final pick = pickRandomMovie(
      single,
      Random(3),
      lastKey: moviePickKey(movies.first),
    );

    expect(pick, movies.first);
  });
}
