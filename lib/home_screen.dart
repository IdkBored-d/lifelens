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
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = _buildPages();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userName != widget.userName) {
      _pages = _buildPages();
    }
  }

  List<Widget> _buildPages() {
    return [
      MiniMeScreen(userName: widget.userName),
      LogHubScreen(userName: widget.userName),
      const CommunityScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final pages = List<Widget>.generate(_pages.length, (index) {
      return TickerMode(enabled: index == _navIndex, child: _pages[index]);
    }, growable: false);

    return Scaffold(
      body: IndexedStack(index: _navIndex, children: pages),
      bottomNavigationBar: BottomNav(
        currentIndex: _navIndex,
        onChanged: (i) => setState(() => _navIndex = i),
      ),
    );
  }
}
