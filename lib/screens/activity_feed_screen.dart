import 'package:flutter/material.dart';

import '../models/activity_entry.dart';
import '../models/user_profile.dart';
import '../services/activity_service.dart';
import '../services/friend_service.dart';
import '../services/user_service.dart';
import '../widgets/poster_image.dart';

class ActivityFeedScreen extends StatelessWidget {
  final bool embedded;

  const ActivityFeedScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final body = StreamBuilder<List<ActivityEntry>>(
      stream: ActivityService.feed(FriendService.acceptedFriendIds()),
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
                'Could not load activity.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        final entries = snapshot.data ?? [];
        if (entries.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.feed_outlined, size: 64, color: Color(0xFFE50914)),
                  SizedBox(height: 20),
                  Text(
                    'No friend activity yet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Movies your friends rate or mark as watched show up here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: entries.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _entryCard(entries[index]),
        );
      },
    );

    if (embedded) return body;

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        title: const Text('Activity Feed'),
      ),
      body: body,
    );
  }

  Widget _entryCard(ActivityEntry entry) {
    final verb = entry.isRating ? 'rated' : 'watched';

    return Card(
      color: const Color(0xFF252525),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PosterImage(
              path: entry.posterPath,
              width: 46,
              height: 68,
              radius: 6,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ActorName(uid: entry.userId, verb: verb),
                  const SizedBox(height: 4),
                  Text(
                    entry.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (entry.rating != null) ...[
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          entry.rating!.toStringAsFixed(0),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        _timeAgo(entry.timestamp),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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

class _ActorName extends StatelessWidget {
  final String uid;
  final String verb;

  const _ActorName({required this.uid, required this.verb});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: UserService.profile(uid),
      builder: (context, snapshot) {
        final fallback = uid.length > 6 ? uid.substring(0, 6) : uid;
        final name = snapshot.data?.label ?? 'User $fallback';
        return RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            children: [
              TextSpan(
                text: name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(text: ' $verb'),
            ],
          ),
        );
      },
    );
  }
}
