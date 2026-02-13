import 'package:flutter/material.dart';
import 'package:lifelens/shared_widgets/soft_icon_button.dart';

class GreetingHeader extends StatelessWidget {

  const GreetingHeader({required this.name, required this.subtitle});

  final String name;
  final String subtitle;
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final now = DateTime.now();
    final greeting = _dayGreeting(now.hour);
    final dateText = _dateLine(now);

    return Row (
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded (
          child: Column (
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text (
                '$greeting, $name',
                style: theme.textTheme.headlineSmall?.copyWith (
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),

              const SizedBox(height: 4),
              Text (
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith (
                  color: cs.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 6),
              Text (
                dateText,
                style: theme.textTheme.labelLarge?.copyWith (
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),
        SoftIconButton(
          icon: Icons.notifications_none_rounded, 
          onTap: () => ScaffoldMessenger.of(context).showSnackBar (
            const SnackBar (
              content: Text('Notifications (UI Only)'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(milliseconds: 900),
            ),
          ),
        ),
      ],
    );
  }

  String _dayGreeting(int hour) {
    if(hour < 12) return 'Good Morning';
    if(hour < 18) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _dateLine(DateTime dt) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
  ];
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final wd = weekdays[(dt.weekday - 1).clamp(0,6)];
  return '$wd • ${months[dt.month - 1]} ${dt.day}';
  }
}
