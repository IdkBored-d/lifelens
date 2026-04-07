import 'package:firebase_auth/firebase_auth.dart';

Future<void> initializeApp() async {
  await FirebaseAuth.instance.authStateChanges().first;
}
