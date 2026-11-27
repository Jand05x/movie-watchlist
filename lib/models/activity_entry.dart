import 'model_helpers.dart';

class ActivityEntry {
  final String id;
  final String senderUid;
  final String recipientUid;
  final String kind;
  final int movieId;
  final String title;
  final String posterPath;
  final String mediaType;
  final double? rating;
  final String note;
  final String message;
  final String status;
  final DateTime? timestamp;
  final Map<String, String> reactions;
  final List<Map<String, dynamic>> comments;

  const ActivityEntry({
    required this.id,
    required this.senderUid,
    this.recipientUid = '',
    required this.kind,
    required this.movieId,
    required this.title,
    required this.posterPath,
    required this.mediaType,
    this.rating,
    this.note = '',
    this.message = '',
    this.status = 'sent',
    this.timestamp,
    this.reactions = const {},
    this.comments = const [],
  });

  factory ActivityEntry.fromMap(Map<String, dynamic> map, String documentId) {
    final rawId = map['movieId'] ?? map['tmdb_id'];
    final rawReactions = map['reactions'];
    final rawComments = map['comments'];

    return ActivityEntry(
      id: documentId,
      senderUid: (map['senderUid'] as String?) ?? '',
      recipientUid: (map['recipientUid'] as String?) ?? '',
      kind: (map['kind'] as String?) ?? 'movie',
      movieId: rawId is num ? rawId.toInt() : 0,
      title: (map['title'] as String?) ?? 'Untitled',
      posterPath: (map['posterPath'] as String?) ?? '',
      mediaType: (map['mediaType'] as String?) ?? 'movie',
      rating: (map['rating'] as num?)?.toDouble(),
      note: (map['note'] as String?) ?? '',
      message: (map['message'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'sent',
      timestamp: parseDate(map['timestamp']),
      reactions: rawReactions is Map
          ? rawReactions.map(
              (key, value) => MapEntry<String, String>(
                key.toString(),
                value.toString(),
              ),
            )
          : const {},
      comments: rawComments is List
          ? rawComments.whereType<Map<String, dynamic>>().toList()
          : const [],
    );
  }

  bool get isInvite => kind == 'watch_together';
}
