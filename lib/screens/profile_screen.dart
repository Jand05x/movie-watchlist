import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/compatibility_service.dart';
import '../services/friend_service.dart';
import '../services/taste_service.dart';
import '../services/user_service.dart';
import '../theme/brand.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_loading.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/section_header.dart';
import 'notifications_screen.dart';
import 'recap_screen.dart';

class ProfileScreen extends StatelessWidget {
  final String? friendUid;

  const ProfileScreen({super.key, this.friendUid});

  @override
  Widget build(BuildContext context) {
    final uid = friendUid ?? FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(friendUid == null ? 'Your Profile' : 'Friend Profile'),
        actions: [
          if (friendUid == null)
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
        future: UserService.profile(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoading(message: 'Loading profile...');
          }
          if (snapshot.hasError) {
            return AppErrorState(message: '${snapshot.error}');
          }

          final profile = snapshot.data;
          if (profile == null) {
            return const AppErrorState(message: 'Profile not found.');
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _header(context, profile),
              const SizedBox(height: 20),
              if (friendUid == null) ...[
                _tasteStats(uid),
                const SectionHeader(title: 'Your taste match'),
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
                _friendCompatibility(uid),
                _tasteStats(uid),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, UserProfile profile) {
    return Row(
      children: [
        InitialsAvatar(
          name: profile.label,
          imageUrl: profile.avatarUrl,
          radius: 38,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile.label, style: FlickerText.display.copyWith(fontSize: 23)),
              const SizedBox(height: 4),
              Text('@${profile.username}', style: FlickerText.caption),
              if (profile.bio.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(profile.bio, style: FlickerText.body),
              ],
            ],
          ),
        ),
        if (friendUid == null)
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
      future: TasteService.forUser(uid),
      builder: (context, snapshot) {
        final taste = snapshot.data;
        if (taste == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Text(
              'Rate a few movies to build your taste profile.',
              style: FlickerText.caption,
            ),
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
    return StreamBuilder(
      stream: FriendService.friends(),
      builder: (context, snapshot) {
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final friends = (snapshot.data ?? [])
            .map((friendship) => friendship.otherUser(uid))
            .toList();
        if (friends.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Add friends to see taste compatibility.',
              style: FlickerText.caption,
            ),
          );
        }

        return Column(
          children: friends.map((friendUid) {
            return FutureBuilder(
              future: UserService.profile(friendUid),
              builder: (context, profileSnapshot) {
                final name = profileSnapshot.data?.label ?? 'Friend';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: InitialsAvatar(
                    name: name,
                    imageUrl: profileSnapshot.data?.avatarUrl,
                    radius: 20,
                  ),
                  title: Text(name, style: FlickerText.body),
                  subtitle: FutureBuilder(
                    future: CompatibilityService.scoreWith(friendUid),
                    builder: (context, scoreSnapshot) {
                      final result = scoreSnapshot.data;
                      if (result == null) {
                        return const Text('Comparing taste...');
                      }
                      return Text(
                        result.enoughData
                            ? '${result.score}% · ${result.band}'
                            : result.band,
                        style: FlickerText.caption,
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
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _friendCompatibility(String uid) {
    return FutureBuilder(
      future: CompatibilityService.scoreWith(uid),
      builder: (context, snapshot) {
        final result = snapshot.data;
        if (result == null) {
          return const AppLoading(message: 'Comparing taste...');
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
              const SizedBox(height: 4),
              Text(result.band, style: FlickerText.caption),
              if (result.sharedGenres.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Shared genres: ${result.sharedGenres.join(', ')}',
                  style: FlickerText.body,
                ),
              ],
              if (result.suggestedGenres.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'They like: ${result.suggestedGenres.join(', ')}',
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
