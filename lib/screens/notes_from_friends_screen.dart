import 'package:flutter/material.dart';

import '../models/activity_entry.dart';
import '../models/user_profile.dart';
import '../services/activity_service.dart';
import '../services/user_service.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_loading.dart';
import '../widgets/friend_note_card.dart';
import 'movie_details_screen.dart';

class NotesFromFriendsScreen extends StatefulWidget {
  final bool embedded;

  const NotesFromFriendsScreen({super.key, this.embedded = false});

  @override
  State<NotesFromFriendsScreen> createState() => _NotesFromFriendsScreenState();
}

class _NotesFromFriendsScreenState extends State<NotesFromFriendsScreen> {
  int _refreshKey = 0;

  void _retry() {
    if (mounted) setState(() => _refreshKey++);
  }

  @override
  Widget build(BuildContext context) {
    final body = StreamBuilder<List<ActivityEntry>>(
      key: ValueKey('friend-notes-$_refreshKey'),
      stream: ActivityService.notesFromFriends(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoading(message: 'Loading notes...');
        }
        if (snapshot.hasError) {
          return AppErrorState(
            message: 'Could not load notes.\n${snapshot.error}',
            onRetry: _retry,
          );
        }

        final notes = snapshot.data ?? const <ActivityEntry>[];
        if (notes.isEmpty) {
          return const AppEmptyState(
            icon: Icons.note_alt_outlined,
            title: 'No notes from friends',
            message: 'Notes friends add when they send you a movie appear here.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          itemCount: notes.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _card(context, notes[index]),
        );
      },
    );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Notes from friends')),
      body: body,
    );
  }

  Widget _card(BuildContext context, ActivityEntry entry) {
    return FutureBuilder<UserProfile?>(
      future: UserService.profile(entry.senderUid),
      builder: (context, snapshot) {
        return FriendNoteCard(
          entry: entry,
          senderName: snapshot.data?.label ?? 'A friend',
          avatarUrl: snapshot.data?.avatarUrl,
          onOpen: () => _openMovie(context, entry),
        );
      },
    );
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
