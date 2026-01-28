import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {

  final PageController _controller = PageController();
  int _index = 0;

  final List<_IntroPageData> _pages = const [
    _IntroPageData(
      title: "Welcome to LifeLens",
      subtitle: "A calm space to track your wellness—one day at a time.",
      icon: Icons.spa_rounded,
    ),
    _IntroPageData(
      title: "Track what matters",
      subtitle: "Log mood, sleep, activity, and symptoms with quick, simple inputs.",
      icon: Icons.favorite_rounded,
    ),
    _IntroPageData(
      title: "See your progress",
      subtitle: "Turn daily habits into insights and gentle next steps.",
      icon: Icons.insights_rounded,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _goNext() async {
    if (_index < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
    else {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'onboardingComplete': true});
    }
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
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _Pill(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.spa_rounded, size: 18),
                          SizedBox(width: 8),
                          Text("LifeLens", style: TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _goNext,
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                      ),
                      child: const Text("Skip"),
                    ),
                  ],
                ),
              ),

              // Pages
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final p = _pages[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Icon hero
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(36),
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 30,
                                  spreadRadius: 2,
                                  color: Colors.black.withOpacity(0.06),
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Icon(
                              p.icon,
                              size: 64,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            p.title,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1C1C1E),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            p.subtitle,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              height: 1.35,
                              color: const Color(0xFF5A5A66),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  children: [
                    _Dots(count: _pages.length, index: _index),
                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF2EC4B6), // teal
                              Color(0xFF3A86FF), // blue
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 20,
                              color: Colors.black.withOpacity(0.10),
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _goNext,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            _index == _pages.length - 1 ? "Get started" : "Next",
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    if (_index > 0)
                      TextButton(
                        onPressed: () {
                          _controller.previousPage(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOut,
                          );
                        },
                        child: const Text("Back"),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroPageData {
  final String title;
  final String subtitle;
  final IconData icon;
  const _IntroPageData({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: active ? Theme.of(context).colorScheme.primary : Colors.black12,
          ),
        );
      }),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: child,
    );
  }
}
