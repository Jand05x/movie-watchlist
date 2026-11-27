import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/friendship.dart';
import '../models/user_profile.dart';
import '../services/activity_service.dart';
import '../services/friend_service.dart';
import '../services/user_service.dart';
import '../theme/brand.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_loading.dart';
import '../widgets/initials_avatar.dart';

class SharePickerScreen extends StatefulWidget {
  final Map<String, dynamic> movie;

  const SharePickerScreen({super.key, required this.movie});

  @override
  State<SharePickerScreen> createState() => _SharePickerScreenState();
}

class _SharePickerScreenState extends State<SharePickerScreen> {
  final TextEditingController _note = TextEditingController();
  final Set<String> _selected = {};
  bool _invite = false;
  bool _sending = false;
  String? _status;
  int _refreshKey = 0;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _retry() {
    if (mounted) setState(() => _refreshKey++);
  }

  Future<void> _send() async {
    if (_selected.isEmpty) return;

    setState(() {
      _sending = true;
      _status = null;
    });
    try {
      final total = _selected.length;
      final sent = await ActivityService.shareWithFriends(
        widget.movie,
        friendUids: _selected.toList(),
        kind: _invite ? 'watch_together' : 'movie',
        note: _note.text,
      );
      if (!mounted) return;

      setState(() {
        _sending = false;
        _status = sent == total
            ? sent == 1
                ? 'Sent to 1 friend.'
                : 'Sent to $sent friends.'
            : 'Sent to $sent of $total friends. Some shares failed.';
      });
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.pop(context, sent > 0);
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _status = 'Could not send: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.movie['title'] ?? widget.movie['name'] ?? 'this movie';

    return Scaffold(
      appBar: AppBar(title: const Text('Send to friends')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose friends to send "$title" to. Nothing is posted publicly.',
                  style: FlickerText.caption,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_status != null) ...[
                  const SizedBox(height: 10),
                  Text(_status!, style: FlickerText.body),
                ],
              ],
            ),
          ),
          SwitchListTile(
            value: _invite,
            onChanged: (value) => setState(() => _invite = value),
            title: const Text('Invite to watch together'),
            subtitle: const Text('They will see it as a watch-night invite.'),
            activeThumbColor: FlickerColors.primaryBright,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Add a note (optional)'),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<Friendship>>(
              key: ValueKey('share-friends-$_refreshKey'),
              stream: FriendService.friends(),
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
                final friends = snapshot.data ?? [];
                if (friends.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.people_outline,
                    title: 'No friends yet',
                    message: 'Add friends before sending movies.',
                  );
                }

                final friendUids = friends
                    .map((friendship) => friendship.otherUser(uid))
                    .where((friendUid) => friendUid.isNotEmpty)
                    .toList();
                if (friendUids.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.people_outline,
                    title: 'No friends yet',
                    message: 'Add friends before sending movies.',
                  );
                }

                return ListView(
                  children: friendUids.map((friendUid) {
                    return FutureBuilder<UserProfile?>(
                      future: UserService.profile(friendUid),
                      builder: (context, profileSnapshot) {
                        final profile = profileSnapshot.data;
                        final selected = _selected.contains(friendUid);
                        return CheckboxListTile(
                          value: selected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selected.add(friendUid);
                              } else {
                                _selected.remove(friendUid);
                              }
                            });
                          },
                          secondary: InitialsAvatar(
                            name: profile?.label ?? friendUid,
                            imageUrl: profile?.avatarUrl,
                            radius: 20,
                          ),
                          title: Text(profile?.label ?? 'Friend'),
                          subtitle: Text('@${profile?.username ?? 'unknown'}'),
                          activeColor: FlickerColors.primaryBright,
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _sending || _selected.isEmpty ? null : _send,
                child: Text(
                  _sending
                      ? 'Sending...'
                      : _invite
                      ? 'Send invites (${_selected.length})'
                      : 'Send (${_selected.length})',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
