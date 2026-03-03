import 'package:flutter/material.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({required this.currentIndex, required this.onChanged,});

  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return NavigationBar (
      selectedIndex: currentIndex,
      onDestinationSelected: onChanged,
      backgroundColor: cs.surface.withOpacity(0.95),
      indicatorColor: cs.primaryContainer.withOpacity(0.7),
      destinations: const [
        NavigationDestination (
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),

        NavigationDestination (
          icon: Icon(Icons.add_circle_outline_rounded),
          selectedIcon: Icon(Icons.add_circle_rounded),
          label: 'Log',
        ),

        NavigationDestination (
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Mini-Me',
        ),

        NavigationDestination (
          icon: Icon(Icons.forum_outlined),
          selectedIcon: Icon(Icons.forum_rounded),
          label: 'Community',
        ),

        NavigationDestination (
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings_rounded),
          label: 'Pofile'
        ),
      ],
    );
  }
}