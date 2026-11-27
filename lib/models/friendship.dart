import 'model_helpers.dart';

String friendshipPairId(String first, String second) {
  final parts = [first, second]..sort();
  return '${parts[0]}_${parts[1]}';
}

class Friendship {
  final String id;
  final String userId;
  final String friendId;
  final String status;
  final List<String> participants;
  final DateTime? createdAt;
  final String? responderUid;
  final DateTime? respondedAt;

  const Friendship({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.status,
    this.participants = const [],
    this.createdAt,
    this.responderUid,
    this.respondedAt,
  });

  factory Friendship.fromMap(Map<String, dynamic> map, String documentId) {
    final userId = (map['userId'] as String?) ?? '';
    final friendId = (map['friendId'] as String?) ?? '';
    final rawParticipants = map['participants'];

    return Friendship(
      id: documentId,
      userId: userId,
      friendId: friendId,
      status: (map['status'] as String?) ?? 'pending',
      participants: rawParticipants is List
          ? rawParticipants.whereType<String>().toList()
          : [userId, friendId].where((uid) => uid.isNotEmpty).toList(),
      createdAt: parseDate(map['createdAt']),
      responderUid: map['responderUid'] as String?,
      respondedAt: parseDate(map['respondedAt']),
    );
  }

  bool get isAccepted => status == 'accepted';
  bool get isPending => status == 'pending';
  bool get isDeclined => status == 'declined';
  bool get isCancelled => status == 'cancelled';

  String otherUser(String currentUid) {
    if (userId == currentUid) return friendId;
    if (friendId == currentUid) return userId;
    return participants.firstWhere(
      (uid) => uid != currentUid,
      orElse: () => '',
    );
  }

  bool isIncoming(String currentUid) => isPending && friendId == currentUid;
  bool isOutgoing(String currentUid) => isPending && userId == currentUid;

  bool wasDeclinedBy(String currentUid) =>
      isDeclined && responderUid == currentUid;

  bool wasDeclinedFor(String currentUid) =>
      isDeclined && userId == currentUid && responderUid != currentUid;
}
