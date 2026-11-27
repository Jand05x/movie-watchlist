import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/activity_service.dart';
import '../services/taste_service.dart';
import '../services/tmdb_service.dart';
import '../services/user_service.dart';
import '../services/watchlist_service.dart';
import '../theme/brand.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/movie_card.dart';
import '../widgets/section_header.dart';
import 'activity_feed_screen.dart';
import 'movie_details_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'recap_screen.dart';
import 'search_results_screen.dart';
import 'watchlist_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _search = TextEditingController();

  late Future<List<Map<String, dynamic>>> _trending;
  late Future<List<Map<String, dynamic>>> _recommendations;
  late Future<String?> _topGenre;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _trending = TmdbService.trendingMovies();
    _topGenre = _loadTopGenre();
    _recommendations = _loadRecommendations();
  }

  Future<String?> _loadTopGenre() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final taste = await TasteService.forUser(uid);
    final genres = taste?['genreScores'];
    if (genres is! List || genres.isEmpty) return null;
    final first = genres.first;
    return first is Map ? first['name'] as String? : null;
  }

  Future<List<Map<String, dynamic>>> _loadRecommendations() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const [];

    final taste = await TasteService.forUser(uid);
    final genres = taste?['genreScores'];
    if (genres is! List || genres.isEmpty) return const [];

    for (final entry in genres) {
      if (entry is! Map) continue;
      final id = entry['id'];
      if (id is num && id > 0) {
        return TmdbService.discoverByGenre(id.toInt());
      }
    }
    return const [];
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: FlickerStrings.appName,
                style: FlickerText.section,
              ),
              TextSpan(text: '\n${FlickerStrings.tagline}', style: FlickerText.label),
            ],
          ),
        ),
        toolbarHeight: 62,
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationsScreen(),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FutureBuilder(
              future: UserService.profile(uid),
              builder: (context, snapshot) {
                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfileScreen(),
                      ),
                    );
                  },
                  child: InitialsAvatar(
                    name: snapshot.data?.label ?? 'Me',
                    imageUrl: snapshot.data?.avatarUrl,
                    radius: 19,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(_load);
          await _trending;
        },
        color: FlickerColors.primaryBright,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) {
                  if (value.trim().isEmpty) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SearchResultsScreen(query: value.trim()),
                    ),
                  );
                },
                decoration: const InputDecoration(
                  hintText: 'Search movies, shows, people',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            _greeting(uid),
            SectionHeader(
              title: 'From your circle',
              subtitle: 'Movies friends sent you',
              actionLabel: 'See all',
              onAction: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ActivityFeedScreen(),
                  ),
                );
              },
            ),
            _circleRow(),
            SectionHeader(
              title: 'Your next watch',
              subtitle: 'Saved and not watched yet',
              actionLabel: 'Library',
              onAction: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WatchlistScreen(),
                  ),
                );
              },
            ),
            _watchlistRow(),
            FutureBuilder<String?>(
              future: _topGenre,
              builder: (context, snapshot) {
                final genre = snapshot.data;
                if (genre == null) return const SizedBox.shrink();
                return Column(
                  children: [
                    SectionHeader(
                      title: 'Because you like $genre',
                      subtitle: 'Picked from your ratings',
                    ),
                    _futureRow(_recommendations),
                  ],
                );
              },
            ),
            SectionHeader(title: 'Trending this week'),
            _futureRow(_trending),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RecapScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.bar_chart),
                label: const Text('See your monthly recap'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FlickerColors.primaryBright,
                  side: const BorderSide(color: FlickerColors.primaryBright),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _greeting(String uid) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: FutureBuilder(
        future: UserService.profile(uid),
        builder: (context, snapshot) {
          final name = snapshot.data?.label ?? 'movie fan';
          return Text(
            '$greeting, $name',
            style: FlickerText.display.copyWith(fontSize: 24),
          );
        },
      ),
    );
  }

  Widget _circleRow() {
    return SizedBox(
      height: 232,
      child: StreamBuilder(
        stream: ActivityService.feed(),
        builder: (context, snapshot) {
          final entries = snapshot.data ?? [];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: FlickerColors.primaryBright),
            );
          }
          if (snapshot.hasError) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Could not load your circle. Pull down to retry.',
                style: FlickerText.caption,
              ),
            );
          }
          if (entries.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Share a movie with a friend to start your circle.',
                style: FlickerText.caption,
              ),
            );
          }

          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: entries.take(10).length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return MovieCard(
                movie: {
                  'id': entry.movieId,
                  'title': entry.title,
                  'poster_path': entry.posterPath,
                  'media_type': entry.mediaType,
                  'vote_average': entry.rating ?? 0,
                },
                width: 124,
                badge: entry.isInvite ? 'INVITE' : 'FROM A FRIEND',
                onTap: () => _open({
                  'id': entry.movieId,
                  'title': entry.title,
                  'poster_path': entry.posterPath,
                  'media_type': entry.mediaType,
                }),
              );
            },
          );
        },
      ),
    );
  }

  Widget _watchlistRow() {
    return SizedBox(
      height: 232,
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: WatchlistService.watchlist(),
        builder: (context, snapshot) {
          final movies = (snapshot.data ?? [])
              .where((movie) => movie['watched'] != true)
              .take(10)
              .toList();
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: FlickerColors.primaryBright),
            );
          }
          if (snapshot.hasError) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Could not load your library. Pull down to retry.',
                style: FlickerText.caption,
              ),
            );
          }
          if (movies.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Nothing saved yet. Discover something worth watching.',
                style: FlickerText.caption,
              ),
            );
          }

          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: movies.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final movie = movies[index];
              final id = movie['tmdb_id'];
              final card = {
                'id': id,
                'title': movie['title'] ?? 'Untitled',
                'poster_path': movie['poster_path'] ?? '',
                'media_type': movie['media_type'] ?? 'movie',
                'vote_average': movie['rating'] ?? 0,
              };
              return MovieCard(
                movie: card,
                width: 124,
                onTap: () => _open(card),
              );
            },
          );
        },
      ),
    );
  }

  Widget _futureRow(Future<List<Map<String, dynamic>>> future) {
    return SizedBox(
      height: 232,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Center(child: Text('Could not load titles.'));
          }
          if (snapshot.data!.isEmpty) {
            return const Center(child: Text('No titles found.'));
          }

          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: snapshot.data!.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final movie = snapshot.data![index];
              return MovieCard(
                movie: movie,
                width: 124,
                onTap: () => _open(movie),
              );
            },
          );
        },
      ),
    );
  }
}
