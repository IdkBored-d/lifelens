import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_controller.dart';

class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeController = context.watch<ThemeController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Preferences')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ---------- Calm Mode Card ----------
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      Icon(
                        Icons.spa_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Text('Calm Mode', style: theme.textTheme.titleMedium),
                      const Spacer(),
                      Switch(
                        value: themeController.isCalmMode,
                        onChanged: (value) =>
                            context.read<ThemeController>().setCalmMode(value),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Default is Dark Mode. Calm Mode switches to the soft palette shown here.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Benefits list
                  _CalmFeature(
                    icon: Icons.palette_outlined,
                    text: 'Softer colors and contrast',
                  ),
                  _CalmFeature(
                    icon: Icons.motion_photos_off_outlined,
                    text: 'Reduced animations',
                  ),
                  _CalmFeature(
                    icon: Icons.notifications_none,
                    text: 'Fewer notifications',
                  ),
                  _CalmFeature(
                    icon: Icons.layers_clear_outlined,
                    text: 'Simplified screens',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // ---------- Optional Calm Preferences ----------
          Text(
            'Calm preferences',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          _PreferenceTile(
            icon: Icons.schedule_outlined,
            title: 'Quiet hours',
            subtitle: 'Reduce notifications at certain times',
          ),
          _PreferenceTile(
            icon: Icons.volume_off_outlined,
            title: 'Low-stimulation mode',
            subtitle: 'Limit visual and sensory input',
          ),
          _PreferenceTile(
            icon: Icons.remove_red_eye_outlined,
            title: 'Visual simplicity',
            subtitle: 'Hide non-essential UI elements',
          ),
        ],
      ),
    );
  }
}

class _CalmFeature extends StatelessWidget {
  final IconData icon;
  final String text;

  const _CalmFeature({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _PreferenceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PreferenceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {},
      ),
    );
  }
}
