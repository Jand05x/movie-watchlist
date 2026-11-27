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

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabs,
          indicatorColor: FlickerColors.primaryBright,
          labelColor: FlickerColors.cream,
          unselectedLabelColor: FlickerColors.muted,
          tabs: const [
            Tab(text: 'Received'),
            Tab(text: 'Sent'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _list(ActivityService.inbox(), received: true),
              _list(ActivityService.sent(), received: false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _list(Stream<List<ActivityEntry>> stream, {required bool received}) {
    return StreamBuilder<List<ActivityEntry>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoading();
        }
        if (snapshot.hasError) {
          return AppErrorState(message: '${snapshot.error}');
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
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(entry.title, style: FlickerText.title),
            if (entry.isInvite) ...[
              const SizedBox(height: 4),
              Text('Watch-night invite', style: FlickerText.caption),
            ],
            if (note != null) ...[
              const SizedBox(height: 8),
              Text(note, style: FlickerText.body),
            ],
            if (!received) ...[
              const SizedBox(height: 8),
              Text('Status: ${_status(entry)}', style: FlickerText.caption),
            ],
            if (received) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FlickerColors.muted,
                      side: const BorderSide(color: FlickerColors.muted),
                    ),
                    onPressed: () => _respond(context, entry, false),
                    child: const Text('Not for me'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _respond(context, entry, true),
                    child: Text(
                      entry.isInvite ? 'Count me in' : 'Thanks!',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _status(ActivityEntry entry) => entry.status;

  Future<void> _respond(
    BuildContext context,
    ActivityEntry entry,
    bool accepted,
  ) async {
    try {
      await ActivityService.respond(entry.id, accepted);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accepted
                ? 'Added to your feed.'
                : 'We let your friend know.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not respond: $e')),
      );
    }
  }
}
