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
  final DateTime? createdAt;

  const Friendship({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.status,
    this.createdAt,
  });

  factory Friendship.fromMap(Map<String, dynamic> map, String documentId) {
    return Friendship(
      id: documentId,
      userId: (map['userId'] as String?) ?? '',
      friendId: (map['friendId'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'pending',
      createdAt: parseDate(map['createdAt']),
    );
  }

  bool get isAccepted => status == 'accepted';
  bool get isPending => status == 'pending';

  String otherUser(String currentUid) =>
      userId == currentUid ? friendId : userId;

  bool isIncoming(String currentUid) => isPending && friendId == currentUid;
  bool isOutgoing(String currentUid) => isPending && userId == currentUid;
}
