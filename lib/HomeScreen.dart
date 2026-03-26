import 'package:flutter/material.dart';
import 'package:lifelens/minime_screen.dart';
import 'package:lifelens/profile_screen.dart';
import 'package:lifelens/shared_widgets/bottom_nav.dart';
import 'package:lifelens/community/community_screen.dart';
import 'package:lifelens/screens/log_hub_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.userName});

  final String userName;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const MiniMeScreen(),
      LogHubScreen(userName: widget.userName),
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
