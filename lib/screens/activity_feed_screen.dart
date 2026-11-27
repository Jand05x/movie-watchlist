import 'package:flutter/material.dart';

import '../models/activity_entry.dart';
import '../models/user_profile.dart';
import '../services/activity_service.dart';
import '../services/user_service.dart';
import '../theme/brand.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_loading.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/poster_image.dart';
import 'movie_details_screen.dart';

class ActivityFeedScreen extends StatefulWidget {
  final bool embedded;
  final int? limit;

  const ActivityFeedScreen({super.key, this.embedded = false, this.limit});

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> {
  int _refreshKey = 0;

  void _retry() {
    if (mounted) setState(() => _refreshKey++);
  }

  @override
  Widget build(BuildContext context) {
    final body = StreamBuilder<List<ActivityEntry>>(
      key: ValueKey('feed-$_refreshKey'),
      stream: ActivityService.feed(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoading(message: 'Loading your circle...');
        }
        if (snapshot.hasError) {
          return AppErrorState(
            message: 'Could not load activity.\n${snapshot.error}',
            onRetry: _retry,
          );
        }

        var entries = snapshot.data ?? [];
        if (widget.limit != null && entries.length > widget.limit!) {
          entries = entries.sublist(0, widget.limit!);
        }

        if (entries.isEmpty) {
          return const AppEmptyState(
            icon: Icons.feed_outlined,
            title: 'Nothing from your circle yet',
            message: 'When friends send you a movie, it will show up here.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: entries.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _entryCard(context, entries[index]),
        );
      },
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(title: const Text('Your Circle')),
      body: body,
    );
  }

  Widget _entryCard(BuildContext context, ActivityEntry entry) {
    return Card(
      color: FlickerColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<UserProfile?>(
                  future: UserService.profile(entry.senderUid),
                  builder: (context, snapshot) {
                    final name = snapshot.data?.label ?? 'A friend';
                    return InitialsAvatar(
                      name: name,
                      imageUrl: snapshot.data?.avatarUrl,
                      radius: 20,
                    );
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<UserProfile?>(
                        future: UserService.profile(entry.senderUid),
                        builder: (context, snapshot) {
                          return Text.rich(
                            TextSpan(
                              style: FlickerText.caption,
                              children: [
                                TextSpan(
                                  text: snapshot.data?.label ?? 'A friend',
                                  style: const TextStyle(
                                    color: FlickerColors.cream,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(
                                  text: entry.isInvite
                                      ? ' invited you to watch'
                                      : ' sent you a movie',
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                      const SizedBox(height: 2),
                      Text(_timeAgo(entry.timestamp), style: FlickerText.label),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _openMovie(context, entry),
              child: Row(
                children: [
                  PosterImage(
                    path: entry.posterPath,
                    width: 52,
                    height: 76,
                    radius: 7,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          style: FlickerText.body.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (entry.rating != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: FlickerColors.amber,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    entry.rating!.toStringAsFixed(0),
                                    style: FlickerText.caption,
                                  ),
                                ],
                              ),
                            Text('Tap to view', style: FlickerText.caption),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (entry.note.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '“${entry.note}”',
                style: FlickerText.caption,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (entry.reactions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                entry.reactions.values.join('  '),
                style: const TextStyle(fontSize: 18),
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                children: ['❤️', '🔥', '😮'].map((emoji) {
                  return IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'React $emoji',
                    icon: Text(emoji, style: const TextStyle(fontSize: 16)),
                    onPressed: () => _react(entry.id, emoji),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _react(String shareId, String emoji) async {
    try {
      await ActivityService.react(shareId, emoji);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not react: $e')),
      );
    }
  }

  void _openMovie(BuildContext context, ActivityEntry entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MovieDetailsScreen(
          movie: {
            'id': entry.movieId,
            'title': entry.title,
            'poster_path': entry.posterPath,
            'media_type': entry.mediaType,
          },
        ),
      ),
    );
  }

  String _timeAgo(DateTime? timestamp) {
    if (timestamp == null) return 'just now';
    final minutes = DateTime.now().difference(timestamp).inMinutes;
    if (minutes < 1) return 'just now';
    if (minutes < 60) return '$minutes min ago';
    final hours = minutes ~/ 60;
    if (hours < 24) return '$hours h ago';
    final days = hours ~/ 24;
    if (days < 30) return '$days d ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}
