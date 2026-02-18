import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'restart.dart';
import 'settings_screen.dart';
import 'preferences_screen.dart';
import 'privacy_screen.dart';
import 'package:provider/provider.dart';
import 'theme_controller.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final themeController = context.watch<ThemeController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), centerTitle: true),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.person,
                      size: 48,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),

                  const SizedBox(height: 13),
                  Text(
                    user?.email ?? 'No email',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            _ProfileSection(
              title: 'Account',
              children: [
                _ProfileTile(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: user?.email ?? 'Not available',
                ),

                _ProfileTile(
                  icon: Icons.lock_outline,
                  label: 'Password',
                  value: user?.providerData.first.providerId ?? 'Email',
                ),
              ],
            ),

            const SizedBox(height: 24),

            _ProfileSection(
              title: 'Preferences',
              children: [
                _ProfileTile(
                  icon: Icons.spa_outlined,
                  label: 'Calm mode',
                  value: themeController.isCalmMode ? 'Enabled' : 'Off',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PreferencesScreen(),
                      ),
                    );
                  },
                ),

                _ProfileTile(
                  icon: Icons.notifications_none,
                  label: 'Notifications',
                  value: 'On',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),

                _ProfileTile(
                  icon: Icons.accessibility_new,
                  label: 'Accessibility',
                  value: 'Standard',
                ),
              ],
            ),

            _ProfileSection(
              title: 'Actions',
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Log out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),

                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    RestartWidget.restartApp(context);
                  },
                ),

                const SizedBox(height: 12),

                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset preferences'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),

                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ProfileSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),

          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 22, color: theme.colorScheme.primary),
            const SizedBox(width: 12),

            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),

            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
