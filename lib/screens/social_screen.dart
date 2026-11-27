import 'package:flutter/material.dart';

import '../services/user_service.dart';
import '../theme/brand.dart';
import 'activity_feed_screen.dart';
import 'add_friend_screen.dart';
import 'friends_screen.dart';
import 'inbox_screen.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void initState() {
    super.initState();
    UserService.ensureProfile().catchError((_) => null);
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
            Tab(text: 'Circle'),
            Tab(text: 'Inbox'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          FriendsScreen(embedded: true),
          ActivityFeedScreen(embedded: true),
          InboxScreen(),
        ],
      ),
    );
  }
}
