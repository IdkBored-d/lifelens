import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:lifelens/minime_screen.dart';
import 'package:lifelens/profile_screen.dart';
import 'package:lifelens/services/mini_me_suggestions_inbox.dart';
import 'package:lifelens/shared_widgets/bottom_nav.dart';
import 'package:lifelens/community/community_screen.dart';
import 'package:lifelens/screens/log_hub_screen.dart';
import 'package:lifelens/moodlog_store.dart';
import 'package:lifelens/sleep_store.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.userName});

  final String userName;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshSuggestionsInbox());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshSuggestionsInbox(refreshStores: true));
    }
  }

  Future<void> _refreshSuggestionsInbox({bool refreshStores = false}) async {
    final moodStore = context.read<MoodLogStore>();
    final sleepStore = context.read<SleepStore>();

    if (refreshStores) {
      await moodStore.refreshFromPersistence();
      await sleepStore.refresh();
    }

    if (!mounted) return;
    await context.read<MiniMeSuggestionsInbox>().refresh(
      moodStore: moodStore,
      sleepStore: sleepStore,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      MiniMeScreen(userName: widget.userName, isActive: _navIndex == 0),
      LogHubScreen(
        userName: widget.userName,
        onOpenMiniMe: () {
          if (_navIndex != 0) {
            setState(() => _navIndex = 0);
          }
          unawaited(_refreshSuggestionsInbox());
        },
      ),
      const CommunityScreen(),
      const ProfileScreen(),
    ];

    final visiblePages = List<Widget>.generate(pages.length, (index) {
      return TickerMode(enabled: index == _navIndex, child: pages[index]);
    }, growable: false);

    return Scaffold(
      body: IndexedStack(index: _navIndex, children: visiblePages),
      bottomNavigationBar: BottomNav(
        currentIndex: _navIndex,
        onChanged: (i) {
          setState(() => _navIndex = i);
          unawaited(_refreshSuggestionsInbox());
        },
      ),
    );
  }
}
