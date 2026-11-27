import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/friendship.dart';
import '../models/user_profile.dart';
import '../services/friend_service.dart';
import '../services/user_service.dart';

class FriendsScreen extends StatelessWidget {
  final bool embedded;

  const FriendsScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final body = StreamBuilder<List<Friendship>>(
      stream: FriendService.relationships(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFE50914)),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load friends.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final items = snapshot.data ?? [];
        final incoming = items.where((item) => item.isIncoming(uid)).toList();
        final outgoing = items.where((item) => item.isOutgoing(uid)).toList();
        final friends = items.where((item) => item.isAccepted).toList();

        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Color(0xFFE50914)),
                  SizedBox(height: 20),
                  Text(
                    'No friends yet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Use the + button to find someone by email or username.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (incoming.isNotEmpty) ...[
              _heading('Incoming requests'),
              ...incoming.map(
                (friendship) => _requestTile(
                  context,
                  friendship,
                  friendship.userId,
                  true,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (outgoing.isNotEmpty) ...[
              _heading('Sent requests'),
              ...outgoing.map(
                (friendship) => _requestTile(
                  context,
                  friendship,
                  friendship.friendId,
                  false,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (friends.isNotEmpty) ...[
              _heading('Your friends'),
              ...friends.map(
                (friendship) => _friendTile(
                  context,
                  friendship,
                  friendship.otherUser(uid),
                ),
              ),
            ],
          ],
        );
      },
    );

    if (embedded) return body;

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        title: const Text('Friends'),
      ),
      body: body,
    );
  }

  Widget _heading(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFE50914),
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _requestTile(
    BuildContext context,
    Friendship friendship,
    String otherUid,
    bool incoming,
  ) {
    return Card(
      color: const Color(0xFF252525),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF3A3A3A),
          child: Icon(Icons.person, color: Colors.white70),
        ),
        title: _UserName(uid: otherUid),
        subtitle: Text(
          incoming ? 'Wants to be friends' : 'Request pending',
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        trailing: incoming
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Accept',
                    icon: const Icon(Icons.check, color: Colors.greenAccent),
                    onPressed: () => _run(
                      context,
                      () => FriendService.accept(friendship.id),
                      'Friend request accepted.',
                    ),
                  ),
                  IconButton(
                    tooltip: 'Decline',
                    icon: const Icon(Icons.close, color: Colors.redAccent),
                    onPressed: () => _run(
                      context,
                      () => FriendService.remove(friendship.id),
                      'Request declined.',
                    ),
                  ),
                ],
              )
            : IconButton(
                tooltip: 'Cancel request',
                icon: const Icon(Icons.cancel_outlined, color: Colors.white70),
                onPressed: () => _run(
                  context,
                  () => FriendService.remove(friendship.id),
                  'Request cancelled.',
                ),
              ),
      ),
    );
  }

  Widget _friendTile(
    BuildContext context,
    Friendship friendship,
    String otherUid,
  ) {
    return Card(
      color: const Color(0xFF252525),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF3A3A3A),
          child: Icon(Icons.person, color: Colors.white70),
        ),
        title: _UserName(uid: otherUid),
        subtitle: const Text(
          'Shares public activity with you',
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
        trailing: IconButton(
          tooltip: 'Remove friend',
          icon: const Icon(Icons.person_remove_outlined, color: Color(0xFFE50914)),
          onPressed: () => _run(
            context,
            () => FriendService.remove(friendship.id),
            'Friend removed.',
          ),
        ),
      ),
    );
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
    String message,
  ) async {
    try {
      await action();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update: $e')));
    }
  }
}

class _UserName extends StatelessWidget {
  final String uid;

  const _UserName({required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: UserService.profile(uid),
      builder: (context, snapshot) {
        final fallback = uid.length > 6 ? uid.substring(0, 6) : uid;
        return Text(
          snapshot.data?.label ?? 'User $fallback',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        );
      },
    );
  }
}
