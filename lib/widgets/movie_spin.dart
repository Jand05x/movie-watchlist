import 'dart:math';

import 'package:flutter/material.dart';

import '../services/watchlist_service.dart';
import '../theme/brand.dart';
import '../utils/movie_picker.dart';
import 'movie_card.dart';

class MovieSpin extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>> onOpen;

  const MovieSpin({super.key, required this.onOpen});

  @override
  State<MovieSpin> createState() => _MovieSpinState();
}

class _MovieSpinState extends State<MovieSpin> {
  final Random _random = Random();
  String? _lastKey;
  double _turns = 0;
  bool _spinning = false;

  Future<List<Map<String, dynamic>>?> _loadUnwatched() async {
    try {
      final entries = await WatchlistService.watchlist().first;
      return entries.where((movie) => movie['watched'] != true).toList();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load your watchlist.')),
        );
      }
      return null;
    }
  }

  void _notifyEmpty() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add a movie to your to-watch list first.'),
      ),
    );
  }

  Future<void> _spin() async {
    if (_spinning) return;

    setState(() {
      _spinning = true;
      _turns += 2 + _random.nextInt(3);
    });

    final entries = await _loadUnwatched();

    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    setState(() => _spinning = false);

    if (entries == null) return;
    if (entries.isEmpty) {
      _notifyEmpty();
      return;
    }

    final pick = pickRandomMovie(entries, _random, lastKey: _lastKey);
    if (pick == null) return;
    _lastKey = moviePickKey(pick);
    _showPick(pick);
  }

  void _showPick(Map<String, dynamic> pick) {
    final card = _cardMap(pick);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlickerColors.canvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: const Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('Tonight\'s pick', style: FlickerText.section),
                const SizedBox(height: 4),
                const Text(
                  'Picked from your to-watch list',
                  style: FlickerText.caption,
                ),
                const SizedBox(height: 18),
                MovieCard(movie: card, width: 148),
                const SizedBox(height: 18),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: FlickerColors.primaryBright,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    widget.onOpen(card);
                  },
                  icon: const Icon(Icons.movie_outlined),
                  label: const Text('View details'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<String, dynamic> _cardMap(Map<String, dynamic> movie) {
    return {
      'id': movie['tmdb_id'] ?? movie['tmdbId'] ?? movie['id'],
      'title': movie['title'] ?? 'Untitled',
      'poster_path': movie['poster_path'] ?? '',
      'media_type': movie['media_type'] ?? 'movie',
      'vote_average': movie['rating'] ?? 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
      child: Center(
        child: GestureDetector(
          onTap: _spin,
          child: Semantics(
            button: true,
            label: 'Spin for a random movie from your to-watch list',
            child: Column(
              children: [
                AnimatedRotation(
                  turns: _turns,
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          FlickerColors.primaryBright,
                          FlickerColors.primary,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: FlickerColors.primary.withAlpha(90),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      _spinning ? Icons.hourglass_top : Icons.shuffle,
                      color: FlickerColors.cream,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _spinning ? 'Spinning...' : 'Spin for a pick',
                  style: FlickerText.caption,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
