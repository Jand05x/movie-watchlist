import 'package:flutter/material.dart';

import '../services/tmdb_service.dart';
import '../services/watchlist_service.dart';
import '../widgets/poster_image.dart';
import 'movie_details_screen.dart';

class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});

  static const Color _background = Color(0xFF141414);
  static const Color _cardBackground = Color(0xFF252525);
  static const Color _red = Color(0xFFE50914);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        title: const Text(
          'My Watchlist',
          style: TextStyle(
            color: Colors.white,
            fontSize: 23,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: WatchlistService.watchlist(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load your watchlist.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _red));
          }

          final movies = snapshot.data ?? [];

          if (movies.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(26),
                      decoration: const BoxDecoration(
                        color: _cardBackground,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bookmark_add_outlined,
                        size: 64,
                        color: _red,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Your watchlist is empty',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Find something you love and save it here '
                      'to watch later.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.explore_outlined),
                      label: const Text('Discover Movies'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: _red),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  '${movies.length} ${movies.length == 1 ? 'title' : 'titles'} saved for later',
                  style: const TextStyle(color: Colors.white60, fontSize: 14),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: movies.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final movie = movies[index];
                    final rawId = movie['tmdb_id'];
                    final id = rawId is num ? rawId.toInt() : null;
                    final title = movie['title']?.toString() ?? 'Untitled';
                    final poster = movie['poster_path']?.toString() ?? '';

                    return Material(
                      color: _cardBackground,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: id == null
                            ? null
                            : () => _openDetails(
                                context,
                                movie,
                                id,
                              ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              PosterImage(
                                path: poster,
                                width: 64,
                                height: 96,
                                radius: 6,
                                heroTag: 'poster-${movie['media_type'] ?? 'movie'}-$id',
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove from watchlist',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 34,
                                  minHeight: 34,
                                ),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: _red,
                                  size: 21,
                                ),
                                onPressed: id == null
                                    ? null
                                    : () async {
                                        try {
                                          await WatchlistService.remove(id);
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Could not remove movie: $e',
                                                  ),
                                                ),
                                              );
                                        }
                                      },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openDetails(
    BuildContext context,
    Map<String, dynamic> movie,
    int id,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Loading details...'),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      final isTv = movie['media_type'] == 'tv';
      final details = isTv
          ? await TmdbService.getTvDetails(id)
          : await TmdbService.getMovieDetails(id);

      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      if (details == null) {
        throw StateError('No details were returned for this title.');
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MovieDetailsScreen(movie: details),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Could not load details: $e')),
      );
    }
  }

}
