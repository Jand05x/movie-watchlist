import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/friendship.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/compatibility_service.dart';
import '../services/friend_service.dart';
import '../services/taste_service.dart';
import '../services/user_service.dart';
import '../theme/brand.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_loading.dart';
import '../widgets/initials_avatar.dart';
import 'notifications_screen.dart';
import 'recap_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? friendUid;

  const ProfileScreen({super.key, this.friendUid});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _refreshKey = 0;

  void _refresh() {
    if (!mounted) return;
    setState(() => _refreshKey++);
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.friendUid ?? FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.friendUid == null ? 'Your Profile' : 'Friend Profile'),
        actions: [
          if (widget.friendUid == null)
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: _refresh,
            ),
          if (widget.friendUid == null)
            IconButton(
              tooltip: 'Notifications',
              icon: const Icon(Icons.notifications_none),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
              },
            ),
        ],
      ),
      body: FutureBuilder<UserProfile?>(
        key: ValueKey('profile-$_refreshKey'),
        future: UserService.profile(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoading(message: 'Loading profile...');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: 'Could not load profile.\n${snapshot.error}',
              onRetry: _refresh,
            );
          }

          final profile = snapshot.data;
          if (profile == null) {
            return AppErrorState(
              message: 'Profile not found.',
              onRetry: _refresh,
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _header(context, profile),
              const SizedBox(height: 20),
              if (widget.friendUid == null) ...[
                _tasteStats(uid),
                const SizedBox(height: 8),
                _sectionTitle(
                  'Your taste match',
                  'Score = shared genres (60%) + movies watched in common (40%). '
                  'Both people need at least 3 ratings.',
                ),
                _compatibilityList(context),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RecapScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.bar_chart),
                  label: const Text('View monthly recap'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FlickerColors.primaryBright,
                    side: const BorderSide(color: FlickerColors.primaryBright),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.read<AuthService>().signOut(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Log out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FlickerColors.muted,
                    side: const BorderSide(color: FlickerColors.muted),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ] else ...[
                _sectionTitle(
                  'Taste match with ${profile.label}',
                  'Based on genre overlap and watched movies in common.',
                ),
                _friendCompatibility(uid),
                _tasteStats(uid),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: FlickerText.section),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: FlickerText.caption,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, UserProfile profile) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InitialsAvatar(
          name: profile.label,
          imageUrl: profile.avatarUrl,
          radius: 38,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.label,
                style: FlickerText.display.copyWith(fontSize: 23),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text('@${profile.username}', style: FlickerText.caption),
              if (profile.bio.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(profile.bio, style: FlickerText.body),
              ],
            ],
          ),
        ),
        if (widget.friendUid == null)
          IconButton(
            tooltip: 'Edit profile',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editProfile(context, profile),
          ),
      ],
    );
  }

  Future<void> _editProfile(BuildContext context, UserProfile profile) async {
    final displayName = TextEditingController(text: profile.displayName);
    final bio = TextEditingController(text: profile.bio);
    final avatarUrl = TextEditingController(text: profile.avatarUrl);
    bool discoverable = profile.discoverable;
    bool tasteShared = profile.tasteShared;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit profile'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: displayName,
                      decoration: const InputDecoration(labelText: 'Display name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: bio,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Bio'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: avatarUrl,
                      decoration: const InputDecoration(
                        labelText: 'Avatar image URL',
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: discoverable,
                      onChanged: (value) =>
                          setDialogState(() => discoverable = value),
                      title: const Text('Discoverable by friends'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: tasteShared,
                      onChanged: (value) =>
                          setDialogState(() => tasteShared = value),
                      title: const Text('Share taste for compatibility'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) return;

    try {
      await UserService.updateProfile(
        displayName: displayName.text,
        bio: bio.text,
        avatarUrl: avatarUrl.text,
        discoverable: discoverable,
        tasteShared: tasteShared,
      );
      _refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    }
  }

  Widget _tasteStats(String uid) {
    return FutureBuilder<Map<String, dynamic>?>(
      key: ValueKey('taste-$_refreshKey-$uid'),
      future: TasteService.forUser(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoading(message: 'Loading taste profile...');
        }
        if (snapshot.hasError) {
          return AppErrorState(
            message: 'Could not load taste profile.\n${snapshot.error}',
            onRetry: _refresh,
          );
        }

        final taste = snapshot.data;
        if (taste == null) {
          return const AppEmptyState(
            icon: Icons.movie_outlined,
            title: 'No taste profile yet',
            message: 'Rate at least 3 movies to build a taste profile.',
          );
        }

        final watched = taste['watchedCount'] ?? 0;
        final rated = taste['ratedCount'] ?? 0;
        final genres = taste['genreScores'];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _stat('$watched', 'watched')),
                const SizedBox(width: 12),
                Expanded(child: _stat('$rated', 'rated')),
              ],
            ),
            if (genres is List && genres.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: genres.whereType<Map>().map((genre) {
                  return Chip(
                    label: Text('${genre['name']}'),
                    backgroundColor: FlickerColors.surface,
                    labelStyle: FlickerText.caption,
                  );
                }).toList(),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _stat(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlickerColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: FlickerText.display),
          Text(label, style: FlickerText.caption),
        ],
      ),
    );
  }

  Widget _compatibilityList(BuildContext context) {
    return StreamBuilder<List<Friendship>>(
      key: ValueKey('friends-$_refreshKey'),
      stream: FriendService.friends(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoading(message: 'Finding friends...');
        }
        if (snapshot.hasError) {
          return AppErrorState(
            message: 'Could not load friends.\n${snapshot.error}',
            onRetry: _refresh,
          );
        }

        final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final friends = (snapshot.data ?? [])
            .map((friendship) => friendship.otherUser(currentUid))
            .where((uid) => uid.isNotEmpty)
            .toList();
        if (friends.isEmpty) {
          return const AppEmptyState(
            icon: Icons.people_outline,
            title: 'No friends to compare yet',
            message: 'Add a friend from the Friends tab to see your taste match.',
          );
        }

        return Column(
          children: friends.map((friendUid) {
            return _friendMatchTile(context, friendUid);
          }).toList(),
        );
      },
    );
  }

  Widget _friendMatchTile(BuildContext context, String friendUid) {
    return FutureBuilder<UserProfile?>(
      key: ValueKey('friend-profile-$friendUid-$_refreshKey'),
      future: UserService.profile(friendUid),
      builder: (context, profileSnapshot) {
        final profile = profileSnapshot.data;
        final name = profile?.label ?? 'Friend';
        return Card(
          color: FlickerColors.surface,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: InitialsAvatar(
              name: name,
              imageUrl: profile?.avatarUrl,
              radius: 20,
            ),
            title: Text(
              name,
              style: FlickerText.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: FutureBuilder<CompatibilityResult>(
              key: ValueKey('match-$friendUid-$_refreshKey'),
              future: CompatibilityService.scoreWith(friendUid),
              builder: (context, scoreSnapshot) {
                if (scoreSnapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('Comparing taste...'),
                  );
                }
                if (scoreSnapshot.hasError) {
                  return const Text('Could not compare taste.');
                }
                final result = scoreSnapshot.data;
                if (result == null) return const Text('No match data.');

                final headline = result.enoughData
                    ? '${result.score}% · ${result.band}'
                    : result.band;
                final detail = result.sharedGenres.isNotEmpty
                    ? 'Shared: ${result.sharedGenres.join(', ')}'
                    : result.explanation;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(headline, style: FlickerText.caption),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: FlickerText.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              },
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(friendUid: friendUid),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _friendCompatibility(String uid) {
    return FutureBuilder<CompatibilityResult>(
      key: ValueKey('friend-match-$uid-$_refreshKey'),
      future: CompatibilityService.scoreWith(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoading(message: 'Comparing taste...');
        }
        if (snapshot.hasError) {
          return AppErrorState(
            message: 'Could not compare taste.\n${snapshot.error}',
            onRetry: _refresh,
          );
        }
        final result = snapshot.data;
        if (result == null) {
          return const AppEmptyState(
            icon: Icons.favorite_border,
            title: 'No match available',
            message: 'Taste information is not available yet.',
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: FlickerColors.roseWash,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.enoughData ? '${result.score}% match' : result.band,
                style: FlickerText.display,
              ),
              const SizedBox(height: 6),
              Text(result.explanation, style: FlickerText.caption),
              if (result.sharedGenres.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Shared genres', style: FlickerText.label),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: result.sharedGenres
                      .map((genre) => Chip(
                            label: Text(genre),
                            backgroundColor: FlickerColors.surface,
                            labelStyle: FlickerText.caption,
                          ))
                      .toList(),
                ),
              ],
              if (result.sharedMovieTitles.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Movies you both watched',
                  style: FlickerText.label,
                ),
                const SizedBox(height: 4),
                Text(
                  result.sharedMovieTitles.join(', '),
                  style: FlickerText.body,
                ),
              ],
              if (result.suggestedGenres.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'They also like: ${result.suggestedGenres.join(', ')}',
                  style: FlickerText.body,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
