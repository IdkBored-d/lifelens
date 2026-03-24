import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'moodlog_store.dart';
import './assets/minime/minime_avatar.dart';
import 'package:lifelens/utils/minime_helpers.dart';
import 'avatar_store.dart';
import 'avatar_customization_screen.dart';

class MiniMeScreen extends StatelessWidget {
  const MiniMeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Mini-Me")),
      body: Consumer2<MoodLogStore, AvatarStore>(
        builder: (context, moodStore, avatarStore, _) {
          final latest = moodStore.items.isEmpty ? null : moodStore.items.first;
          final intensity = latest?.intensity ?? 0;
          final glow = glowForIntensity(theme.colorScheme, intensity);

          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.surface,
                  cs.surfaceContainerHighest,
                ],
              ),
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final avatarSize = (constraints.biggest.shortestSide * 0.9)
                      .clamp(280.0, 760.0);

                  return Stack(
                    children: [
                      Center(
                        child: MiniMeAvatar(
                          bodyModel: avatarStore.bodyModel,
                          hairModel: avatarStore.hairModel,
                          shirtModel: avatarStore.shirtModel,
                          moodLabel: latest?.moodLabel,
                          glow: glow,
                          size: avatarSize,
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 18,
                        child: Center(
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const AvatarCustomizationScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.edit_rounded),
                            label: const Text('Customize Avatar'),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
