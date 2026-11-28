import 'model_helpers.dart';

class ActivityEntry {
  static const List<String> allowedReactions = ['❤️', '😂', '👀', '🍿'];

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
  final List<String> participants;
  final String sourceId;

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
    this.participants = const [],
    this.sourceId = '',
  });

  factory ActivityEntry.fromMap(Map<String, dynamic> map, String documentId) {
    final rawId = map['movieId'] ?? map['tmdbId'] ?? map['tmdb_id'];
    final rawReactions = map['reactions'];
    final rawComments = map['comments'];
    final rawParticipants = map['participants'];
    final kind =
        (map['kind'] as String?) ??
        (map['type'] as String?) ??
        'movie';

    return ActivityEntry(
      id: (map['activityId'] as String?) ?? documentId,
      senderUid: (map['senderUid'] as String?) ??
          (map['actorUid'] as String?) ??
          '',
      recipientUid: (map['recipientUid'] as String?) ?? '',
      kind: kind,
      movieId: rawId is num ? rawId.toInt() : 0,
      title: (map['title'] as String?) ?? 'Untitled',
      posterPath: (map['posterPath'] as String?) ??
          (map['poster_path'] as String?) ??
          '',
      mediaType: (map['mediaType'] as String?) ??
          (map['media_type'] as String?) ??
          'movie',
      rating: (map['rating'] as num?)?.toDouble(),
      note: (map['note'] as String?) ?? (map['message'] as String?) ?? '',
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
      participants: rawParticipants is List
          ? rawParticipants.whereType<String>().toList()
          : const [],
      sourceId: (map['sourceId'] as String?) ?? '',
    );
  }

  bool get isInvite => kind == 'watch_together' || kind == 'watch_invite';

  Map<String, int> get reactionCounts {
    final counts = <String, int>{for (final emoji in allowedReactions) emoji: 0};
    for (final emoji in reactions.values) {
      if (counts.containsKey(emoji)) counts[emoji] = counts[emoji]! + 1;
    }
    return counts;
  }

  String? reactionBy(String uid) => reactions[uid];
}
