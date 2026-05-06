import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../auth/signup_login.dart';
import '../home_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../intro_screen.dart';
import '../auth/verifyemail_screen.dart';
import 'app_init.dart';
import '../screens/brand_splash_screen.dart';
import '../screens/startup_splash_screen.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with SingleTickerProviderStateMixin {
  late Future<void> _initFuture;
  late AnimationController _openCtrl;
  late Animation<double> _splashFade;
  late Animation<double> _contentFade;
  late Animation<double> _contentScale;
  bool _openTriggered = false;

  String? _cachedHomeUserId;
  String? _cachedHomeUserName;
  Widget? _cachedHomeScreen;
  String? _verificationGateUserId;
  String? _verificationGateEmail;
  bool _verificationGateActive = false;

  void _clearHomeCache() {
    _cachedHomeUserId = null;
    _cachedHomeUserName = null;
    _cachedHomeScreen = null;
    HomeScreen.resetCachedNavigation();
  }

  /// Triggers the splash-dissolve animation exactly once, outside of build().
  /// Runs on next frame once so content is painted before splash transparency starts.
  void _openContent() {
    if (_openTriggered) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_openTriggered) return;
      setState(() => _openTriggered = true);
      _openCtrl.forward();
    });
  }

  Widget _ready(Widget child) {
    _openContent();
    return child;
  }

  @override
  void initState() {
    super.initState();
    _openCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    // Hold briefly, then crossfade content in under the splash.
    _splashFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _openCtrl,
        curve: const Interval(0.10, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _contentFade = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _openCtrl,
        curve: const Interval(0.10, 0.88, curve: Curves.easeOutCubic),
      ),
    );
    _contentScale = Tween<double>(begin: 0.992, end: 1.0).animate(
      CurvedAnimation(
        parent: _openCtrl,
        curve: const Interval(0.10, 0.90, curve: Curves.easeOutCubic),
      ),
    );

    final bootUser = FirebaseAuth.instance.currentUser;
    if (bootUser != null && !bootUser.emailVerified) {
      _verificationGateUserId = bootUser.uid;
      _verificationGateEmail = bootUser.email;
      _verificationGateActive = true;
    }
    _initFuture = initializeApp();
  }

  @override
  void dispose() {
    _openCtrl.dispose();
    super.dispose();
  }

  Widget _buildContent() {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, initSnapshot) {
        if (initSnapshot.connectionState != ConnectionState.done) {
          return const _BootPlaceholder();
        }

        if (initSnapshot.hasError) {
          return _ready(
            _InitErrorScreen(
              error: initSnapshot.error.toString(),
              onRetry: () => setState(() {
                _openTriggered = false;
                _openCtrl.reset();
                _initFuture = initializeApp();
              }),
            ),
          );
        }

        if (Firebase.apps.isEmpty) {
          return _ready(
            _FirebaseUnavailableScreen(
              onRetry: () => setState(() {
                _openTriggered = false;
                _openCtrl.reset();
                _initFuture = initializeApp();
              }),
            ),
          );
        }

        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const _BootPlaceholder();
            }

            if (!authSnapshot.hasData) {
              _clearHomeCache();
              if (_verificationGateActive && _verificationGateEmail != null) {
                return _ready(
                  VerifyEmailScreen(
                    email: _verificationGateEmail!,
                    onVerifiedConfirmed: () {
                      if (!mounted) return;
                      setState(() {
                        _verificationGateActive = false;
                        _verificationGateUserId = null;
                        _verificationGateEmail = null;
                      });
                      FirebaseAuth.instance.signOut();
                    },
                    onUseAnotherAccount: () {
                      if (!mounted) return;
                      setState(() {
                        _verificationGateActive = false;
                        _verificationGateUserId = null;
                        _verificationGateEmail = null;
                      });
                      FirebaseAuth.instance.signOut();
                    },
                  ),
                );
              }
              _verificationGateActive = false;
              _verificationGateUserId = null;
              _verificationGateEmail = null;
              return _ready(const StartupSplashScreen());
            }

            final user = authSnapshot.data!;
            final uid = user.uid;

            if (!user.emailVerified) {
              _verificationGateUserId = uid;
              _verificationGateEmail = user.email ?? _verificationGateEmail;
              _verificationGateActive = true;
            }

            if (_verificationGateActive && _verificationGateUserId == uid) {
              return _ready(
                VerifyEmailScreen(
                  email: user.email ?? '',
                  onVerifiedConfirmed: () {
                    if (!mounted) return;
                    setState(() => _verificationGateActive = false);
                  },
                  onUseAnotherAccount: () {
                    if (!mounted) return;
                    setState(() {
                      _verificationGateActive = false;
                      _verificationGateUserId = null;
                      _verificationGateEmail = null;
                    });
                  },
                ),
              );
            }

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const _BootPlaceholder();
                }

                if (userSnapshot.hasError) {
                  return _ready(
                    _UserProfileErrorScreen(
                      message: userSnapshot.error.toString(),
                      onRetry: () => setState(() {}),
                    ),
                  );
                }

                final doc = userSnapshot.data;
                if (doc == null || !doc.exists) {
                  _clearHomeCache();
                  return _ready(const SignupLogin());
                }

                final data = doc.data() ?? <String, dynamic>{};
                final onboardingComplete = data['onboardingComplete'] == true;

                if (!onboardingComplete) {
                  _clearHomeCache();
                  return _ready(const IntroScreen());
                }

                final userName = (data['firstName'] ?? 'Friend').toString();
                if (_cachedHomeScreen == null ||
                    _cachedHomeUserId != uid ||
                    _cachedHomeUserName != userName) {
                  _cachedHomeUserId = uid;
                  _cachedHomeUserName = userName;
                  _cachedHomeScreen = HomeScreen(
                    key: ValueKey('home-$uid'),
                    userName: userName,
                  );
                }
                return _ready(_cachedHomeScreen!);
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Solid theme floor prevents any OS background from showing through
    // while the splash dissolves and content is partially transparent.
    final floorColor = Theme.of(context).scaffoldBackgroundColor;
    return ColoredBox(
      color: floorColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Content: always painted under the splash overlay ───────────
          AnimatedBuilder(
            animation: _openCtrl,
            child: RepaintBoundary(child: _buildContent()),
            builder: (context, child) {
              return Opacity(
                opacity: _openTriggered ? _contentFade.value : 1,
                child: Transform.scale(
                  scale: _openTriggered ? _contentScale.value : 1,
                  child: child,
                ),
              );
            },
          ),
          // ── Splash: fades to transparent but stays mounted, preventing
          // the one-frame flash that can happen when removing the overlay.
          IgnorePointer(
            ignoring: _openTriggered,
            child: AnimatedBuilder(
              animation: _splashFade,
              builder: (_, child) =>
                  Opacity(opacity: _splashFade.value, child: child),
              child: const BrandSplashScreen(),
            ),
          ),
        ],
      ),
    );
  }
}

class _BootPlaceholder extends StatelessWidget {
  const _BootPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: Theme.of(context).scaffoldBackgroundColor);
  }
}

class _UserProfileErrorScreen extends StatelessWidget {
  const _UserProfileErrorScreen({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Could not load your profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

class _InitErrorScreen extends StatelessWidget {
  const _InitErrorScreen({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Failed to start LifeLens',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

class _FirebaseUnavailableScreen extends StatelessWidget {
  const _FirebaseUnavailableScreen({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Firebase Not Configured',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'This build is missing Firebase configuration for this platform.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}
