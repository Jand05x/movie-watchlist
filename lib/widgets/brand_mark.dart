import 'package:flutter/material.dart';

import '../theme/brand.dart';

class BrandMark extends StatelessWidget {
  final double size;
  final bool showTagline;

  const BrandMark({super.key, this.size = 64, this.showTagline = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.3),
            gradient: const LinearGradient(
              colors: [FlickerColors.primary, FlickerColors.primaryBright],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Icon(
            Icons.theaters,
            color: FlickerColors.cream,
            size: size * 0.52,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          FlickerStrings.appName,
          style: FlickerText.display.copyWith(fontSize: size * 0.52),
        ),
        if (showTagline) ...[
          const SizedBox(height: 6),
          Text(FlickerStrings.tagline, style: FlickerText.caption),
        ],
      ],
    );
  }
}
