import 'package:flutter/material.dart';

import '../services/user_service.dart';
import 'activity_feed_screen.dart';
import 'add_friend_screen.dart';
import 'friends_screen.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

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
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        title: const Text(
          'Social',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Add friend',
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: _openAddFriend,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color(0xFFE50914),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.people_outline), text: 'Friends'),
            Tab(icon: Icon(Icons.feed_outlined), text: 'Activity'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          FriendsScreen(embedded: true),
          ActivityFeedScreen(embedded: true),
        ],
      ),
    );
  }
}
