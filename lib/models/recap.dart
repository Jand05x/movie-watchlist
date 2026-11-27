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
  final List<RecapBadge> badges;

  const RecapStats({
    required this.monthStart,
    required this.watchedCount,
    required this.distinctDays,
    required this.longestStreak,
    required this.topGenre,
    required this.highestRatedTitle,
    required this.highestRating,
    required this.badges,
  });
}

RecapStats computeRecap(List<Review> reviews, DateTime now) {
  final start = DateTime(now.year, now.month);
  final end = DateTime(now.year, now.month + 1);

  final watched = reviews.where((review) {
    final timestamp = review.timestamp;
    return review.watched &&
        timestamp != null &&
        !timestamp.isBefore(start) &&
        timestamp.isBefore(end);
  }).toList();

  final days = <DateTime>{};
  for (final review in watched) {
    final timestamp = review.timestamp!;
    days.add(DateTime(timestamp.year, timestamp.month, timestamp.day));
  }

  final sortedDays = days.toList()..sort();
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

  final genreCounts = <String, int>{};
  for (final review in watched) {
    for (final genre in review.genres) {
      if (genre.name.isEmpty) continue;
      genreCounts[genre.name] = (genreCounts[genre.name] ?? 0) + 1;
    }
  }
  final topGenre = genreCounts.entries.isEmpty
      ? null
      : (List<MapEntry<String, int>>.from(genreCounts.entries)
            ..sort(
              (a, b) => b.value == a.value
                  ? a.key.compareTo(b.key)
                  : b.value.compareTo(a.value),
            ))
          .first
          .key;

  Review? best;
  for (final review in watched) {
    final rating = review.rating;
    if (rating == null) continue;
    if (best == null ||
        rating > (best.rating ?? 0) ||
        (rating == best.rating &&
            (review.timestamp ?? start).isAfter(best.timestamp ?? start))) {
      best = review;
    }
  }

  final count = watched.length;
  return RecapStats(
    monthStart: start,
    watchedCount: count,
    distinctDays: sortedDays.length,
    longestStreak: longestStreak,
    topGenre: topGenre,
    highestRatedTitle: best?.title,
    highestRating: best?.rating?.toDouble(),
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
    ],
  );
}
