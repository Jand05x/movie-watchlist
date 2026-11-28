import 'package:flutter/material.dart';

import '../services/tmdb_service.dart';
import '../theme/brand.dart';
import '../widgets/app_error_state.dart';
import '../widgets/movie_card.dart';
import '../widgets/section_header.dart';
import 'movie_details_screen.dart';
import 'search_results_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final TextEditingController _search = TextEditingController();

  late Future<List<Map<String, dynamic>>> _trending;
  late Future<List<Map<String, dynamic>>> _popular;
  late Future<List<Map<String, dynamic>>> _tv;
  late Future<List<Map<String, dynamic>>> _topRated;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _trending = TmdbService.trendingMovies();
    _popular = TmdbService.popularMovies();
    _tv = TmdbService.popularTvShows();
    _topRated = TmdbService.topRatedMovies();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _submitSearch() {
    final query = _search.text.trim();
    if (query.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchResultsScreen(query: query),
      ),
    );
  }

  void _open(Map<String, dynamic> movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MovieDetailsScreen(movie: movie),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(_load);
          await Future.wait([_trending, _popular, _tv, _topRated]);
        },
        color: FlickerColors.primaryBright,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _submitSearch(),
                decoration: const InputDecoration(
                  hintText: 'Search movies and shows',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            SectionHeader(
              title: 'Trending this week',
              subtitle: 'What everyone is watching',
            ),
            _row(_trending),
            SectionHeader(title: 'Popular movies'),
            _row(_popular),
            SectionHeader(title: 'Popular series'),
            _row(_tv),
            SectionHeader(title: 'Top rated'),
            _row(_topRated),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _row(Future<List<Map<String, dynamic>>> future) {
    return SizedBox(
      height: MediaQuery.textScalerOf(context).scale(232),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AppErrorState(message: 'Could not load titles.');
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('No titles found.'));
          }

          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final movie = items[index];
              return MovieCard(
                movie: movie,
                width: 124,
                heroTag: 'poster-${movie['media_type'] ?? 'movie'}-${movie['id']}',
                onTap: () => _open(movie),
              );
            },
          );
        },
      ),
    );
  }
}
