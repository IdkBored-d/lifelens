import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/SignupLogin.dart';
import '../loading_screen.dart';
import '../HomeScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../intro_screen.dart';
import '../auth/verifyemail_screen.dart';
import 'app_init.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = initializeApp();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, initSnapshot) {
        if (initSnapshot.connectionState != ConnectionState.done) {
          return const LoadingScreen();
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
