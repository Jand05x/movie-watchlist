import 'package:flutter/material.dart';

import '../models/recap.dart';
import '../models/review.dart';
import '../services/recap_service.dart';
import '../theme/brand.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_loading.dart';
import '../widgets/movie_card.dart';

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
      backgroundColor: FlickerColors.canvas,
      appBar: AppBar(title: const Text('Your Recap')),
      body: FutureBuilder<RecapStats>(
        future: RecapService.currentMonth(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoading(message: 'Building your recap...');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: 'Could not build your recap.\n${snapshot.error}',
            );
          }

          final stats = snapshot.data;
          if (stats == null) {
            return const Center(
              child: Text(
                'No recap data yet.',
                style: FlickerText.body,
              ),
            );
          }
          return _content(context, stats);
        },
      ),
    );
  }

  Widget _content(BuildContext context, RecapStats stats) {
    final month = _months[stats.monthStart.month - 1];
    final average = stats.averageRating == null
        ? '—'
        : stats.averageRating!.toStringAsFixed(1);
    final unlocked = stats.badges.where((badge) => badge.unlocked).toList();
    final locked = stats.badges.where((badge) => !badge.unlocked).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text('$month ${stats.monthStart.year}', style: FlickerText.display),
        const SizedBox(height: 4),
        const Text('Your month in movies', style: FlickerText.caption),
        const SizedBox(height: 22),
        _sectionTitle('The big picture'),
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
                smallValue: stats.topGenre != null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statCard(
                icon: Icons.calendar_month_outlined,
                value: '${stats.distinctDays}',
                label: 'Movie nights',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                icon: Icons.local_fire_department_outlined,
                value: '${stats.longestStreak}',
                label: 'Best streak',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _sectionTitle('By the numbers'),
        Row(
          children: [
            Expanded(
              child: _statCard(
                icon: Icons.star_border_rounded,
                value: average,
                label: 'Average rating',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                icon: Icons.star_rate_outlined,
                value: '${stats.ratedCount}',
                label: 'Movies rated',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statCard(
                icon: Icons.category_outlined,
                value: '${stats.distinctGenreCount}',
                label: 'Genres explored',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                icon: Icons.note_outlined,
                value: '${stats.noteCount}',
                label: 'Notes written',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _statCard(
          icon: Icons.event_available_outlined,
          value: stats.mostActiveDayLabel ?? '—',
          label: stats.mostActiveDayLabel == null
              ? 'Busiest movie day'
              : '${stats.mostActiveDayCount} movies on your busiest day',
          smallValue: stats.mostActiveDayLabel != null,
        ),
        if (stats.highestRatedMovie != null) ...[
          const SizedBox(height: 24),
          _sectionTitle('Your standout'),
          _highlightCard(stats.highestRatedMovie!),
        ],
        const SizedBox(height: 24),
        _sectionTitle('Top genres'),
        if (stats.topGenres.isEmpty)
          const Text('No genres yet.', style: FlickerText.body)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: stats.topGenres
                .map(
                  (genre) => _genreChip(genre.key, genre.value),
                )
                .toList(),
          ),
        if (stats.watchedMovies.isNotEmpty) ...[
          const SizedBox(height: 24),
          _sectionTitle('Recently watched'),
          SizedBox(
            height: MediaQuery.textScalerOf(context).scale(216),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: stats.watchedMovies.take(10).length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return _movieCard(stats.watchedMovies[index]);
              },
            ),
          ),
        ],
        const SizedBox(height: 24),
        _sectionTitle('Little wins'),
        const Text(
          'Milestones from this month.',
          style: FlickerText.caption,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: unlocked.map(_badgeChip).toList(),
        ),
        if (locked.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Text('Still to unlock', style: FlickerText.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: locked.map(_badgeChip).toList(),
          ),
        ],
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: FlickerText.section),
    );
  }

  Widget _genreChip(String name, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: FlickerColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FlickerColors.divider),
      ),
      child: Text(
        '$name · $count',
        style: FlickerText.body.copyWith(fontSize: 12),
      ),
    );
  }

  Widget _highlightCard(Review movie) {
    return Card(
      color: FlickerColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _movieCard(movie, width: 92),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Highest rated', style: FlickerText.caption),
                  const SizedBox(height: 4),
                  Text(
                    movie.title,
                    style: FlickerText.body.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${movie.rating}/5 stars',
                    style: FlickerText.label.copyWith(
                      color: FlickerColors.amber,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _movieCard(Review movie, {double width = 108}) {
    return MovieCard(
      movie: {
        'id': movie.tmdbId,
        'title': movie.title,
        'poster_path': movie.posterPath,
        'media_type': movie.mediaType,
        'vote_average': movie.rating ?? 0,
      },
      width: width,
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
        color: FlickerColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FlickerColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: FlickerColors.primaryBright, size: 22),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: FlickerText.display.copyWith(
              fontSize: smallValue ? 17 : 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: FlickerText.caption,
          ),
        ],
      ),
    );
  }

  Widget _badgeChip(RecapBadge badge) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: badge.unlocked ? FlickerColors.roseWash : FlickerColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: badge.unlocked ? FlickerColors.primaryBright : FlickerColors.divider,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            badge.unlocked ? Icons.check_circle_outline : Icons.lock_outline,
            size: 16,
            color: badge.unlocked ? FlickerColors.amber : FlickerColors.muted,
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  badge.title,
                  style: FlickerText.body.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  badge.description,
                  style: FlickerText.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
