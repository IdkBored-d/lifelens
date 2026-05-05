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
  late Animation<Offset> _contentSlide;
  late Animation<double> _splashFade;
  bool _openTriggered = false;
  bool _openComplete = false;

  // Parallel subscriptions used ONLY to trigger the open animation.
  // These are independent from the FutureBuilder/StreamBuilder in _buildContent.
  StreamSubscription<User?>? _authReadySub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docReadySub;

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
  }

  /// Triggers the splash-dissolve animation exactly once, outside of build().
  /// Double addPostFrameCallback ensures content is fully laid out and painted
  /// before any pixel of the splash becomes transparent.
  void _openContent() {
    if (_openTriggered) return;
    _openTriggered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openCtrl.forward().then((_) {
          if (mounted) setState(() => _openComplete = true);
        });
      });
    });
  }

  /// Sets up a one-shot listener chain that calls [_openContent] the first
  /// time the data stack resolves to something renderable. Completely
  /// independent from the FutureBuilder/StreamBuilder used for UI rendering.
  void _listenForReadiness() {
    _initFuture.then((_) {
      if (!mounted) return;
      _authReadySub = FirebaseAuth.instance.authStateChanges().listen(
        (user) {
          if (!mounted) return;
          if (user == null || !user.emailVerified) {
            // Unauthenticated, verification gate, or startup splash — ready.
            _openContent();
            _cancelReadinessListeners();
          } else {
            // Authenticated — wait for first Firestore snapshot.
            _docReadySub?.cancel();
            _docReadySub = FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots()
                .listen(
              (_) {
                if (!mounted) return;
                _openContent();
                _cancelReadinessListeners();
              },
              onError: (_) {
                _openContent();
                _cancelReadinessListeners();
              },
            );
          }
        },
        onError: (_) {
          _openContent();
          _cancelReadinessListeners();
        },
      );
    }).catchError((_) {
      _openContent();
    });
  }

  void _cancelReadinessListeners() {
    _authReadySub?.cancel();
    _authReadySub = null;
    _docReadySub?.cancel();
    _docReadySub = null;
  }

  @override
  void initState() {
    super.initState();
    _openCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    // Content rises subtly — easeOutCubic gives a natural opening feel.
    _contentSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.025),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _openCtrl, curve: Curves.easeOutCubic));
    // Splash holds at full opacity for the first 40% of the animation
    // (240 ms) so content is guaranteed to be painted, then dissolves
    // smoothly with easeIn over the remaining 360 ms.
    _splashFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _openCtrl,
        curve: const Interval(0.40, 1.0, curve: Curves.easeIn),
      ),
    );

    final bootUser = FirebaseAuth.instance.currentUser;
    if (bootUser != null && !bootUser.emailVerified) {
      _verificationGateUserId = bootUser.uid;
      _verificationGateEmail = bootUser.email;
      _verificationGateActive = true;
    }
    _initFuture = initializeApp();
    _listenForReadiness();
  }

  @override
  void dispose() {
    _cancelReadinessListeners();
    _openCtrl.dispose();
    super.dispose();
  }

  Widget _buildContent() {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, initSnapshot) {
        if (initSnapshot.connectionState != ConnectionState.done) {
          // Overlay is still fully opaque — just show the dark bg behind it.
          return const Scaffold(backgroundColor: Color(0xFF0F1014));
        }

        if (initSnapshot.hasError) {
          return _InitErrorScreen(
            error: initSnapshot.error.toString(),
            onRetry: () => setState(() {
              _openTriggered = false;
              _openComplete = false;
              _openCtrl.reset();
              _initFuture = initializeApp();
              _listenForReadiness();
            }),
          );
        }

        if (Firebase.apps.isEmpty) {
          return _FirebaseUnavailableScreen(
            onRetry: () => setState(() {
              _openTriggered = false;
              _openComplete = false;
              _openCtrl.reset();
              _initFuture = initializeApp();
              _listenForReadiness();
            }),
          );
        }

        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(backgroundColor: Color(0xFF0F1014));
            }

            if (!authSnapshot.hasData) {
              _clearHomeCache();
              if (_verificationGateActive && _verificationGateEmail != null) {
                return VerifyEmailScreen(
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
                );
              }
              _verificationGateActive = false;
              _verificationGateUserId = null;
              _verificationGateEmail = null;
              return const StartupSplashScreen();
            }

            final user = authSnapshot.data!;
            final uid = user.uid;

            if (!user.emailVerified) {
              _verificationGateUserId = uid;
              _verificationGateEmail = user.email ?? _verificationGateEmail;
              _verificationGateActive = true;
            }

            if (_verificationGateActive && _verificationGateUserId == uid) {
              return VerifyEmailScreen(
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
              );
            }

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(backgroundColor: Color(0xFF0F1014));
                }

                if (userSnapshot.hasError) {
                  return _UserProfileErrorScreen(
                    message: userSnapshot.error.toString(),
                    onRetry: () => setState(() {}),
                  );
                }

                final doc = userSnapshot.data;
                if (doc == null || !doc.exists) {
                  _clearHomeCache();
                  return const SignupLogin();
                }

                final data = doc.data() ?? <String, dynamic>{};
                final onboardingComplete = data['onboardingComplete'] == true;

                if (!onboardingComplete) {
                  _clearHomeCache();
                  return const IntroScreen();
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
                return _cachedHomeScreen!;
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Solid dark floor prevents any OS background from showing through
    // while the splash dissolves and content is partially transparent.
    return ColoredBox(
      color: const Color(0xFF0F1014),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Content: always full opacity, lifts up as splash dissolves ──
          SlideTransition(
            position: _contentSlide,
            child: _buildContent(),
          ),
          // ── Splash: dissolves out (easeIn) — removed when done ──────────
          if (!_openComplete)
            AnimatedBuilder(
              animation: _splashFade,
              builder: (_, child) =>
                  Opacity(opacity: _splashFade.value, child: child),
              child: const BrandSplashScreen(),
            ),
        ],
      ),
    );
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
