import 'package:flutter/material.dart';

import '../theme/brand.dart';

class AppLoading extends StatelessWidget {
  final String? message;

  const AppLoading({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: FlickerColors.primaryBright),
          if (message != null) ...[
            const SizedBox(height: 14),
            Text(message!, style: FlickerText.caption),
          ],
        ],
      ),
    );
  }
}
