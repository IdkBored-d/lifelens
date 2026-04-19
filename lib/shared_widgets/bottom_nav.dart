import 'package:flutter/material.dart';
import 'package:lifelens/services/mini_me_suggestions_inbox.dart';
import 'package:lifelens/shared_widgets/mini_me_profile_icon.dart';
import 'package:provider/provider.dart';

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
          icon: const _MiniMeNavIcon(selected: false),
          selectedIcon: const _MiniMeNavIcon(selected: true),
          label: 'Mini-Me',
        ),

        NavigationDestination(
          icon: const Icon(Icons.add_circle_outline_rounded),
          selectedIcon: const Icon(Icons.add_circle_rounded),
          label: 'Log',
        ),

        NavigationDestination(
          icon: const Icon(Icons.forum_outlined),
          selectedIcon: const Icon(Icons.forum_rounded),
          label: 'Community',
        ),

        NavigationDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings_rounded),
          label: 'Profile',
        ),
      ],
    );
  }
}

class _MiniMeNavIcon extends StatelessWidget {
  const _MiniMeNavIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unreadCount = context.select<MiniMeSuggestionsInbox, int>(
      (inbox) => inbox.unreadCount,
    );

    final badgeLabel = unreadCount > 99 ? '99+' : '$unreadCount';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        MiniMeProfileIcon(
          size: selected ? 30 : 28,
          padding: 2,
          backgroundColor: selected
              ? cs.primaryContainer
              : cs.surfaceContainerHighest,
          borderColor: selected
              ? cs.primary.withValues(alpha: 0.24)
              : cs.outlineVariant.withValues(alpha: 0.45),
        ),
        if (unreadCount > 0)
          Positioned(
            right: -8,
            top: -6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: cs.error,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: cs.surface, width: 1.4),
              ),
              child: Text(
                badgeLabel,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onError,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
