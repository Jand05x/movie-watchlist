import 'package:flutter_test/flutter_test.dart';

import 'package:movie_watchlist/services/compatibility_service.dart';

Map<String, dynamic> taste({
  required int rated,
  required int watched,
  List<Map<String, dynamic>> genres = const [],
  List<int> watchedIds = const [],
  List<Map<String, dynamic>> movies = const [],
}) {
  return {
    'ratedCount': rated,
    'watchedCount': watched,
    'genreScores': genres,
    'watchedIds': watchedIds,
    'watchedMovies': movies,
  };
}

void main() {
  test('identical taste produces a full score with shared details', () {
    final mine = taste(
      rated: 5,
      watched: 3,
      genres: [
        {'id': 28, 'name': 'Action', 'count': 5},
      ],
      watchedIds: [10, 20, 30],
      movies: [
        {'movieId': 10, 'title': 'First'},
        {'movieId': 20, 'title': 'Second'},
        {'movieId': 30, 'title': 'Third'},
      ],
    );

    final result = CompatibilityService.calculate(mine, Map<String, dynamic>.from(mine));

    expect(result.reason, 'ready');
    expect(result.enoughData, isTrue);
    expect(result.score, 100);
    expect(result.band, 'Great match');
    expect(result.sharedGenres, ['Action']);
    expect(result.sharedMovieIds, [10, 20, 30]);
    expect(result.sharedMovieTitles, contains('First'));
  });

  test('different taste explains the score and suggests genres', () {
    final mine = taste(
      rated: 4,
      watched: 3,
      genres: [
        {'id': 28, 'name': 'Action', 'count': 4},
      ],
      watchedIds: [10, 20, 30],
    );
    final theirs = taste(
      rated: 4,
      watched: 3,
      genres: [
        {'id': 18, 'name': 'Drama', 'count': 4},
      ],
      watchedIds: [40, 50, 60],
    );

    final result = CompatibilityService.calculate(mine, theirs);

    expect(result.reason, 'ready');
    expect(result.score, lessThan(40));
    expect(result.explanation, contains('shared genres'));
    expect(result.explanation, contains('You rated 4 movies'));
    expect(result.sharedGenres, isEmpty);
    expect(result.sharedMovieIds, isEmpty);
    expect(result.suggestedGenres, ['Drama']);
  });

  test('missing genre names are ignored instead of showing blank chips', () {
    final mine = taste(
      rated: 3,
      watched: 3,
      genres: [
        {'id': 28, 'name': '', 'count': 3},
      ],
    );
    final theirs = taste(
      rated: 3,
      watched: 3,
      genres: [
        {'id': 28, 'count': 3},
      ],
    );

    final result = CompatibilityService.calculate(mine, theirs);

    expect(result.sharedGenres, isEmpty);
    expect(result.score, 0);
  });
}
