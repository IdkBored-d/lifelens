import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lifelens/moodlog_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int _selectedMood = -1;
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // UI-only: swap these to route later
    final pages = <Widget>[
      _HomeDashboard(
        selectedMood: _selectedMood,
        onMoodSelected: (i) => setState(() => _selectedMood = i),
      ),
      const MoodLogScreen(source: LogSource.tab),
      const _PlaceholderPage(title: "Mini-Me"),
      const _PlaceholderPage(title: "Community"),
      const _PlaceholderPage(title: "Profile"),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.primaryContainer.withOpacity(0.22),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(child: pages[_navIndex]),
      ),
      bottomNavigationBar: _LifeLensBottomNav(
        currentIndex: _navIndex,
        onChanged: (i) => setState(() => _navIndex = i),
      ),
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({
    required this.selectedMood,
    required this.onMoodSelected,
  });

  final int selectedMood;
  final ValueChanged<int> onMoodSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GreetingHeader(
            name: "Matthew", // UI-only: replace with user profile later
            subtitle: "How are you feeling today?",
          ),
          const SizedBox(height: 14),

          // Mini-Me hero
          _MiniMeHeroCard(
            title: "Mini-Me",
            moodLabel: selectedMood == -1
                ? "Tap an emotion to check-in"
                : _moods[selectedMood].label,
            statusLine: selectedMood == -1 ? "Energy: —" : "Energy: Balanced",
          ),
          const SizedBox(height: 14),

          // Emotion check-in
          _SectionTitle(title: "Emotion check-in", trailing: "Today"),
          const SizedBox(height: 10),
          _MoodRow(selected: selectedMood, onSelect: onMoodSelected),
          const SizedBox(height: 18),

          // Quick actions
          _SectionTitle(title: "Quick actions"),
          const SizedBox(height: 10),
          _QuickActionsGrid(
            actions: [
              _QuickAction(
                icon: Icons.emoji_emotions_outlined,
                label: "Mood Log",
                onTap: (){
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MoodLogScreen(),
                    ),
                  );
                }
              ),
              _QuickAction(
                icon: Icons.nightlight_round,
                label: "Sleep",
                onTap: () => _toast(context, "Sleep (UI only)"),
              ),
              _QuickAction(
                icon: Icons.fitness_center_outlined,
                label: "Exercise",
                onTap: () => _toast(context, "Exercise (UI only)"),
              ),
              _QuickAction(
                icon: Icons.healing_outlined,
                label: "Symptoms",
                onTap: () => _toast(context, "Symptoms (UI only)"),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Insights preview
          _SectionTitle(title: "Today’s insight", trailing: "Preview"),
          const SizedBox(height: 10),
          _InsightCard(
            title: "You’re building consistency 🌿",
            body:
                "On days you sleep 7+ hours, your mood trends more positive. Try a 10-minute wind-down tonight.",
          ),

          const SizedBox(height: 16),

          _ContextualSuggestions(
            moodLabel: selectedMood == -1
              ? "Neutral" : _moods[selectedMood].label,
          ),
          const SizedBox(height: 16),

          // Optional: streak / summary strip
          _SummaryStrip(
            items: const [
              _SummaryItem(
                title: "Check-ins",
                value: "3",
                icon: Icons.favorite_rounded,
              ),
              _SummaryItem(
                title: "Sleep",
                value: "6h 40m",
                icon: Icons.nightlight_round,
              ),
              _SummaryItem(
                title: "Steps",
                value: "4,821",
                icon: Icons.directions_walk_rounded,
              ),
            ],
          ),

          const SizedBox(height: 8),
          Divider(color: cs.outlineVariant.withOpacity(0.7)),
          const SizedBox(height: 10),

          // Small “continue” card
          _ContinueCard(
            title: "Continue where you left off",
            subtitle: "Review your week’s mood trend",
            onTap: () => _toast(context, "Trends (UI only)"),
          ),
        ],
      ),
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 900),
      ),
    );
  }
}

class _ContextualSuggestions extends StatelessWidget{
  const _ContextualSuggestions({
    required this.moodLabel,
  });
  final String moodLabel;

  @override
  Widget build(BuildContext context){
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final suggestions = _suggestionsForMood(moodLabel);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Suggested for you",
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          ...suggestions.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SuggestionTile(
                icon: s.icon,
                text: s.text,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("${s.text} (UI Only)"),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(milliseconds: 900),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
  List<_Suggestion> _suggestionsForMood(String mood){
    final m = mood.toLowerCase();

    if(m.contains("calm")){
      return const [
        _Suggestion(
          icon: Icons.self_improvement_rounded,
          text: "Maintain your calm with a 2-minute breathing exercise",
        ),

        _Suggestion(
          icon: Icons.bookmark_border_rounded,
          text: "Reflect briefly on what's helping you feel balanced",
        ),
      ];
    }

    if(m.contains("anxious") || m.contains("stress")){
      return const[
        _Suggestion(
          icon: Icons.air_rounded,
          text: "Try a short grounding breathing exercise",
        ),
      ];
    }

     if(m.contains("sad")){
      return const[
        _Suggestion(
          icon: Icons.favorite_border_rounded,
          text: "Be a little kinder to yourself - take it one day at a time",
        ),
      ];
    }

    if(m.contains("happy")){
      return const[
        _Suggestion(
          icon: Icons.thumbs_up_down,
          text: "Glad to know your feeling well today!"
        ),
      ];
    }
    return const[
      _Suggestion(
        icon: Icons.track_changes_rounded,
        text: "Check in later for any changes",
      ),
      _Suggestion(
        icon: Icons.insights_outlined,
        text: "Make sure you log everyday to understand your patterns",
      ),
    ];
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.name, required this.subtitle});

  final String name;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final now = DateTime.now();
    final greeting = _dayGreeting(now.hour);
    final dateText = _dateLine(now);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$greeting, $name",
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                dateText,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _SoftIconButton(
          icon: Icons.notifications_none_rounded,
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Notifications (UI only)"),
              behavior: SnackBarBehavior.floating,
              duration: Duration(milliseconds: 900),
            ),
          ),
        ),
      ],
    );
  }

  String _dayGreeting(int hour) {
    if (hour < 12) return "Good morning";
    if (hour < 18) return "Good afternoon";
    return "Good evening";
  }

  String _dateLine(DateTime dt) {
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];
    const weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    final wd = weekdays[(dt.weekday - 1).clamp(0, 6)];
    return "$wd • ${months[dt.month - 1]} ${dt.day}";
  }
}

class _MiniMeHeroCard extends StatelessWidget {
  const _MiniMeHeroCard({
    required this.title,
    required this.moodLabel,
    required this.statusLine,
  });

  final String title;
  final String moodLabel;
  final String statusLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final Color stateColor = _stateColorFromMood(moodLabel, cs);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primaryContainer.withOpacity(0.55),
            cs.secondaryContainer.withOpacity(0.45),
            cs.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Mini-Me placeholder (swap for ModelViewer later)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: stateColor,
              boxShadow: [
                BoxShadow(
                  color: stateColor.withOpacity(0.28),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.surface,
                border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
              ),
              child: Icon(
                Icons.person_rounded,
                size: 44,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  moodLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(text: statusLine, icon: Icons.bolt_rounded),
                    _Pill(text: "Sync: Ready", icon: Icons.cloud_done_outlined),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _SoftIconButton(
            icon: Icons.chevron_right_rounded,
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Mini-Me details (UI only)"),
                behavior: SnackBarBehavior.floating,
                duration: Duration(milliseconds: 900),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Color _stateColorFromMood(String moodLabel, ColorScheme cs) {
    final m = moodLabel.toLowerCase();

    if(m.contains("calm")) return Color(0xFFb4A6E6);
    if(m.contains("happy") || m.contains("joy")) return Colors.greenAccent;
    if(m.contains("sad")) return Colors.redAccent;
    if(m.contains("neutral")) return Color(0xFF8C91A8);
    if(m.contains("anxious") || m.contains("stress")) return Colors.orangeAccent;


    return cs.primary;
  }
}

class _MoodRow extends StatelessWidget {
  const _MoodRow({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(_moods.length, (i) {
          final mood = _moods[i];
          final isSelected = i == selected;

          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                HapticFeedback.mediumImpact();
                onSelect(i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                transform: isSelected
                    ? (Matrix4.identity()..scale(1.05))
                    : Matrix4.identity(),
                padding: const EdgeInsets.symmetric(vertical: 10),
                margin: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? cs.primaryContainer.withOpacity(0.75)
                      : cs.surface.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? cs.primary.withOpacity(0.55)
                        : cs.outlineVariant.withOpacity(0.6),
                  ),
                ),
                child: Column(
                  children: [
                    Text(mood.emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 6),
                    Text(
                      mood.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: isSelected
                            ? cs.onPrimaryContainer
                            : cs.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.actions});

  final List<_QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (context, i) {
        final a = actions[i];
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: a.onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: cs.outlineVariant.withOpacity(0.35),
                    ),
                  ),
                  child: Icon(a.icon, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    a.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withOpacity(0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.65),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
            ),
            child: Icon(Icons.lightbulb_outline_rounded, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({super.key, required this.items});
  final List<_SummaryItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      child: Row(
        children: items
            .map(
              (it) => Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(it.icon, size: 18, color: cs.primary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      it.value,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      it.title,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.tertiaryContainer.withOpacity(0.55),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
              ),
              child: Icon(Icons.timeline_rounded, color: cs.tertiary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _LifeLensBottomNav extends StatelessWidget {
  const _LifeLensBottomNav({
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
      backgroundColor: cs.surface.withOpacity(0.95),
      indicatorColor: cs.primaryContainer.withOpacity(0.7),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: "Home",
        ),
        NavigationDestination(
          icon: Icon(Icons.add_circle_outline_rounded),
          selectedIcon: Icon(Icons.add_circle_rounded),
          label: "Log",
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: "Mini-Me",
        ),
        NavigationDestination(
          icon: Icon(Icons.forum_outlined),
          selectedIcon: Icon(Icons.forum_rounded),
          label: "Community",
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings_rounded),
          label: "Profile",
        ),
      ],
    );
  }
}

class _SoftIconButton extends StatelessWidget {
  const _SoftIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
        ),
        child: Icon(icon, color: cs.onSurfaceVariant),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.icon});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: theme.textTheme.labelLarge?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        "$title (UI only)",
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _QuickAction {
  _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _SummaryItem {
  const _SummaryItem({
    required this.title,
    required this.value,
    required this.icon,
  });
  final String title;
  final String value;
  final IconData icon;
}

class _Mood {
  const _Mood(this.emoji, this.label);
  final String emoji;
  final String label;
}

class _Suggestion {
  const _Suggestion({
    required this.icon,
    required this.text,
  });
  final IconData icon;
  final String text;
}

class _SuggestionTile extends StatelessWidget{
  const _SuggestionTile({
    required this.icon,
    required this.text,
    required this.onTap,
  });
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context){
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
const _moods = <_Mood>[
  _Mood("😊", "Happy"),
  _Mood("😌", "Calm"),
  _Mood("😐", "Neutral"),
  _Mood("😟", "Anxious"),
  _Mood("😞", "Sad"),
];

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 900),
    ),
  );
}
