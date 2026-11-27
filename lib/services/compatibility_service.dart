import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'user_service.dart';

class CompatibilityResult {
  final int score;
  final String band;
  final bool enoughData;
  final String reason;
  final String explanation;
  final List<String> sharedGenres;
  final List<int> sharedMovieIds;
  final List<String> sharedMovieTitles;
  final List<String> suggestedGenres;
  final int myRatedCount;
  final int theirRatedCount;

  const CompatibilityResult({
    this.score = 0,
    required this.band,
    this.enoughData = false,
    this.reason = 'not-enough-data',
    this.explanation = '',
    this.sharedGenres = const [],
    this.sharedMovieIds = const [],
    this.sharedMovieTitles = const [],
    this.suggestedGenres = const [],
    this.myRatedCount = 0,
    this.theirRatedCount = 0,
  });
}

class CompatibilityService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('You must be logged in to compare taste.');
    }
    return user.uid;
  }

  static int _count(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value is num ? value.toInt() : 0;
  }

  static Map<String, int> _genres(Map<String, dynamic> data) {
    final raw = data['genreScores'];
    if (raw is! List) return const {};

    final result = <String, int>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final name = item['name'] as String?;
      if (name == null || name.isEmpty) continue;
      final count = item['count'];
      result[name] = count is num ? count.toInt() : 0;
    }
    return result;
  }

  static List<int> _ids(Map<String, dynamic> data, String key) {
    final raw = data[key];
    if (raw is! List) return const [];

    return raw
        .whereType<num>()
        .map((value) => value.toInt())
        .toList();
  }

  static Map<int, String> _movieTitles(Map<String, dynamic> data) {
    final result = <int, String>{};
    for (final key in ['watchedMovies', 'favoriteMovies', 'topRated']) {
      final raw = data[key];
      if (raw is! List) continue;
      for (final item in raw) {
        if (item is! Map) continue;
        final id = item['movieId'];
        final title = item['title'] as String?;
        if (id is num && title != null && title.isNotEmpty) {
          result[id.toInt()] = title;
        }
      }
    }
    return result;
  }

  static CompatibilityResult calculate(
    Map<String, dynamic> mine,
    Map<String, dynamic> theirs,
  ) {
    final myRated = _count(mine, 'ratedCount');
    final theirRated = _count(theirs, 'ratedCount');
    final myGenres = _genres(mine);
    final theirGenres = _genres(theirs);
    final sharedGenres = myGenres.keys
        .where((name) => theirGenres.containsKey(name))
        .toList()
      ..sort((a, b) {
        final left = (myGenres[a] ?? 0) + (theirGenres[a] ?? 0);
        final right = (myGenres[b] ?? 0) + (theirGenres[b] ?? 0);
        return right.compareTo(left);
      });

    final myIds = _ids(mine, 'watchedIds').toSet();
    final theirIds = _ids(theirs, 'watchedIds').toSet();
    final sharedIds = myIds.intersection(theirIds).toList();
    final titles = _movieTitles(theirs);
    final titlesMine = _movieTitles(mine);
    final sharedTitles = sharedIds
        .map((id) => titles[id] ?? titlesMine[id])
        .whereType<String>()
        .take(6)
        .toList();

    final genreOverlap = sharedGenres.fold<int>(
      0,
      (total, name) =>
          total + (myGenres[name] ?? 0) + (theirGenres[name] ?? 0),
    );
    final ratedFloor = myRated < theirRated ? myRated : theirRated;
    final myWatched = _count(mine, 'watchedCount');
    final theirWatched = _count(theirs, 'watchedCount');
    final watchedFloor = myWatched < theirWatched ? myWatched : theirWatched;

    final genreRatio =
        (genreOverlap / (ratedFloor * 2).clamp(1, 999)).clamp(0.0, 1.0);
    final movieRatio = (sharedIds.length /
            (watchedFloor < 3 ? 3 : watchedFloor))
        .clamp(0.0, 1.0);
    final raw = ((genreRatio * 0.6) + (movieRatio * 0.4)) * 100;
    final score = raw.round().clamp(0, 100);

    final suggestedGenres = theirGenres.keys
        .where((name) => !myGenres.containsKey(name))
        .toList()
      ..sort((a, b) => theirGenres[b]!.compareTo(theirGenres[a]!));

    return CompatibilityResult(
      score: score,
      band: score >= 80
          ? 'Great match'
          : score >= 60
              ? 'Good match'
              : score >= 40
                  ? 'Different tastes'
                  : 'Opposites attract',
      enoughData: true,
      reason: 'ready',
      explanation:
          'Based on shared genres (60%) and watched movies in common (40%). '
          'You rated $myRated movies and they rated $theirRated.',
      sharedGenres: sharedGenres.take(3).toList(),
      sharedMovieIds: sharedIds.take(6).toList(),
      sharedMovieTitles: sharedTitles,
      suggestedGenres: suggestedGenres.take(3).toList(),
      myRatedCount: myRated,
      theirRatedCount: theirRated,
    );
  }

  static Future<CompatibilityResult> scoreWith(String otherUid) async {
    if (otherUid == _uid) {
      return const CompatibilityResult(
        band: 'Your taste',
        reason: 'self',
        explanation: 'This is your own taste profile.',
      );
    }

    final friend = await UserService.profile(otherUid);
    if (friend == null) {
      return const CompatibilityResult(
        band: 'Profile unavailable',
        reason: 'not-found',
        explanation: 'We could not find this profile.',
      );
    }
    if (!friend.tasteShared) {
      return const CompatibilityResult(
        band: 'Taste sharing is off',
        reason: 'not-shared',
        explanation: 'This friend has turned off taste sharing.',
      );
    }

    final mineSnapshot = await _db.collection('taste').doc(_uid).get();
    final theirsSnapshot = await _db.collection('taste').doc(otherUid).get();
    if (!mineSnapshot.exists || !theirsSnapshot.exists) {
      return const CompatibilityResult(
        band: 'Not enough data yet',
        reason: 'not-enough-data',
        explanation: 'Both people need at least 3 ratings before a match can be calculated.',
      );
    }

    final mine = mineSnapshot.data()!;
    final theirs = theirsSnapshot.data()!;
    if (_count(mine, 'ratedCount') < 3 || _count(theirs, 'ratedCount') < 3) {
      return const CompatibilityResult(
        band: 'Not enough data yet',
        reason: 'not-enough-data',
        explanation: 'Both people need at least 3 ratings before a match can be calculated.',
      );
    }

    return calculate(mine, theirs);
  }
}
