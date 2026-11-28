import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/friend_service.dart';
import '../services/taste_service.dart';
import '../services/user_service.dart';
import '../theme/brand.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/initials_avatar.dart';

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final TextEditingController _controller = TextEditingController();

  bool _loadingSuggestions = true;
  bool _searching = false;
  String? _suggestionsError;
  String? _error;
  String? _status;
  List<UserProfile> _suggestions = [];
  List<UserProfile> _results = [];
  final Set<String> _pending = {};

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    setState(() {
      _loadingSuggestions = true;
      _suggestionsError = null;
    });
    try {
      final suggestions = await UserService.suggestions();
      if (!mounted) return;
      setState(() => _suggestions = suggestions.take(8).toList());
    } catch (e) {
      if (mounted) setState(() => _suggestionsError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingSuggestions = false);
    }
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _error = null;
        _status = null;
      });
      return;
    }

    setState(() {
      _searching = true;
      _error = null;
      _status = null;
      _results = const [];
    });

    try {
      final results = await UserService.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        if (results.isEmpty) _error = 'No discoverable users found for "$query".';
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not search: $e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _send(UserProfile profile) async {
    if (_pending.contains(profile.uid)) return;

    setState(() {
      _pending.add(profile.uid);
      _error = null;
      _status = null;
    });

    try {
      final result = await FriendService.sendRequest(profile.uid);
      if (!mounted) return;
      setState(() => _status = result.message);
      if (result.didSend) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not send request: $e');
    } finally {
      if (mounted) {
        setState(() => _pending.remove(profile.uid));
      }
    }
  }

  Future<List<String>> _genres(String uid) async {
    try {
      final taste = await TasteService.forUser(uid);
      final genres = taste?['genreScores'];
      if (genres is! List) return const [];
      return genres
          .whereType<Map>()
          .map((genre) => (genre['name'] as String?) ?? '')
          .where((name) => name.isNotEmpty)
          .take(3)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlickerColors.canvas,
      appBar: AppBar(title: const Text('Discover People')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            const Text('Find your people', style: FlickerText.section),
            const SizedBox(height: 4),
            const Text(
              'Search by name, username or email. People who turn off discovery will not appear.',
              style: FlickerText.caption,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              style: FlickerText.body,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              onSubmitted: (_) => _search(),
              decoration: const InputDecoration(
                hintText: 'Name, @username or email',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: FlickerColors.primaryBright,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _searching ? null : _search,
              icon: _searching
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.search),
              label: const Text('Search'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: FlickerText.body.copyWith(color: FlickerColors.danger),
              ),
            ],
            if (_status != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FlickerColors.roseWash,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_status!, style: FlickerText.body),
              ),
            ],
            if (_results.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text('Search results', style: FlickerText.section),
              const SizedBox(height: 10),
              for (final profile in _results) ...[
                _personCard(profile),
                const SizedBox(height: 8),
              ],
            ],
            const SizedBox(height: 24),
            const Text('People you may know', style: FlickerText.section),
            const SizedBox(height: 4),
            const Text(
              'Discover movie fans who are open to new friends.',
              style: FlickerText.caption,
            ),
            const SizedBox(height: 10),
            if (_loadingSuggestions)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(
                    color: FlickerColors.primaryBright,
                  ),
                ),
              )
            else if (_suggestionsError != null)
              AppErrorState(
                message: 'Could not load suggestions.\n$_suggestionsError',
                onRetry: _loadSuggestions,
              )
            else if (_suggestions.isEmpty)
              const AppEmptyState(
                icon: Icons.people_outline,
                title: 'No suggestions yet',
                message: 'Try searching by name, username or email.',
              )
            else
              for (final profile in _suggestions) ...[
                _personCard(profile),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }

  Widget _personCard(UserProfile profile) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final busy = _pending.contains(profile.uid);

    return Card(
      color: FlickerColors.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            InitialsAvatar(
              name: profile.label,
              imageUrl: profile.avatarUrl,
              radius: 23,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.label,
                    style: FlickerText.body.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${profile.username}',
                    style: FlickerText.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (profile.bio.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      profile.bio,
                      style: FlickerText.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  FutureBuilder<int>(
                    future: UserService.mutualFriendCount(profile.uid),
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return Text(
                        count == 1 ? '1 mutual friend' : '$count mutual friends',
                        style: FlickerText.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                  FutureBuilder<List<String>>(
                    future: _genres(profile.uid),
                    builder: (context, snapshot) {
                      final genres = snapshot.data ?? const [];
                      if (genres.isEmpty) return const SizedBox.shrink();
                      return Text(
                        'Likes ${genres.join(', ')}',
                        style: FlickerText.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (profile.uid != uid)
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: FlickerColors.primaryBright,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onPressed: busy ? null : () => _send(profile),
                child: Text(
                  busy ? 'Sending' : 'Add',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
