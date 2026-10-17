import 'package:flutter/material.dart';

import '../services/tmdb_service.dart';
import '../services/watchlist_service.dart';

class MovieDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> movie;

  const MovieDetailsScreen({super.key, required this.movie});

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  bool _saving = false;
  bool _added = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkWatchlist();
  }

  Future<void> _checkWatchlist() async {
    final id = widget.movie['id'];

    if (id is! int) {
      if (mounted) {
        setState(() => _checking = false);
      }
      return;
    }

    try {
      final exists = await WatchlistService.isInWatchlist(id);

      if (mounted) {
        setState(() {
          _added = exists;
          _checking = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  Future<void> _addToWatchlist() async {
    setState(() => _saving = true);

    try {
      await WatchlistService.add(widget.movie);

      if (!mounted) return;

      setState(() => _added = true);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Added to your watchlist!')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not add movie: $e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    final posterPath = movie['poster_path'] as String?;
    final id = movie['id'];

    return Scaffold(
      appBar: AppBar(title: Text(movie['title'] ?? 'Movie details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (posterPath != null && posterPath.isNotEmpty)
              Center(
                child: Image.network(
                  '${TmdbService.imageBase}$posterPath',
                  height: 300,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.movie, size: 100),
                ),
              ),
            const SizedBox(height: 20),
            Text(
              movie['title'] ?? 'Untitled',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Release date: ${movie['release_date'] ?? 'Unknown'}'),
            const SizedBox(height: 12),
            Text(movie['overview'] ?? 'No description available.'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE50914),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _saving || _checking || _added || id == null
                    ? null
                    : _addToWatchlist,
                icon: Icon(_added ? Icons.bookmark_added : Icons.bookmark_add),
                label: Text(
                  _checking
                      ? 'Checking Watchlist...'
                      : _saving
                      ? 'Adding...'
                      : _added
                      ? 'Added to Watchlist'
                      : 'Add to Watchlist',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
