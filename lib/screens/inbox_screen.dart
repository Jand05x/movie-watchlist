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

class InboxScreen extends StatefulWidget {
  final bool embedded;

  const InboxScreen({super.key, this.embedded = false});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  int _tab = 0;
  int _refreshKey = 0;

  void _retry() {
    if (mounted) setState(() => _refreshKey++);
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Received'),
                  selected: _tab == 0,
                  onSelected: (_) => setState(() => _tab = 0),
                  selectedColor: FlickerColors.primary,
                  labelStyle: FlickerText.caption.copyWith(
                    color: _tab == 0 ? FlickerColors.cream : FlickerColors.muted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Sent'),
                  selected: _tab == 1,
                  onSelected: (_) => setState(() => _tab = 1),
                  selectedColor: FlickerColors.primary,
                  labelStyle: FlickerText.caption.copyWith(
                    color: _tab == 1 ? FlickerColors.cream : FlickerColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _list(
            _tab == 0 ? ActivityService.inbox() : ActivityService.sent(),
            received: _tab == 0,
          ),
        ),
      ],
    );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: body,
    );
  }

  Widget _list(Stream<List<ActivityEntry>> stream, {required bool received}) {
    return StreamBuilder<List<ActivityEntry>>(
      key: ValueKey('inbox-$_tab-$_refreshKey'),
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoading(message: 'Loading messages...');
        }
        if (snapshot.hasError) {
          return AppErrorState(
            message: 'Could not load messages.\n${snapshot.error}',
            onRetry: _retry,
          );
        }

        final entries = snapshot.data ?? [];
        if (entries.isEmpty) {
          return AppEmptyState(
            icon: received ? Icons.inbox_outlined : Icons.outbox_outlined,
            title: received ? 'No new sends' : 'Nothing sent yet',
            message: received
                ? 'Friend recommendations and watch invites land here.'
                : 'Send a movie from any title page.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          itemCount: entries.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) =>
              _card(context, entries[index], received),
        );
      },
    );
  }

  Widget _card(BuildContext context, ActivityEntry entry, bool received) {
    final uid = received ? entry.senderUid : entry.recipientUid;
    final note = entry.note.isEmpty ? null : '“${entry.note}”';
    final status = _statusLabel(entry.status);

    return Card(
      color: FlickerColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FutureBuilder<UserProfile?>(
                  future: UserService.profile(uid),
                  builder: (context, snapshot) {
                    return InitialsAvatar(
                      name: snapshot.data?.label ?? 'Friend',
                      imageUrl: snapshot.data?.avatarUrl,
                      radius: 18,
                    );
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FutureBuilder<UserProfile?>(
                    future: UserService.profile(uid),
                    builder: (context, snapshot) {
                      return Text(
                        received
                            ? '${snapshot.data?.label ?? 'A friend'} sent this'
                            : 'Sent to ${snapshot.data?.label ?? 'a friend'}',
                        style: FlickerText.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ),
                Chip(
                  label: Text(status),
                  backgroundColor: FlickerColors.canvas,
                  labelStyle: FlickerText.label,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: entry.movieId == 0 ? null : () => _openMovie(context, entry),
              child: Row(
                children: [
                  PosterImage(
                    path: entry.posterPath,
                    width: 48,
                    height: 70,
                    radius: 7,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          style: FlickerText.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text('Tap to view', style: FlickerText.caption),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (entry.isInvite) ...[
              const SizedBox(height: 8),
              Text('Watch-night invite', style: FlickerText.caption),
            ],
            if (note != null) ...[
              const SizedBox(height: 8),
              Text(
                note,
                style: FlickerText.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (entry.status == 'declined') ...[
              const SizedBox(height: 8),
              Text(
                received ? 'You passed on this.' : 'They passed on this.',
                style: FlickerText.caption,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'Accepted';
      case 'declined':
        return 'Declined';
      default:
        return 'New';
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
}
