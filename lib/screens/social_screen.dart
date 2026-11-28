import 'package:flutter/material.dart';

import '../theme/brand.dart';
import 'add_friend_screen.dart';
import 'friends_screen.dart';
import 'inbox_screen.dart';
import 'notes_from_friends_screen.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _openAddFriend() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddFriendScreen()),
    );
    if (added == true && mounted) _tabs.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            tooltip: 'Add friend',
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: _openAddFriend,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: FlickerColors.primaryBright,
          labelColor: FlickerColors.cream,
          unselectedLabelColor: FlickerColors.muted,
          tabs: const [
            Tab(text: 'People'),
            Tab(text: 'Notes'),
            Tab(text: 'Inbox'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          FriendsScreen(embedded: true),
          NotesFromFriendsScreen(embedded: true),
          InboxScreen(embedded: true),
        ],
      ),
    );
  }
}
