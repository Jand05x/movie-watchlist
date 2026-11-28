import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/friendship.dart';
import '../models/review.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/compatibility_service.dart';
import '../services/friend_service.dart';
import '../services/review_service.dart';
import '../services/taste_service.dart';
import '../services/tmdb_service.dart';
import '../services/user_service.dart';
import '../services/watchlist_service.dart';
import '../theme/brand.dart';
import '../utils/date_format.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_loading.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/poster_image.dart';
import 'notifications_screen.dart';
import 'recap_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? friendUid;

  const ProfileScreen({super.key, this.friendUid});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _refreshKey = 0;

  void _refresh() {
    if (!mounted) return;
    setState(() => _refreshKey++);
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.friendUid ?? FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.friendUid == null ? 'Your Profile' : 'Friend Profile'),
        actions: [
          if (widget.friendUid == null)
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: _refresh,
            ),
          if (widget.friendUid == null)
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
        ],
      ),
      body: FutureBuilder<UserProfile?>(
        key: ValueKey('profile-$_refreshKey'),
        future: UserService.profile(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoading(message: 'Loading profile...');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: 'Could not load profile.\n${snapshot.error}',
              onRetry: _refresh,
            );
          }

          final profile = snapshot.data;
          if (profile == null) {
            return AppErrorState(
              message: 'Profile not found.',
              onRetry: _refresh,
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _header(context, profile),
              const SizedBox(height: 20),
              if (widget.friendUid == null) ...[
                _profileCounts(),
                const SizedBox(height: 18),
                _sectionTitle(
                  'Your movie taste',
                  'The genres you keep coming back to.',
                ),
                _yourMovieTaste(uid),
                const SizedBox(height: 18),
                _sectionTitle(
                  'Your taste with your friends',
                  'See where your movie tastes overlap.',
                ),
                _compatibilityList(context),
                const SizedBox(height: 18),
                _sectionTitle(
                  'Your movie notes',
                  'Private thoughts you can keep on each movie.',
                ),
                _notesSection(),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RecapScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.bar_chart),
                  label: const Text('View monthly recap'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FlickerColors.primaryBright,
                    side: const BorderSide(color: FlickerColors.primaryBright),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.read<AuthService>().signOut(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Log out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FlickerColors.muted,
                    side: const BorderSide(color: FlickerColors.muted),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ] else ...[
                _sectionTitle(
                  'Taste match with ${profile.label}',
                  'A quick snapshot of what you both enjoy.',
                ),
                _friendCompatibility(uid),
                const SizedBox(height: 18),
                _sectionTitle(
                  'Their movie taste',
                  'Genres they enjoy most.',
                ),
                _yourMovieTaste(uid),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: FlickerText.section),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: FlickerText.caption,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, UserProfile profile) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InitialsAvatar(
          name: profile.label,
          imageUrl: profile.avatarUrl,
          radius: 38,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.label,
                style: FlickerText.display.copyWith(fontSize: 23),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text('@${profile.username}', style: FlickerText.caption),
              if (profile.bio.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(profile.bio, style: FlickerText.body),
              ],
            ],
          ),
        ),
        if (widget.friendUid == null)
          IconButton(
            tooltip: 'Edit profile',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editProfile(context, profile),
          ),
      ],
    );
  }

  Future<void> _editProfile(BuildContext context, UserProfile profile) async {
    final displayName = TextEditingController(text: profile.displayName);
    final bio = TextEditingController(text: profile.bio);
    final avatarUrl = TextEditingController(text: profile.avatarUrl);
    bool discoverable = profile.discoverable;
    bool tasteShared = profile.tasteShared;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit profile'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: displayName,
                      decoration: const InputDecoration(labelText: 'Display name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: bio,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Bio'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: avatarUrl,
                      decoration: const InputDecoration(
                        labelText: 'Avatar image URL',
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: discoverable,
                      onChanged: (value) =>
                          setDialogState(() => discoverable = value),
                      title: const Text('Discoverable by friends'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: tasteShared,
                      onChanged: (value) =>
                          setDialogState(() => tasteShared = value),
                      title: const Text('Share taste for compatibility'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) return;

    try {
      await UserService.updateProfile(
        displayName: displayName.text,
        bio: bio.text,
        avatarUrl: avatarUrl.text,
        discoverable: discoverable,
        tasteShared: tasteShared,
      );
      _refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    }
  }

  Future<Map<String, int>> _loadCounts() async {
    final entries = await WatchlistService.allEntries().first;
    return {
      'watched': entries.where((movie) => movie['watched'] == true).length,
      'wanting': entries.where((movie) => movie['watched'] != true).length,
    };
  }

  Widget _profileCounts() {
    return FutureBuilder<Map<String, int>>(
      key: ValueKey('counts-$_refreshKey'),
      future: _loadCounts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoading(message: 'Loading your library...');
        }
        if (snapshot.hasError) {
          return AppErrorState(
            message: 'Could not load your library.\n${snapshot.error}',
            onRetry: _refresh,
          );
        }

        final counts = snapshot.data ?? const <String, int>{};
        return Row(
          children: [
            Expanded(
              child: _statBox('${counts['watched'] ?? 0}', 'Watched'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statBox('${counts['wanting'] ?? 0}', 'Wanting to watch'),
            ),
          ],
        );
      },
    );
  }

  Widget _statBox(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlickerColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlickerColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: FlickerText.display),
          const SizedBox(height: 2),
          Text(
            label,
            style: FlickerText.caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _yourMovieTaste(String uid) {
    return FutureBuilder<Map<String, dynamic>?>(
      key: ValueKey('taste-$_refreshKey-$uid'),
      future: TasteService.forUser(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoading(message: 'Loading movie taste...');
        }
        if (snapshot.hasError) {
          return AppErrorState(
            message: 'Movie taste is not available.',
            onRetry: _refresh,
          );
        }

        final taste = snapshot.data;
        if (taste == null) {
          return const AppEmptyState(
            icon: Icons.movie_outlined,
            title: 'No movie taste yet',
            message: 'Rate a few movies to build your taste profile.',
          );
        }

        final genres = taste['genreScores'];
        if (genres is! List || genres.isEmpty) {
          return const AppEmptyState(
            icon: Icons.movie_outlined,
            title: 'No movie taste yet',
            message: 'Rate a few movies to build your taste profile.',
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: genres.whereType<Map>().map((genre) {
            return Chip(
              label: Text('${genre['name']}'),
              backgroundColor: FlickerColors.surface,
              labelStyle: FlickerText.caption,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _notesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: FlickerColors.primaryBright,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
            onPressed: () => _showNotePicker(context),
            icon: const Icon(Icons.add_comment_outlined),
            label: const Text('Add a note'),
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Review>>(
          key: ValueKey('notes-$_refreshKey'),
          future: ReviewService.notes(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoading(message: 'Loading notes...');
            }
            if (snapshot.hasError) {
              return AppErrorState(
                message: 'Could not load notes.\n${snapshot.error}',
                onRetry: _refresh,
              );
            }

            final notes = snapshot.data ?? const [];
            if (notes.isEmpty) {
              return const AppEmptyState(
                icon: Icons.note_outlined,
                title: 'No notes yet',
                message: 'Pick a movie above and write a private note.',
              );
            }

            return Column(
              children: notes.map(_noteCard).toList(),
            );
          },
        ),
      ],
    );
  }

  Future<void> _showNotePicker(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlickerColors.canvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: const Radius.circular(20)),
      ),
      builder: (_) => NotePickerSheet(onSaved: _refresh),
    );
  }

  Widget _noteCard(Review review) {
    return Card(
      color: FlickerColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PosterImage(
              path: review.posterPath,
              width: 44,
              height: 64,
              radius: 6,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review.title,
                    style: FlickerText.body.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatShortDate(review.timestamp),
                    style: FlickerText.label,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    review.note,
                    style: FlickerText.body,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compatibilityList(BuildContext context) {
    return StreamBuilder<List<Friendship>>(
      key: ValueKey('friends-$_refreshKey'),
      stream: FriendService.friends(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoading(message: 'Finding friends...');
        }
        if (snapshot.hasError) {
          return AppErrorState(
            message: 'Could not load friends.\n${snapshot.error}',
            onRetry: _refresh,
          );
        }

        final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final friends = (snapshot.data ?? [])
            .map((friendship) => friendship.otherUser(currentUid))
            .where((uid) => uid.isNotEmpty)
            .toList();
        if (friends.isEmpty) {
          return const AppEmptyState(
            icon: Icons.people_outline,
            title: 'No friends to compare yet',
            message: 'Add a friend from the Friends tab to see your taste match.',
          );
        }

        return Column(
          children: friends.map((friendUid) {
            return _friendMatchTile(context, friendUid);
          }).toList(),
        );
      },
    );
  }

  Widget _friendMatchTile(BuildContext context, String friendUid) {
    return FutureBuilder<UserProfile?>(
      key: ValueKey('friend-profile-$friendUid-$_refreshKey'),
      future: UserService.profile(friendUid),
      builder: (context, profileSnapshot) {
        final profile = profileSnapshot.data;
        final name = profile?.label ?? 'Friend';
        return Card(
          color: FlickerColors.surface,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: InitialsAvatar(
              name: name,
              imageUrl: profile?.avatarUrl,
              radius: 20,
            ),
            title: Text(
              name,
              style: FlickerText.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: FutureBuilder<CompatibilityResult>(
              key: ValueKey('match-$friendUid-$_refreshKey'),
              future: CompatibilityService.scoreWith(friendUid),
              builder: (context, scoreSnapshot) {
                if (scoreSnapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('Comparing taste...'),
                  );
                }
                if (scoreSnapshot.hasError) {
                  return const Text('Could not compare taste.');
                }
                final result = scoreSnapshot.data;
                if (result == null) return const Text('No match data.');

                final headline = result.enoughData
                    ? '${result.score}% · ${result.band}'
                    : result.band;
                final detail = result.sharedGenres.isNotEmpty
                    ? 'Shared: ${result.sharedGenres.join(', ')}'
                    : result.explanation;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(headline, style: FlickerText.caption),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: FlickerText.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              },
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(friendUid: friendUid),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _friendCompatibility(String uid) {
    return FutureBuilder<CompatibilityResult>(
      key: ValueKey('friend-match-$uid-$_refreshKey'),
      future: CompatibilityService.scoreWith(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoading(message: 'Comparing taste...');
        }
        if (snapshot.hasError) {
          return AppErrorState(
            message: 'Could not compare taste.\n${snapshot.error}',
            onRetry: _refresh,
          );
        }
        final result = snapshot.data;
        if (result == null) {
          return const AppEmptyState(
            icon: Icons.favorite_border,
            title: 'No match available',
            message: 'Taste information is not available yet.',
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: FlickerColors.roseWash,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.enoughData ? '${result.score}% match' : result.band,
                style: FlickerText.display,
              ),
              const SizedBox(height: 6),
              Text(result.explanation, style: FlickerText.caption),
              if (result.sharedGenres.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Shared genres', style: FlickerText.label),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: result.sharedGenres
                      .map((genre) => Chip(
                            label: Text(genre),
                            backgroundColor: FlickerColors.surface,
                            labelStyle: FlickerText.caption,
                          ))
                      .toList(),
                ),
              ],
              if (result.sharedMovieTitles.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Movies you both watched',
                  style: FlickerText.label,
                ),
                const SizedBox(height: 4),
                Text(
                  result.sharedMovieTitles.join(', '),
                  style: FlickerText.body,
                ),
              ],
              if (result.suggestedGenres.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'They also like: ${result.suggestedGenres.join(', ')}',
                  style: FlickerText.body,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class NotePickerSheet extends StatefulWidget {
  final VoidCallback onSaved;

  const NotePickerSheet({super.key, required this.onSaved});

  @override
  State<NotePickerSheet> createState() => _NotePickerSheetState();
}

class _NotePickerSheetState extends State<NotePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  List<Map<String, dynamic>> _watchlist = const [];
  List<Map<String, dynamic>> _results = const [];
  Map<String, dynamic>? _selected;
  bool _loadingWatchlist = true;
  bool _searching = false;
  bool _saving = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _loadWatchlist();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadWatchlist() async {
    try {
      final entries = await WatchlistService.watchlist().first;
      if (!mounted) return;
      setState(() {
        _watchlist = entries
            .where(
              (movie) =>
                  movie['tmdb_id'] != null ||
                  movie['tmdbId'] != null ||
                  movie['id'] != null,
            )
            .map(_normalize)
            .toList();
      });
    } catch (_) {
      if (mounted) setState(() => _searchError = 'Could not load your watchlist.');
    } finally {
      if (mounted) setState(() => _loadingWatchlist = false);
    }
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> movie) {
    return {
      'id': movie['id'] ?? movie['tmdbId'] ?? movie['tmdb_id'],
      'title': movie['title'] ?? movie['name'] ?? 'Untitled',
      'poster_path': movie['poster_path'] ?? movie['posterPath'] ?? '',
      'media_type': movie['media_type'] ?? movie['mediaType'] ?? 'movie',
    };
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _searchError = null;
    });

    try {
      final results = await TmdbService.searchMovies(query);
      if (!mounted) return;
      setState(() {
        _results = results.take(8).map(_normalize).toList();
      });
    } catch (_) {
      if (mounted) {
        setState(() => _searchError = 'Could not search movies. Try again.');
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _save() async {
    final selected = _selected;
    if (selected == null || _saving) return;

    setState(() => _saving = true);
    try {
      await ReviewService.setNote(selected, _noteController.text);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save note: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottomInset),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.82,
          child: _selected == null ? _pickMovie() : _writeNote(),
        ),
      ),
    );
  }

  Widget _pickMovie() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Add a private note', style: FlickerText.section),
        const SizedBox(height: 4),
        const Text('Pick a movie first.', style: FlickerText.caption),
        const SizedBox(height: 14),
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search movies',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: _searching ? null : _search,
            ),
          ),
        ),
        if (_searchError != null) ...[
          const SizedBox(height: 8),
          Text(_searchError!, style: FlickerText.caption),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              const Text('Your watchlist', style: FlickerText.label),
              const SizedBox(height: 6),
              if (_loadingWatchlist)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_watchlist.isEmpty)
                const Text(
                  'Nothing saved yet. Search for a movie below.',
                  style: FlickerText.caption,
                )
              else
                ..._watchlist.map(_movieTile),
              const SizedBox(height: 16),
              if (_searching)
                const Center(child: CircularProgressIndicator())
              else if (_results.isNotEmpty) ...[
                const Text('Search results', style: FlickerText.label),
                const SizedBox(height: 6),
                ..._results.map(_movieTile),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _writeNote() {
    final movie = _selected!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            PosterImage(
              path: movie['poster_path'] as String?,
              width: 48,
              height: 70,
              radius: 6,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                movie['title'] as String? ?? 'Untitled',
                style: FlickerText.body.copyWith(fontWeight: FontWeight.w700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Change movie',
              icon: const Icon(Icons.swap_horiz),
              onPressed: () => setState(() {
                _selected = null;
                _noteController.clear();
              }),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _noteController,
          enabled: !_saving,
          maxLines: 5,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Your note',
            hintText: 'What did you think?',
            helperText: 'Private to you',
          ),
        ),
        const Spacer(),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: FlickerColors.primaryBright,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Saving...' : 'Save note'),
        ),
      ],
    );
  }

  Widget _movieTile(Map<String, dynamic> movie) {
    return Card(
      color: FlickerColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: PosterImage(
          path: movie['poster_path'] as String?,
          width: 40,
          height: 58,
          radius: 5,
        ),
        title: Text(
          movie['title'] as String? ?? 'Untitled',
          style: FlickerText.body.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: const Text('Tap to write a note', style: FlickerText.caption),
        onTap: () => setState(() => _selected = movie),
      ),
    );
  }
}
