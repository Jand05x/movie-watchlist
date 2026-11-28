import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/friendship.dart';
import '../models/user_profile.dart';
import '../services/friend_service.dart';
import '../services/user_service.dart';
import '../theme/brand.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_loading.dart';
import '../widgets/initials_avatar.dart';
import 'add_friend_screen.dart';
import 'profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  final bool embedded;

  const FriendsScreen({super.key, this.embedded = false});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  String? _busyId;
  int _refreshKey = 0;

  void _retry() {
    if (mounted) setState(() => _refreshKey++);
  }

  Future<void> _openAddFriend() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddFriendScreen()),
    );
    if (added == true) _retry();
  }

  Future<void> _run(
    String friendshipId,
    Future<void> Function() action,
    String message,
  ) async {
    setState(() => _busyId = friendshipId);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = StreamBuilder<List<Friendship>>(
      key: ValueKey('friends-$_refreshKey'),
      stream: FriendService.relationships(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoading(message: 'Loading friends...');
        }
        if (snapshot.hasError) {
          return AppErrorState(
            message: 'Could not load friends.\n${snapshot.error}',
            onRetry: _retry,
          );
        }

        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final items = snapshot.data ?? [];
        final incoming = items.where((item) => item.isIncoming(uid)).toList();
        final outgoing = items.where((item) => item.isOutgoing(uid)).toList();
        final friends = items.where((item) => item.isAccepted).toList();
        final declined = items.where((item) => item.isDeclined).toList();
        final cancelled = items.where((item) => item.isCancelled).toList();

        if (items.isEmpty) {
          return AppEmptyState(
            icon: Icons.people_outline,
            title: 'No friends yet',
            message: 'Find someone by email or username to start watching together.',
            actionLabel: widget.embedded ? null : 'Add friend',
            onAction: widget.embedded ? null : _openAddFriend,
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (incoming.isNotEmpty) ...[
              _heading('Incoming requests'),
              ...incoming.map(
                (item) => _tile(
                  context,
                  item,
                  otherUid: item.userId,
                  subtitle: 'Wants to be friends',
                  trailing: _pendingActions(item, incoming: true),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (outgoing.isNotEmpty) ...[
              _heading('Sent requests'),
              ...outgoing.map(
                (item) => _tile(
                  context,
                  item,
                  otherUid: item.friendId,
                  subtitle: 'Request pending',
                  trailing: _pendingActions(item, incoming: false),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (friends.isNotEmpty) ...[
              _heading('Your friends'),
              ...friends.map(
                (item) => _tile(
                  context,
                  item,
                  otherUid: item.otherUser(uid),
                  subtitle: 'Shares public activity with you',
                  trailing: IconButton(
                    tooltip: 'Remove friend',
                    icon: const Icon(
                      Icons.person_remove_outlined,
                      color: FlickerColors.danger,
                    ),
                    onPressed: _busyId == item.id
                        ? null
                        : () => _run(
                              item.id,
                              () => FriendService.remove(item.id),
                              'Friend removed.',
                            ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (declined.isNotEmpty) ...[
              _heading('Declined'),
              ...declined.map(
                (item) => _tile(
                  context,
                  item,
                  otherUid: item.otherUser(uid),
                  subtitle: item.wasDeclinedBy(uid)
                      ? 'You declined this request'
                      : 'They declined this request',
                  trailing: _endedActions(item),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (cancelled.isNotEmpty) ...[
              _heading('Cancelled'),
              ...cancelled.map(
                (item) => _tile(
                  context,
                  item,
                  otherUid: item.otherUser(uid),
                  subtitle: 'Request cancelled',
                  trailing: _endedActions(item),
                ),
              ),
            ],
          ],
        );
      },
    );

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: FlickerColors.canvas,
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            tooltip: 'Add friend',
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: _openAddFriend,
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _heading(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: FlickerText.label.copyWith(color: FlickerColors.primaryBright),
      ),
    );
  }

  Widget _pendingActions(Friendship item, {required bool incoming}) {
    final busy = _busyId == item.id;
    if (incoming) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Accept',
            icon: const Icon(Icons.check, color: Colors.greenAccent),
            onPressed: busy
                ? null
                : () => _run(
                      item.id,
                      () => FriendService.accept(item.id),
                      'Friend request accepted.',
                    ),
          ),
          IconButton(
            tooltip: 'Decline',
            icon: const Icon(Icons.close, color: FlickerColors.danger),
            onPressed: busy
                ? null
                : () => _run(
                      item.id,
                      () => FriendService.decline(item.id),
                      'Friend request declined.',
                    ),
          ),
        ],
      );
    }

    return IconButton(
      tooltip: 'Cancel request',
      icon: const Icon(Icons.cancel_outlined, color: FlickerColors.muted),
      onPressed: busy
          ? null
          : () => _run(
                item.id,
                () => FriendService.cancel(item.id),
                'Friend request cancelled.',
              ),
    );
  }

  Widget? _endedActions(Friendship item) {
    if (_busyId == item.id) {
      return const SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return IconButton(
      tooltip: 'Remove record',
      icon: const Icon(Icons.delete_outline, color: FlickerColors.muted),
      onPressed: () => _run(
        item.id,
        () => FriendService.remove(item.id),
        'Request removed.',
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    Friendship item, {
    required String otherUid,
    required String subtitle,
    Widget? trailing,
  }) {
    return Card(
      color: FlickerColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: _Avatar(uid: otherUid),
        title: _UserName(uid: otherUid),
        subtitle: Text(subtitle, style: FlickerText.caption),
        trailing: trailing,
        onTap: otherUid.isEmpty
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(friendUid: otherUid),
                  ),
                );
              },
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String uid;

  const _Avatar({required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: UserService.profile(uid),
      builder: (context, snapshot) {
        return InitialsAvatar(
          name: snapshot.data?.label ?? uid,
          imageUrl: snapshot.data?.avatarUrl,
          radius: 20,
        );
      },
    );
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
          style: FlickerText.body.copyWith(fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
