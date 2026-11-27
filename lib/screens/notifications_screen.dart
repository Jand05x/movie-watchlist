import 'package:flutter/material.dart';

import '../services/activity_service.dart';
import '../services/notification_service.dart';
import '../theme/brand.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_loading.dart';
import 'friends_screen.dart';
import 'inbox_screen.dart';
import 'movie_details_screen.dart';
import 'profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _refreshKey = 0;

  void _retry() {
    if (mounted) setState(() => _refreshKey++);
  }

  Future<void> _markAllRead() async {
    try {
      await NotificationService.markAllRead();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not mark all as read: $e')),
      );
    }
  }

  Future<void> _open(Map<String, dynamic> item) async {
    final id = item['id'] as String?;
    if (id != null) {
      try {
        await NotificationService.markRead(id);
      } catch (_) {}
    }
    if (!mounted) return;

    final type = item['type'] as String?;
    if (type == 'friend_request' ||
        type == 'friend_accepted' ||
        type == 'friend_declined') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FriendsScreen()),
      );
      return;
    }

    final shareId = item['shareId'] as String?;
    if (shareId != null && shareId.isNotEmpty) {
      try {
        final share = await ActivityService.shareById(shareId);
        if (!mounted) return;
        if (share != null && share.movieId != 0) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MovieDetailsScreen(
                movie: {
                  'id': share.movieId,
                  'title': share.title,
                  'poster_path': share.posterPath,
                  'media_type': share.mediaType,
                },
              ),
            ),
          );
          return;
        }
      } catch (_) {}
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InboxScreen()),
        );
      }
      return;
    }

    final actorUid = item['actorUid'] as String?;
    if (actorUid != null && actorUid.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileScreen(friendUid: actorUid),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Mark all as read',
            icon: const Icon(Icons.done_all),
            onPressed: _markAllRead,
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        key: ValueKey('notifications-$_refreshKey'),
        stream: NotificationService.forMe(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoading(message: 'Loading notifications...');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: 'Could not load notifications.\n${snapshot.error}',
              onRetry: _retry,
            );
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const AppEmptyState(
              icon: Icons.notifications_none,
              title: 'All quiet',
              message: 'Friend activity and replies will appear here.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              final read = item['read'] == true;
              final isInvite = item['type'] == 'watch_invite';
              return Card(
                color: read ? FlickerColors.surface : FlickerColors.roseWash,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  leading: Icon(
                    isInvite
                        ? Icons.local_fire_department_outlined
                        : item['type'] == 'friend_request'
                        ? Icons.person_add_alt_1_outlined
                        : Icons.notifications_none,
                    color: FlickerColors.primaryBright,
                  ),
                  title: Text(
                    (item['title'] as String?) ?? 'Update',
                    style: FlickerText.body.copyWith(
                      fontWeight: read ? FontWeight.normal : FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    (item['body'] as String?) ?? '',
                    style: FlickerText.caption,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _open(item),
                  trailing: read
                      ? const Icon(
                          Icons.chevron_right,
                          color: FlickerColors.muted,
                        )
                      : IconButton(
                          tooltip: 'Mark as read',
                          icon: const Icon(Icons.check),
                          onPressed: () => NotificationService.markRead(
                            item['id'] as String,
                          ),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
