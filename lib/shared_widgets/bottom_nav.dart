import 'package:flutter/material.dart';
import 'package:lifelens/shared_widgets/mini_me_profile_icon.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onChanged,
      backgroundColor: cs.surface.withValues(alpha: 0.95),
      indicatorColor: cs.primaryContainer.withValues(alpha: 0.7),
      destinations: [
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Mini-Me',
        ),

        NavigationDestination(
          icon: Icon(Icons.add_circle_outline_rounded),
          selectedIcon: Icon(Icons.add_circle_rounded),
          label: 'Log',
        ),

        NavigationDestination(
          icon: Icon(Icons.forum_outlined),
          selectedIcon: Icon(Icons.forum_rounded),
          label: 'Community',
        ),

        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: MiniMeProfileIcon(size: 28, padding: 2),
          label: 'Profile',
        ),
      ],
    );
  }
}
