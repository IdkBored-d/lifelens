import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/SignupLogin.dart';
import '../loading_screen.dart';
import '../HomeScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../intro_screen.dart';
import '../auth/verifyemail_screen.dart';
import 'app_init.dart';
import '../screens/gemma_setup_screen.dart';
import '../app_services.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  late final Future<bool> _initFuture;
  bool _gemmaSetupDone = false;

  Future<bool> _buildInitFuture() => initializeApp().then((_) {
        final isLoaded = AppServices.isGemmaLoaded;
        final showSetup = !isLoaded;
        debugPrint('[AppRoot] Gemma: isLoaded=$isLoaded showSetup=$showSetup');
        return showSetup;
      }).catchError((Object e) {
        debugPrint('[AppRoot] initializeApp() error: $e');
        throw e;
      });

  @override
  void initState() {
    super.initState();
    debugPrint('[AppRoot] initState() called');
    _initFuture = _buildInitFuture();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _initFuture,
      builder: (context, initSnapshot) {
        if (initSnapshot.connectionState != ConnectionState.done) {
          return const LoadingScreen();
        }

        if (initSnapshot.hasError) {
          return _InitErrorScreen(
            error: initSnapshot.error.toString(),
            onRetry: () => setState(() {
              _gemmaSetupDone = false;
              _initFuture = _buildInitFuture();
            }),
          );
        }

        final showSetup = initSnapshot.data ?? false;
        debugPrint('[AppRoot] Build: showSetup=$showSetup, _gemmaSetupDone=$_gemmaSetupDone');
        if (showSetup && !_gemmaSetupDone) {
          debugPrint('[AppRoot] → Showing GemmaSetupScreen');
          return GemmaSetupScreen(
            onComplete: () => setState(() => _gemmaSetupDone = true),
          );
        }

        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.idTokenChanges(),
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const LoadingScreen();
            }

            if (!authSnapshot.hasData) {
              return const SignupLogin();
            }

            final user = authSnapshot.data!;

            if (!user.emailVerified) {
              return VerifyEmailScreen(email: user.email ?? '');
            }

            final uid = user.uid;

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingScreen();
                }

                if (userSnapshot.hasError) {
                  return const IntroScreen();
                }

                final doc = userSnapshot.data;
                if (doc == null || !doc.exists) {
                  return const IntroScreen();
                }

                final data = doc.data() ?? <String, dynamic>{};
                final onboardingComplete = data['onboardingComplete'] == true;

                if (!onboardingComplete) {
                  return const IntroScreen();
                }

                final userName = data['firstName'] ?? 'Friend';
                return HomeScreen(userName: userName);
              },
            );
          },
        );
      },
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
