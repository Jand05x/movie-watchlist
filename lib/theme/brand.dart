import 'package:flutter/material.dart';

class FlickerColors {
  static const Color canvas = Color(0xFF14100F);
  static const Color surface = Color(0xFF241B1B);
  static const Color surfaceRaised = Color(0xFF302323);
  static const Color primary = Color(0xFFB23A48);
  static const Color primaryBright = Color(0xFFD95766);
  static const Color cream = Color(0xFFF6EFE7);
  static const Color muted = Color(0xFFA79A94);
  static const Color amber = Color(0xFFE8B45A);
  static const Color success = Color(0xFF79B58B);
  static const Color danger = Color(0xFFD95766);
  static const Color divider = Color(0x2BF6EFE7);
  static const Color roseWash = Color(0xFF3A2229);
}

class FlickerText {
  static const TextStyle display = TextStyle(
    color: FlickerColors.cream,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
  );
  static const TextStyle title = TextStyle(
    color: FlickerColors.cream,
    fontSize: 21,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle section = TextStyle(
    color: FlickerColors.cream,
    fontSize: 17,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle body = TextStyle(
    color: FlickerColors.cream,
    fontSize: 14,
    height: 1.5,
  );
  static const TextStyle caption = TextStyle(
    color: FlickerColors.muted,
    fontSize: 12,
  );
  static const TextStyle label = TextStyle(
    color: FlickerColors.muted,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.7,
  );
}

class FlickerStrings {
  static const String appName = 'Flicker';
  static const String tagline = 'Movies bring us together.';
}
