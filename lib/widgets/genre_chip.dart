import 'package:flutter/material.dart';

class GenreChip extends StatelessWidget {
  final String label;
  final int? genreId;

  const GenreChip({super.key, required this.label, this.genreId});

  static const Map<int, Color> palette = {
    28: Color(0xFFE5484D),
    12: Color(0xFFF76808),
    16: Color(0xFF30A46C),
    18: Color(0xFF0090FF),
    35: Color(0xFF8E4EC6),
    10751: Color(0xFFE2B53B),
    14: Color(0xFF00A8B5),
    36: Color(0xFFCC4E8B),
    27: Color(0xFF8C6B3F),
    10402: Color(0xFF6E56CF),
    9648: Color(0xFF3E63DD),
    878: Color(0xFF12A594),
    10749: Color(0xFFF25C81),
    53: Color(0xFF4C6B8A),
    10770: Color(0xFF7C7CFF),
  };

  @override
  Widget build(BuildContext context) {
    final seed = (genreId ?? label.hashCode).abs();
    final base = palette[genreId] ??
        Color.fromARGB(
          255,
          90 + seed % 130,
          90 + (seed ~/ 7) % 130,
          110 + (seed ~/ 13) % 120,
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: base.withAlpha(46),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: base.withAlpha(160)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
