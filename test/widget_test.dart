import 'package:flutter_test/flutter_test.dart';

import 'package:movie_watchlist/models/activity_entry.dart';
import 'package:movie_watchlist/models/friendship.dart';
import 'package:movie_watchlist/models/review.dart';
import 'package:movie_watchlist/models/recap.dart';

Review review({
  required int tmdbId,
  required DateTime date,
  int? rating,
  bool watched = true,
  List<MovieGenre> genres = const [],
  String title = 'Movie',
}) {
  return Review(
    tmdbId: tmdbId,
    title: title,
    posterPath: '',
    mediaType: 'movie',
    rating: rating,
    watched: watched,
    genres: genres,
    timestamp: date,
  );
}

void main() {
  final now = DateTime(2026, 11, 27);

  test('friendshipPairId is stable regardless of argument order', () {
    expect(friendshipPairId('alice', 'bob'), friendshipPairId('bob', 'alice'));
    expect(friendshipPairId('alice', 'bob'), 'alice_bob');
  });

  test('recap only counts watched entries from the current month', () {
    final stats = computeRecap(
      [
        review(
          tmdbId: 1,
          date: DateTime(2026, 11, 1),
          genres: const [MovieGenre(id: 28, name: 'Action')],
        ),
        review(
          tmdbId: 2,
          date: DateTime(2026, 10, 31),
          genres: const [MovieGenre(id: 18, name: 'Drama')],
        ),
        review(
          tmdbId: 3,
          date: DateTime(2026, 11, 2),
          watched: false,
          genres: const [MovieGenre(id: 18, name: 'Drama')],
        ),
      ],
      now,
    );

    expect(stats.watchedCount, 1);
    expect(stats.topGenre, 'Action');
    expect(stats.badges.first.unlocked, isTrue);
    expect(stats.badges.last.unlocked, isFalse);
  });

  test('recap picks highest rating and longest consecutive-day streak', () {
    final stats = computeRecap(
      [
        review(
          tmdbId: 1,
          date: DateTime(2026, 11, 1),
          rating: 4,
          title: 'First',
          genres: const [MovieGenre(id: 18, name: 'Drama')],
        ),
        review(
          tmdbId: 2,
          date: DateTime(2026, 11, 2),
          rating: 5,
          title: 'Best',
          genres: const [MovieGenre(id: 18, name: 'Drama')],
        ),
        review(tmdbId: 3, date: DateTime(2026, 11, 3)),
        review(tmdbId: 4, date: DateTime(2026, 11, 4)),
        review(tmdbId: 5, date: DateTime(2026, 11, 5)),
      ],
      now,
    );

    expect(stats.highestRatedTitle, 'Best');
    expect(stats.highestRating, 5);
    expect(stats.longestStreak, 5);
    expect(stats.badges.map((badge) => badge.unlocked), [true, false, true]);
  });

  test('watchedAt overrides the mutable update timestamp for recaps', () {
    final entry = Review(
      tmdbId: 1,
      title: 'Movie',
      posterPath: '',
      mediaType: 'movie',
      watched: true,
      watchedAt: DateTime(2026, 11, 2),
      timestamp: DateTime(2026, 12, 1),
    );

    final stats = computeRecap([entry], now);
    expect(entry.effectiveWatchedAt, DateTime(2026, 11, 2));
    expect(stats.watchedCount, 1);
  });

  test('share entries parse recipient and response status', () {
    final entry = ActivityEntry.fromMap(
      {
        'senderUid': 'alice',
        'recipientUid': 'bob',
        'kind': 'watch_together',
        'movieId': 42,
        'title': 'Movie',
        'status': 'accepted',
        'timestamp': '2026-11-27T00:00:00.000Z',
      },
      'share-1',
    );

    expect(entry.recipientUid, 'bob');
    expect(entry.status, 'accepted');
    expect(entry.isInvite, isTrue);
  });

  test('ten-watched badge unlocks at ten movies', () {
    final reviews = List.generate(
      10,
      (index) => review(
        tmdbId: index,
        date: DateTime(2026, 11, 1 + index),
      ),
    );

    final stats = computeRecap(reviews, now);
    expect(stats.badges[1].unlocked, isTrue);
  });
}
