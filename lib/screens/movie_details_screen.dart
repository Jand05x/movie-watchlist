import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/review.dart';
import '../services/review_service.dart';
import '../services/tmdb_service.dart';
import '../services/watchlist_service.dart';
import '../widgets/animated_star_rating.dart';
import '../widgets/genre_chip.dart';
import '../widgets/poster_image.dart';

class MovieDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> movie;

  const MovieDetailsScreen({super.key, required this.movie});

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  static const Color _background = Color(0xFF141414);
  static const Color _red = Color(0xFFE50914);

  late Map<String, dynamic> _details;
  bool _loadingDetails = true;
  bool _checking = true;
  bool _saving = false;
  bool _added = false;
  bool _watched = false;
  int? _rating;
  String _visibility = 'public';

  int? get _tmdbId {
    final id = _details['id'] ?? widget.movie['id'];
    return id is num ? id.toInt() : null;
  }

  @override
  void initState() {
    super.initState();
    _details = Map<String, dynamic>.from(widget.movie);
    _loadDetails();
    _loadPersonalState();
  }

  Future<void> _loadDetails() async {
    final id = _tmdbId;
    if (id == null) {
      if (mounted) setState(() => _loadingDetails = false);
      return;
    }

    final isTv = widget.movie['media_type'] == 'tv';

    try {
      final details = isTv
          ? await TmdbService.getTvDetails(id)
          : await TmdbService.getMovieDetails(id);
      if (!mounted || details == null) return;
      setState(() => _details = details);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  Future<void> _loadPersonalState() async {
    final id = _tmdbId;
    if (id == null) {
      if (mounted) setState(() => _checking = false);
      return;
    }

    try {
      final exists = await WatchlistService.isInWatchlist(id);
      final Review? review = await ReviewService.forMovie(id);
      if (!mounted) return;

      setState(() {
        _added = exists;
        _watched = review?.watched ?? false;
        _rating = review?.rating;
        _visibility = review?.visibility ?? 'public';
        _checking = false;
      });
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _addToWatchlist() async {
    setState(() => _saving = true);

    try {
      await WatchlistService.add(_details);
      if (!mounted) return;
      setState(() => _added = true);
      _showMessage('Added to your watchlist!');
    } catch (e) {
      if (mounted) _showMessage('Could not add movie: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveRating() async {
    final rating = _rating;
    if (rating == null) return;

    setState(() => _saving = true);

    try {
      await ReviewService.saveRating(
        _details,
        rating: rating,
        visibility: _visibility,
      );
      if (mounted) _showMessage('Rating saved to your activity.');
    } catch (e) {
      if (mounted) _showMessage('Could not save rating: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleWatched(bool value) async {
    setState(() => _watched = value);

    try {
      await ReviewService.markWatched(
        _details,
        watched: value,
        visibility: _visibility,
      );
      if (mounted) {
        _showMessage(value ? 'Marked as watched.' : 'Removed from watched.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _watched = !value);
        _showMessage('Could not update: $e');
      }
    }
  }

  Future<void> _toggleVisibility(bool value) async {
    final id = _tmdbId;
    if (id == null) return;

    final next = value ? 'public' : 'private';
    setState(() => _visibility = next);

    try {
      await ReviewService.setVisibility(id, visibility: next);
      if (mounted) {
        _showMessage(
          value ? 'Review shared with friends.' : 'Review is now private.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _visibility = value ? 'private' : 'public');
        _showMessage('Could not update visibility: $e');
      }
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final movie = _details;
    final title = movie['title'] ?? movie['name'] ?? 'Untitled';
    final posterPath = movie['poster_path'] as String?;
    final backdropPath = movie['backdrop_path'] as String?;
    final mediaType = movie['media_type'] as String? ?? 'movie';
    final id = _tmdbId ?? 0;
    final heroTag = 'poster-$mediaType-$id';
    final genres = (movie['genres'] as List?) ?? const [];
    final vote = movie['vote_average'];

    return Scaffold(
      backgroundColor: _background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          title.toString(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _backdrop(backdropPath)),
          SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 82, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      PosterImage(
                        path: posterPath,
                        width: 140,
                        height: 210,
                        radius: 12,
                        heroTag: heroTag,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title.toString(),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Colors.amber,
                                  size: 19,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  vote is num ? vote.toStringAsFixed(1) : 'N/A',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Release: ${movie['release_date'] ?? 'Unknown'}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_loadingDetails) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(
                      minHeight: 2,
                      color: _red,
                      backgroundColor: Colors.transparent,
                    ),
                  ],
                  const SizedBox(height: 22),
                  if (genres.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: genres.whereType<Map>().map((genre) {
                        final rawId = genre['id'];
                        return GenreChip(
                          label: (genre['name'] as String?) ?? 'Genre',
                          genreId: rawId is num ? rawId.toInt() : null,
                        );
                      }).toList(),
                    ),
                  if (genres.isNotEmpty) const SizedBox(height: 20),
                  Text(
                    movie['overview']?.toString().isNotEmpty == true
                        ? movie['overview'].toString()
                        : 'No description available.',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 26),
                  _reviewCard(),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _saving || _checking || _added || id == 0
                          ? null
                          : _addToWatchlist,
                      icon: Icon(
                        _added ? Icons.bookmark_added : Icons.bookmark_add,
                      ),
                      label: Text(
                        _checking
                            ? 'Checking Watchlist...'
                            : _added
                            ? 'Added to Watchlist'
                            : 'Add to Watchlist',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xF21F1F1F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your watch session',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap a star to rate this movie.',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 12),
          AnimatedStarRating(
            rating: _rating ?? 0,
            onChanged: (value) => setState(() => _rating = value),
          ),
          const SizedBox(height: 4),
          Text(
            _rating == null ? 'Not rated yet' : '$_rating of 5 stars',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const Divider(height: 26, color: Colors.white12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _watched,
            onChanged: _toggleWatched,
            activeThumbColor: _red,
            secondary: const Icon(Icons.check_circle_outline, color: _red),
            title: const Text(
              'Mark as watched',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Counts toward your monthly recap',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _visibility == 'public',
            onChanged: _toggleVisibility,
            activeThumbColor: _red,
            secondary: const Icon(Icons.people_outline, color: _red),
            title: const Text(
              'Share with friends',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Show this in your friends\' activity feed',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _rating == null || _saving ? null : _saveRating,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving...' : 'Save rating'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _backdrop(String? path) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (path != null && path.isNotEmpty)
          CachedNetworkImage(
            imageUrl: '${TmdbService.backdropBase}$path',
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                const ColoredBox(color: Color(0xFF1B1B1B)),
            errorWidget: (context, url, error) =>
                const ColoredBox(color: Color(0xFF1B1B1B)),
          )
        else
          const ColoredBox(color: Color(0xFF1B1B1B)),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xC4141414),
                Color(0x99141414),
                Color(0xEE141414),
                _background,
              ],
              stops: [0.0, 0.4, 0.78, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}
