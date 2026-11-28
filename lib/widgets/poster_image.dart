import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/tmdb_service.dart';
import '../theme/brand.dart';

class PosterImage extends StatelessWidget {
  final String? path;
  final double width;
  final double height;
  final double radius;
  final String? heroTag;
  final BoxFit fit;

  const PosterImage({
    super.key,
    this.path,
    required this.width,
    required this.height,
    this.radius = 8,
    this.heroTag,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final child = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: width, height: height, child: _image()),
    );

    if (heroTag == null) return child;
    return Hero(tag: heroTag!, child: child);
  }

  Widget _image() {
    if (path == null || path!.isEmpty) return _placeholder();

    return CachedNetworkImage(
      imageUrl: '${TmdbService.imageBase}$path',
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => _placeholder(),
      errorWidget: (context, url, error) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FlickerColors.surfaceRaised, FlickerColors.canvas],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie_outlined, color: FlickerColors.muted, size: 28),
            const SizedBox(height: 6),
            const Text(
              'NO ARTWORK',
              style: FlickerText.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
