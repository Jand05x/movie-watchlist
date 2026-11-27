import 'package:flutter/material.dart';

import '../services/watchlist_service.dart';
import '../theme/brand.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_loading.dart';
import '../widgets/poster_image.dart';
import 'discover_screen.dart';
import 'movie_details_screen.dart';

class WatchlistScreen extends StatefulWidget {
  final VoidCallback? onOpenDiscover;

  const WatchlistScreen({super.key, this.onOpenDiscover});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  String _filter = 'All';
  String _sort = 'recent';

  void _openDiscover() {
    if (widget.onOpenDiscover != null) {
      widget.onOpenDiscover!();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DiscoverScreen()),
    );
  }

  Future<void> _remove(Map<String, dynamic> movie) async {
    final rawId = movie['tmdb_id'];
    if (rawId is! num) return;
    final id = rawId.toInt();

    try {
      await WatchlistService.remove(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed ${movie['title'] ?? 'this title'}.'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => WatchlistService.restore(movie),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove: $e')),
      );
    }
  }

  void _openDetails(Map<String, dynamic> movie) {
    final id = movie['tmdb_id'];
    if (id is! num) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MovieDetailsScreen(
          movie: {
            'id': id.toInt(),
            'title': movie['title'] ?? 'Untitled',
            'poster_path': movie['poster_path'] ?? '',
            'media_type': movie['media_type'] ?? 'movie',
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Sort',
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'recent', child: Text('Recently added')),
              PopupMenuItem(value: 'title', child: Text('Title A-Z')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
            child: Row(
              children: ['All', 'To watch', 'Watched'].map((filter) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: _filter == filter,
                    onSelected: (value) {
                      if (value) setState(() => _filter = filter);
                    },
                    selectedColor: FlickerColors.primary,
                    labelStyle: FlickerText.caption.copyWith(
                      color: _filter == filter
                          ? FlickerColors.cream
                          : FlickerColors.muted,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: WatchlistService.watchlist(sort: _sort),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppLoading(message: 'Loading your library...');
                }
                if (snapshot.hasError) {
                  return AppErrorState(message: '${snapshot.error}');
                }

                final all = snapshot.data ?? [];
                final movies = all.where((movie) {
                  if (_filter == 'To watch') return movie['watched'] != true;
                  if (_filter == 'Watched') return movie['watched'] == true;
                  return true;
                }).toList();

                if (movies.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.bookmark_add_outlined,
                    title: all.isEmpty
                        ? 'Your library is empty'
                        : 'Nothing here yet',
                    message: all.isEmpty
                        ? 'Save a title to start your watchlist.'
                        : 'Try another filter.',
                    actionLabel: all.isEmpty ? 'Discover movies' : null,
                    onAction: all.isEmpty ? _openDiscover : null,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: movies.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final movie = movies[index];
                    final rawId = movie['tmdb_id'];
                    final id = rawId is num ? rawId.toInt() : null;
                    final watched = movie['watched'] == true;

                    return Card(
                      color: FlickerColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(10),
                        leading: PosterImage(
                          path: movie['poster_path'] as String?,
                          width: 52,
                          height: 76,
                          radius: 7,
                          heroTag: id == null
                              ? null
                              : 'poster-${movie['media_type'] ?? 'movie'}-$id',
                        ),
                        title: Text(
                          (movie['title'] as String?) ?? 'Untitled',
                          style: FlickerText.body.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          watched
                              ? 'Watched${movie['visibility'] == 'public' ? ' · Public' : ''}'
                              : 'To watch',
                          style: FlickerText.caption,
                        ),
                        onTap: () => _openDetails(movie),
                        trailing: IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.delete_outline),
                          color: FlickerColors.danger,
                          onPressed: () => _remove(movie),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
