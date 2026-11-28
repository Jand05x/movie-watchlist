import 'review.dart';

class RecapBadge {
  final String id;
  final String title;
  final String description;
  final bool unlocked;

  const RecapBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.unlocked,
  });
}

class RecapStats {
  final DateTime monthStart;
  final int watchedCount;
  final int distinctDays;
  final int longestStreak;
  final String? topGenre;
  final String? highestRatedTitle;
  final double? highestRating;
  final Review? highestRatedMovie;
  final int ratedCount;
  final double? averageRating;
  final int distinctGenreCount;
  final List<MapEntry<String, int>> topGenres;
  final int noteCount;
  final String? mostActiveDayLabel;
  final int mostActiveDayCount;
  final List<Review> watchedMovies;
  final List<RecapBadge> badges;

  const RecapStats({
    required this.monthStart,
    required this.watchedCount,
    required this.distinctDays,
    required this.longestStreak,
    required this.topGenre,
    required this.highestRatedTitle,
    required this.highestRating,
    required this.highestRatedMovie,
    required this.ratedCount,
    required this.averageRating,
    required this.distinctGenreCount,
    required this.topGenres,
    required this.noteCount,
    required this.mostActiveDayLabel,
    required this.mostActiveDayCount,
    required this.watchedMovies,
    required this.badges,
  });
}

RecapStats computeRecap(List<Review> reviews, DateTime now) {
  final start = DateTime(now.year, now.month);
  final end = DateTime(now.year, now.month + 1);

  final watched = reviews.where((review) {
    final timestamp = review.effectiveWatchedAt;
    return timestamp != null &&
        !timestamp.isBefore(start) &&
        timestamp.isBefore(end);
  }).toList();

  final dayCounts = <DateTime, int>{};
  for (final review in watched) {
    final timestamp = review.effectiveWatchedAt!;
    final day = DateTime(timestamp.year, timestamp.month, timestamp.day);
    dayCounts[day] = (dayCounts[day] ?? 0) + 1;
  }

  final sortedDays = dayCounts.keys.toList()..sort();
  var streak = 0;
  var longestStreak = 0;
  for (var index = 0; index < sortedDays.length; index++) {
    if (index > 0 &&
        sortedDays[index].difference(sortedDays[index - 1]).inDays == 1) {
      streak += 1;
    } else {
      streak = 1;
    }
    if (streak > longestStreak) longestStreak = streak;
  }

  final mostActiveDay = dayCounts.entries.isEmpty
      ? null
      : (List<MapEntry<DateTime, int>>.from(dayCounts.entries)
            ..sort(
              (a, b) => b.value == a.value
                  ? a.key.compareTo(b.key)
                  : b.value.compareTo(a.value),
            ))
          .first;

  final genreCounts = <String, int>{};
  for (final review in watched) {
    for (final genre in review.genres) {
      if (genre.name.isEmpty) continue;
      genreCounts[genre.name] = (genreCounts[genre.name] ?? 0) + 1;
    }
  }
  final sortedGenres = List<MapEntry<String, int>>.from(genreCounts.entries)
    ..sort(
      (a, b) => b.value == a.value
          ? a.key.compareTo(b.key)
          : b.value.compareTo(a.value),
    );
  final topGenre = sortedGenres.isEmpty ? null : sortedGenres.first.key;

  Review? best;
  for (final review in watched) {
    final rating = review.rating;
    if (rating == null) continue;
    if (best == null ||
        rating > (best.rating ?? 0) ||
        (rating == best.rating &&
            (review.ratedAt ?? review.timestamp ?? start)
                .isAfter(best.ratedAt ?? best.timestamp ?? start))) {
      best = review;
    }
  }

  final ratings = watched
      .where((review) => review.rating != null)
      .map((review) => review.rating!)
      .toList();
  final averageRating = ratings.isEmpty
      ? null
      : ratings.reduce((a, b) => a + b) / ratings.length;
  final noteCount = watched
      .where((review) => review.note.trim().isNotEmpty)
      .length;

  final movies = List<Review>.from(watched)
    ..sort((a, b) {
      final left = a.effectiveWatchedAt ?? start;
      final right = b.effectiveWatchedAt ?? start;
      return right.compareTo(left);
    });

  final count = watched.length;
  return RecapStats(
    monthStart: start,
    watchedCount: count,
    distinctDays: sortedDays.length,
    longestStreak: longestStreak,
    topGenre: topGenre,
    highestRatedTitle: best?.title,
    highestRating: best?.rating?.toDouble(),
    highestRatedMovie: best,
    ratedCount: ratings.length,
    averageRating: averageRating,
    distinctGenreCount: sortedGenres.length,
    topGenres: sortedGenres.take(5).toList(),
    noteCount: noteCount,
    mostActiveDayLabel: mostActiveDay == null
        ? null
        : '${mostActiveDay.key.month}/${mostActiveDay.key.day}',
    mostActiveDayCount: mostActiveDay?.value ?? 0,
    watchedMovies: movies,
    badges: [
      RecapBadge(
        id: 'first_watched',
        title: 'First Watch',
        description: 'Log your first movie this month',
        unlocked: count >= 1,
      ),
      RecapBadge(
        id: 'ten_watched',
        title: 'Ten Down',
        description: 'Watch 10 movies in a month',
        unlocked: count >= 10,
      ),
      RecapBadge(
        id: 'streak_5',
        title: 'On a Roll',
        description: 'Watch on 5 days in a row',
        unlocked: longestStreak >= 5,
      ),
      RecapBadge(
        id: 'first_rating',
        title: 'First Take',
        description: 'Rate a movie this month',
        unlocked: ratings.isNotEmpty,
      ),
      RecapBadge(
        id: 'five_star',
        title: 'Five Star',
        description: 'Give a movie five stars',
        unlocked: ratings.any((rating) => rating == 5),
      ),
      RecapBadge(
        id: 'genre_explorer',
        title: 'Genre Explorer',
        description: 'Watch three different genres',
        unlocked: sortedGenres.length >= 3,
      ),
      RecapBadge(
        id: 'weekend_regular',
        title: 'Movie Habit',
        description: 'Watch on four different days',
        unlocked: sortedDays.length >= 4,
      ),
      RecapBadge(
        id: 'note_keeper',
        title: 'Note Keeper',
        description: 'Write a note on a watched movie',
        unlocked: noteCount >= 1,
      ),
    ],
  );
}
