import 'package:flutter/material.dart';
import 'package:lifelens/moodlog_screen.dart';
import 'package:lifelens/minime_screen.dart';
import 'package:lifelens/profile_screen.dart';
import 'package:lifelens/shared_widgets/bottom_nav.dart';
import 'package:lifelens/widgets/home_dashboard.dart';
import 'package:lifelens/community/community_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.userName});

  final String userName;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedMood = -1;
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeDashboard(
        userName: widget.userName,
        selectedMood: _selectedMood,
        onMoodSelected: (i) => setState(() => _selectedMood = i),
        onOpenMiniMe: () => setState(() => _navIndex = 2),
      ),
      const MoodLogScreen(source: LogSource.tab),
      const MiniMeScreen(),
      const CommunityScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_navIndex]),
      bottomNavigationBar: BottomNav(
        currentIndex: _navIndex,
        onChanged: (i) => setState(() => _navIndex = i),
      ),
    );
  }
}
