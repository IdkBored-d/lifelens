import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:lifelens/app_services.dart';
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

  static int _lastNavIndex = 0;

  final String userName;

  static void resetCachedNavigation() {
    _lastNavIndex = 0;
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late int _navIndex = HomeScreen._lastNavIndex;
  late final List<bool> _visitedTabs = List<bool>.generate(
    4,
    (index) => index == 0 || index == _navIndex,
    growable: false,
  );
  late final LogHubScreen _logHubScreen = LogHubScreen(
    userName: widget.userName,
    onOpenMiniMe: () {
      _changeTab(0, refreshSuggestions: true);
    },
  );
  late final CommunityScreen _communityScreen = const CommunityScreen();
  late final ProfileScreen _profileScreen = const ProfileScreen();

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
      unawaited(AppServices.fitnessPipeline.score());
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

  void _scheduleSuggestionsRefresh({bool refreshStores = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_refreshSuggestionsInbox(refreshStores: refreshStores));
    });
  }

  void _changeTab(int index, {bool refreshSuggestions = false}) {
    if (_navIndex == index) {
      if (refreshSuggestions && index == 0) {
        _scheduleSuggestionsRefresh();
      }
      return;
    }

    setState(() {
      _navIndex = index;
      HomeScreen._lastNavIndex = index;
      _visitedTabs[index] = true;
    });

    if (refreshSuggestions && index == 0) {
      _scheduleSuggestionsRefresh();
    }
  }

  Widget _buildPageForIndex(int index) {
    switch (index) {
      case 0:
        return MiniMeScreen(
          userName: widget.userName,
          isActive: _navIndex == 0,
        );
      case 1:
        return _logHubScreen;
      case 2:
        return _communityScreen;
      case 3:
      default:
        return _profileScreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visiblePages = List<Widget>.generate(_visitedTabs.length, (index) {
      final child = _visitedTabs[index]
          ? _buildPageForIndex(index)
          : const SizedBox.shrink();
      return TickerMode(enabled: index == _navIndex, child: child);
    }, growable: false);

    return Scaffold(
      resizeToAvoidBottomInset: _navIndex != 0,
      body: IndexedStack(index: _navIndex, children: visiblePages),
      bottomNavigationBar: BottomNav(
        currentIndex: _navIndex,
        onChanged: (i) {
          _changeTab(i, refreshSuggestions: i == 0);
        },
      ),
    );
  }
}
