import 'package:flutter/material.dart';

import '../services/user_service.dart';
import '../theme/brand.dart';
import 'discover_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'social_screen.dart';
import 'watchlist_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  late final List<Widget> _pages = [
    const HomeScreen(),
    const DiscoverScreen(),
    const SocialScreen(),
    WatchlistScreen(onOpenDiscover: () => setState(() => _index = 1)),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    UserService.ensureProfile().catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (index) => setState(() => _index = index),
        selectedItemColor: FlickerColors.primaryBright,
        unselectedItemColor: FlickerColors.muted,
        selectedLabelStyle: FlickerText.label,
        unselectedLabelStyle: FlickerText.label,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'Discover',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Friends',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_border),
            activeIcon: Icon(Icons.bookmark),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
