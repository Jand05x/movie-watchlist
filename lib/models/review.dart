import 'model_helpers.dart';

class MovieGenre {
  final int id;
  final String name;

  const MovieGenre({required this.id, required this.name});

  factory MovieGenre.fromMap(Map<String, dynamic> map) {
    final rawId = map['id'];
    return MovieGenre(
      id: rawId is num ? rawId.toInt() : 0,
      name: (map['name'] as String?) ?? '',
    );
  }

  @override
  String toString() => name;
}

class Review {
  final int tmdbId;
  final String title;
  final String posterPath;
  final String mediaType;
  final int? rating;
  final bool watched;
  final String visibility;
  final DateTime? watchedAt;
  final DateTime? ratedAt;
  final DateTime? timestamp;
  final String note;
  final List<MovieGenre> genres;

  const Review({
    required this.tmdbId,
    required this.title,
    required this.posterPath,
    required this.mediaType,
    this.rating,
    this.watched = false,
    this.visibility = 'public',
    this.watchedAt,
    this.ratedAt,
    this.timestamp,
    this.note = '',
    this.genres = const [],
  });

  factory Review.fromMap(Map<String, dynamic> map) {
    final rawId = map['tmdbId'] ?? map['id'];
    final rawRating = map['rating'];
    final rawGenres = map['genres'];

    return Review(
      tmdbId: rawId is num ? rawId.toInt() : 0,
      title: (map['title'] as String?) ?? 'Untitled',
      posterPath: (map['posterPath'] as String?) ?? '',
      mediaType: (map['mediaType'] as String?) ?? 'movie',
      rating: rawRating is num ? rawRating.round() : null,
      watched: map['watched'] as bool? ?? rawRating != null,
      visibility: (map['visibility'] as String?) ?? 'public',
      watchedAt: parseDate(map['watchedAt']),
      ratedAt: parseDate(map['ratedAt']),
      timestamp: parseDate(map['timestamp'] ?? map['updatedAt']),
      note: (map['note'] as String?) ?? '',
      genres: rawGenres is List
          ? rawGenres
              .whereType<Map<String, dynamic>>()
              .map(MovieGenre.fromMap)
              .toList()
          : const [],
    );
  }

  DateTime? get effectiveWatchedAt {
    if (!watched) return null;
    return watchedAt ?? timestamp;
  }

  Map<String, dynamic> get movieSnapshot => {
        'id': tmdbId,
        'title': title,
        'poster_path': posterPath,
        'media_type': mediaType,
        'vote_average': rating ?? 0,
      };
}
