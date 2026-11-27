import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/brand.dart';

class InitialsAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final String? imageUrl;

  const InitialsAvatar({
    super.key,
    required this.name,
    this.radius = 22,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return CircleAvatar(
      radius: radius,
      backgroundColor: FlickerColors.roseWash,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: imageUrl!,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                placeholder: (context, url) => Text(initial, style: _style),
                errorWidget: (context, url, error) => Text(initial, style: _style),
              ),
            )
          : Text(initial, style: _style),
    );
  }

  TextStyle get _style => const TextStyle(
        color: FlickerColors.primaryBright,
        fontWeight: FontWeight.bold,
      );
}
