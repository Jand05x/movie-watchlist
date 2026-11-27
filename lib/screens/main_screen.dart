import 'package:flutter/material.dart';

import '../services/repair_service.dart';
import '../theme/brand.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_loading.dart';
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
  bool _repairing = true;
  String? _repairError;

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
    _runRepair();
  }

  Future<void> _runRepair() async {
    setState(() {
      _repairing = true;
      _repairError = null;
    });
    try {
      await RepairService.run();
      if (mounted) setState(() => _repairing = false);
    } catch (error) {
      if (mounted) {
        setState(() {
          _repairError = error.toString();
          _repairing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_repairError != null) {
      return Scaffold(
        body: AppErrorState(
          message: 'Could not prepare your account.\n$_repairError',
          onRetry: _runRepair,
        ),
      );
    }
    if (_repairing) {
      return const Scaffold(body: AppLoading(message: 'Preparing your account...'));
    }

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
