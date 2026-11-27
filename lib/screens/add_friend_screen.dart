import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/friend_service.dart';
import '../services/user_service.dart';
import '../theme/brand.dart';
import '../widgets/initials_avatar.dart';

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final TextEditingController _controller = TextEditingController();

  bool _searching = false;
  bool _sending = false;
  String? _error;
  String? _status;
  UserProfile? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _error = null;
      _status = null;
      _result = null;
    });

    try {
      final isUsername = query.startsWith('@');
      final username = isUsername ? query.substring(1).trim() : query;
      final profile = isUsername
          ? await UserService.findByUsername(username)
          : await UserService.findByEmail(query) ??
              await UserService.findByUsername(username);

      if (!mounted) return;

      if (profile == null) {
        setState(() => _error = 'No user found for "$query".');
      } else if (profile.uid == FirebaseAuth.instance.currentUser?.uid) {
        setState(() => _error = 'That is your own account.');
      } else {
        setState(() => _result = profile);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not search: $e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _send() async {
    final profile = _result;
    if (profile == null) return;

    setState(() {
      _sending = true;
      _error = null;
      _status = null;
    });

    try {
      final result = await FriendService.sendRequest(profile.uid);
      if (!mounted) return;

      setState(() {
        _status = result.message;
        _sending = false;
      });

      if (result.didSend) {
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not send request: $e';
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlickerColors.canvas,
      appBar: AppBar(title: const Text('Add Friend')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Find by email or username',
                style: FlickerText.section,
              ),
              const SizedBox(height: 4),
              const Text(
                'Use @username for a username, or an email address.',
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
                  hintText: 'email@example.com or @username',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: FlickerColors.primaryBright,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _searching ? null : _search,
                child: _searching
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Search'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: FlickerText.body.copyWith(color: FlickerColors.danger),
                ),
              ],
              if (_status != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: FlickerColors.roseWash,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_status!, style: FlickerText.body),
                ),
              ],
              if (_result != null) ...[
                const SizedBox(height: 24),
                Card(
                  color: FlickerColors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            InitialsAvatar(
                              name: _result!.label,
                              imageUrl: _result!.avatarUrl,
                              radius: 24,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _result!.label,
                                    style: FlickerText.body.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '@${_result!.username}',
                                    style: FlickerText.caption,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: FlickerColors.primaryBright,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _sending ? null : _send,
                          icon: const Icon(Icons.person_add_alt_1),
                          label: Text(_sending ? 'Sending...' : 'Send request'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
