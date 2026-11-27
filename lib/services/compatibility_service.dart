import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CompatibilityResult {
  final int score;
  final String band;
  final bool enoughData;
  final List<String> sharedGenres;
  final List<int> sharedMovieIds;
  final List<String> suggestedGenres;

  const CompatibilityResult({
    required this.score,
    required this.band,
    required this.enoughData,
    required this.sharedGenres,
    required this.sharedMovieIds,
    required this.suggestedGenres,
  });
}

class CompatibilityService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

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

  static Future<CompatibilityResult> scoreWith(String otherUid) async {
    if (otherUid == _uid) {
      return const CompatibilityResult(
        score: 0,
        band: 'Your taste',
        enoughData: false,
        sharedGenres: [],
        sharedMovieIds: [],
        suggestedGenres: [],
      );
    }

    final mineSnapshot = await _db.collection('taste').doc(_uid).get();
    final theirsSnapshot = await _db.collection('taste').doc(otherUid).get();
    if (!mineSnapshot.exists || !theirsSnapshot.exists) {
      return const CompatibilityResult(
        score: 0,
        band: 'Not enough data yet',
        enoughData: false,
        sharedGenres: [],
        sharedMovieIds: [],
        suggestedGenres: [],
      );
    }

    final mine = mineSnapshot.data()!;
    final theirs = theirsSnapshot.data()!;
    final myRated = _count(mine, 'ratedCount');
    final theirRated = _count(theirs, 'ratedCount');

    if (myRated < 3 || theirRated < 3) {
      return const CompatibilityResult(
        score: 0,
        band: 'Not enough data yet',
        enoughData: false,
        sharedGenres: [],
        sharedMovieIds: [],
        suggestedGenres: [],
      );
    }

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
    final sharedMovieIds = myIds.intersection(theirIds).toList();

    final genreOverlap = sharedGenres.fold<int>(
      0,
      (total, name) =>
          total + (myGenres[name] ?? 0) + (theirGenres[name] ?? 0),
    );
    final ratedFloor = myRated < theirRated ? myRated : theirRated;
    final watchedFloor = _count(mine, 'watchedCount') <
            _count(theirs, 'watchedCount')
        ? _count(mine, 'watchedCount')
        : _count(theirs, 'watchedCount');

    final genreRatio = (genreOverlap / (ratedFloor * 2).clamp(1, 999))
        .clamp(0.0, 1.0);
    final movieRatio = (sharedMovieIds.length /
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
      sharedGenres: sharedGenres.take(3).toList(),
      sharedMovieIds: sharedMovieIds.take(6).toList(),
      suggestedGenres: suggestedGenres.take(3).toList(),
    );
  }
}
