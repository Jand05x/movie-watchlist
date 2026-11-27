import 'package:flutter/material.dart';

import '../models/recap.dart';
import '../services/recap_service.dart';

class RecapScreen extends StatelessWidget {
  const RecapScreen({super.key});

  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Your Recap',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<RecapStats>(
        future: RecapService.currentMonth(),
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
                  'Could not build your recap.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            );
          }

          final stats = snapshot.data;
          if (stats == null) {
            return const Center(
              child: Text(
                'No recap data yet.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }
          return _content(stats);
        },
      ),
    );
  }

  Widget _content(RecapStats stats) {
    final month = _months[stats.monthStart.month - 1];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          '$month ${stats.monthStart.year}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your month in movies',
          style: TextStyle(color: Colors.white60, fontSize: 14),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: _statCard(
                icon: Icons.movie_outlined,
                value: '${stats.watchedCount}',
                label: 'Movies watched',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                icon: Icons.category_outlined,
                value: stats.topGenre ?? '—',
                label: 'Top genre',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statCard(
                icon: Icons.star_outline,
                value: stats.highestRating?.toStringAsFixed(0) ?? '—',
                label: stats.highestRatedTitle ?? 'Highest rated',
                smallValue: stats.highestRatedTitle != null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                icon: Icons.local_fire_department_outlined,
                value: '${stats.longestStreak}',
                label: 'Best day streak',
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        const Text(
          'Badges',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.25,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: stats.badges.map(_badgeCard).toList(),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
    bool smallValue = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFE50914), size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: smallValue ? 16 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _badgeCard(RecapBadge badge) {
    final color = badge.unlocked ? Colors.amber : Colors.white24;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: badge.unlocked ? const Color(0xFF332A17) : const Color(0xFF202020),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(140)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            badge.unlocked ? Icons.emoji_events : Icons.lock_outline,
            color: color,
            size: 26,
          ),
          const SizedBox(height: 10),
          Text(
            badge.title,
            style: TextStyle(
              color: badge.unlocked ? Colors.white : Colors.white60,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            badge.description,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
