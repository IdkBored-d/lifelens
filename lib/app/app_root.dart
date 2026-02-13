import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lifelens/widgets/home_dashboard.dart';
import '../auth/SignupLogin.dart';
import '../loading_screen.dart';
import '../HomeScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../intro_screen.dart';
import '../auth/verifyemail_screen.dart';
import 'app_init.dart';

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void> (
      future: initializeApp(),
      builder: (context, initSnapshot) {
        if (initSnapshot.connectionState != ConnectionState.done)  {
          return const LoadingScreen();
        }

        return StreamBuilder<User?> (
          stream: FirebaseAuth.instance.authStateChanges(),
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

            return FutureBuilder<DocumentSnapshot> (
              future: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingScreen();
                }

                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return const LoadingScreen();
                }

                final data = 
                  userSnapshot.data!.data() as Map<String, dynamic>;
                final onboardingComplete = 
                  data['onboardingComplete'] ?? false;

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