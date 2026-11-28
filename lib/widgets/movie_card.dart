import 'package:flutter/material.dart';

import '../theme/brand.dart';
import 'poster_image.dart';

class MovieCard extends StatelessWidget {
  final Map<String, dynamic> movie;
  final double width;
  final VoidCallback? onTap;
  final String? heroTag;
  final String? badge;

  const MovieCard({
    super.key,
    required this.movie,
    this.width = 132,
    this.onTap,
    this.heroTag,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final title = movie['title'] ?? movie['name'] ?? 'Untitled';
    final rating = movie['vote_average'];

    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                PosterImage(
                  path: movie['poster_path'] as String?,
                  width: width,
                  height: width * 1.3,
                  radius: 10,
                  heroTag: heroTag,
                ),
                if (badge != null)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: FlickerColors.canvas.withAlpha(220),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(badge!, style: FlickerText.label),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title.toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FlickerColors.cream,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.star_rounded, color: FlickerColors.amber, size: 14),
                const SizedBox(width: 4),
                Text(
                  rating is num ? rating.toStringAsFixed(1) : '—',
                  style: FlickerText.caption,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
