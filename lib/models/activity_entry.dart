import 'model_helpers.dart';

class ActivityEntry {
  final String id;
  final String userId;
  final String type;
  final int movieId;
  final String title;
  final String posterPath;
  final String mediaType;
  final double? rating;
  final String visibility;
  final DateTime? timestamp;

  const ActivityEntry({
    required this.id,
    required this.userId,
    required this.type,
    required this.movieId,
    required this.title,
    required this.posterPath,
    required this.mediaType,
    this.rating,
    this.visibility = 'public',
    this.timestamp,
  });

  factory ActivityEntry.fromMap(Map<String, dynamic> map, String documentId) {
    final rawId = map['movieId'];
    return ActivityEntry(
      id: documentId,
      userId: (map['userId'] as String?) ?? '',
      type: (map['type'] as String?) ?? 'watched',
      movieId: rawId is num ? rawId.toInt() : 0,
      title: (map['title'] as String?) ?? 'Untitled',
      posterPath: (map['posterPath'] as String?) ?? '',
      mediaType: (map['mediaType'] as String?) ?? 'movie',
      rating: (map['rating'] as num?)?.toDouble(),
      visibility: (map['visibility'] as String?) ?? 'public',
      timestamp: parseDate(map['timestamp']),
    );
  }

  bool get isRating => type == 'rated';
}
