import 'package:flutter/material.dart';

import '../services/tmdb_service.dart';
import '../widgets/poster_image.dart';
import 'movie_details_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  final String query;

  const SearchResultsScreen({super.key, required this.query});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late Future<List<Map<String, dynamic>>> _moviesFuture;

  @override
  void initState() {
    super.initState();
    _moviesFuture = TmdbService.searchMovies(widget.query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Results: ${widget.query}')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _moviesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Search failed: ${snapshot.error}'));
          }

          final movies = snapshot.data ?? [];

          if (movies.isEmpty) {
            return const Center(child: Text('No movies found.'));
          }

          return ListView.builder(
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final movie = movies[index];
              final rawId = movie['id'];
              final id = rawId is num ? rawId.toInt() : null;

              return ListTile(
                leading: PosterImage(
                  path: movie['poster_path'] as String?,
                  width: 48,
                  height: 72,
                  heroTag: id == null ? null : 'poster-movie-$id',
                ),
                title: Text(movie['title'] ?? 'Untitled'),
                subtitle: Text((movie['release_date'] ?? '').toString()),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MovieDetailsScreen(movie: movie),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
