import 'package:flutter/material.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF6FBFF),
              Color(0xFFF4F3FF),
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder (
            animation: _controller,
            builder: (_, child) {
              final scale = 1.0 + (_controller.value * 0.05);
              return Transform.scale(scale: scale, child: child);
            },

            child: Column (
              mainAxisSize: MainAxisSize.min,
              children : [
                _LogoCard (theme: theme),
                const SizedBox(height: 20),
                Text (
                  "Preparing your space...",
                  style: theme.textTheme.bodyMedium?.copyWith (
                    color: const Color (0xFF5A5A66),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoCard extends StatelessWidget {
  const _LogoCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container (
      width: 120,
      height: 120,
      decoration: BoxDecoration (
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow (
            blurRadius: 30,
            color: theme.colorScheme.primary.withOpacity(0.18),
            offset: const Offset(0, 12),
          ),
        ],
      ),

      child: Icon (
        Icons.spa_rounded,
        size: 56,
        color: theme.colorScheme.primary,
      ),
    );
  }
}
