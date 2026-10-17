import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/tmdb_service.dart';
import '../services/auth_service.dart';
import 'search_results_screen.dart';
import 'movie_details_screen.dart';
import 'watchlist_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  late Future<List<Map<String, dynamic>>> _trending;
  late Future<List<Map<String, dynamic>>> _popular;
  late Future<List<Map<String, dynamic>>> _tvShows;
  late Future<List<Map<String, dynamic>>> _topRated;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  void _loadContent() {
    _trending = TmdbService.trendingMovies();
    _popular = TmdbService.popularMovies();
    _tvShows = TmdbService.popularTvShows();
    _topRated = TmdbService.topRatedMovies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    final query = _searchController.text.trim();

    if (query.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SearchResultsScreen(query: query)),
    );
  }

  void _openMovie(Map<String, dynamic> movie) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MovieDetailsScreen(movie: movie)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        title: const Text(
          'MOVIE NIGHT',
          style: TextStyle(
            color: Color(0xFFE50914),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await context.read<AuthService>().signOut();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(_loadContent);

            await Future.wait([_trending, _popular, _tvShows, _topRated]);
          },
          color: const Color(0xFFE50914),
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What are we watching?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.white),
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _search(),
                            decoration: InputDecoration(
                              hintText: 'Search movies...',
                              hintStyle: const TextStyle(color: Colors.white54),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Colors.white70,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF252525),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _search,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE50914),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 17,
                            ),
                          ),
                          child: const Text('Search'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              _MovieSection(
                title: 'Trending This Week',
                subtitle: 'What everyone is watching',
                movies: _trending,
                onTap: _openMovie,
              ),

              _MovieSection(
                title: 'Popular Movies',
                movies: _popular,
                onTap: _openMovie,
              ),

              _MovieSection(
                title: 'Popular TV Shows',
                subtitle: 'Discover your next series',
                movies: _tvShows,
                onTap: _openMovie,
              ),

              _MovieSection(
                title: 'Top Rated Movies',
                movies: _topRated,
                onTap: _openMovie,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF1F1F1F),
        selectedItemColor: const Color(0xFFE50914),
        unselectedItemColor: Colors.white60,
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => WatchlistScreen()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark),
            label: 'My Watchlist',
          ),
        ],
      ),
    );
  }
}

class _MovieSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Future<List<Map<String, dynamic>>> movies;
  final void Function(Map<String, dynamic>) onTap;

  const _MovieSection({
    required this.title,
    this.subtitle,
    required this.movies,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 275,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: movies,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFE50914)),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Could not load titles. Check your internet/API key.',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  );
                }

                final items = snapshot.data ?? [];

                if (items.isEmpty) {
                  return const Center(
                    child: Text(
                      'No titles found.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final movie = items[index];
                    final poster = movie['poster_path'];
                    final titleText =
                        movie['title'] ?? movie['name'] ?? 'Untitled';
                    final rating = movie['vote_average'];

                    return GestureDetector(
                      onTap: () => onTap(movie),
                      child: Container(
                        width: 140,
                        margin: const EdgeInsets.only(right: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 140,
                                height: 195,
                                child:
                                    poster != null &&
                                        poster.toString().isNotEmpty
                                    ? Image.network(
                                        '${TmdbService.imageBase}$poster',
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return _posterPlaceholder();
                                            },
                                      )
                                    : _posterPlaceholder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              titleText.toString(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 15,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  rating is num
                                      ? rating.toStringAsFixed(1)
                                      : 'N/A',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
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

  Widget _posterPlaceholder() {
    return Container(
      color: const Color(0xFF252525),
      child: const Center(
        child: Icon(Icons.movie, color: Colors.white38, size: 45),
      ),
    );
  }
}
