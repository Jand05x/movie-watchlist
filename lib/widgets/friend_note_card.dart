import 'package:flutter/material.dart';

import '../models/activity_entry.dart';
import '../theme/brand.dart';
import '../utils/date_format.dart';
import 'initials_avatar.dart';
import 'poster_image.dart';

class FriendNoteCard extends StatelessWidget {
  final ActivityEntry entry;
  final String senderName;
  final String? avatarUrl;
  final VoidCallback? onOpen;

  const FriendNoteCard({
    super.key,
    required this.entry,
    required this.senderName,
    this.avatarUrl,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
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
                InitialsAvatar(
                  name: senderName,
                  imageUrl: avatarUrl,
                  radius: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$senderName sent a note',
                    style: FlickerText.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatShortDate(entry.timestamp),
                  style: FlickerText.label,
                ),
              ],
            ),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: entry.movieId == 0 ? null : onOpen,
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
                        const Text('Tap to view', style: FlickerText.caption),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '“${entry.note.trim()}”',
              style: FlickerText.body,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
