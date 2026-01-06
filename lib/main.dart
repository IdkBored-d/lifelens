//FAST TESTING PURPOSES
import 'package:flutter/material.dart';
import 'package:lifelens/HomeScreen.dart';
import 'package:lifelens/lifelens_theme.dart';
// import your theme file if needed
// import 'package:lifelens/LifeLens.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: lifeLensCalmTheme(),
      home: const MenuScreen(),
    );
  }
}








// import 'package:flutter/material.dart';
// import 'package:lifelens/HomeScreen.dart';
// import 'package:lifelens/SignupLogin.dart';
// import 'intro_screen.dart'; // change path if your intro file is elsewhere

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: const AppRoot(),
//     );
//   }
// }

// class AppRoot extends StatelessWidget {
//   const AppRoot({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return IntroScreen(
//       onGetStarted: () {
//         Navigator.of(context).pushReplacement(
//           MaterialPageRoute(
//             builder: (_) => SignupLogin(
//               onLoginSuccess: () {
//               },
//               onSignupSuccess: () {
//               },
//               onForgotPressed: () {
//               },
//             ),
//           ),
//         );
//       },
//     );
//   }
// }
