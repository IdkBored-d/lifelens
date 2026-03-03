// //FAST TESTING PURPOSES
// import 'package:flutter/material.dart';
// import 'package:lifelens/HomeScreen.dart';
// import 'package:lifelens/lifelens_theme.dart';
// import 'moodlog_store.dart';
// import 'package:provider/provider.dart';

// void main() {
//   runApp(
//     ChangeNotifierProvider(
//       create: (_) => MoodLogStore(),
//       child: const MyApp(),
//     ),
//   );
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       theme: lifeLensCalmTheme(),
//       home: const MenuScreen(),
//     );
//   }
// }

// import 'package:flutter/material.dart';
// import 'app_root.dart';
// import 'package:firebase_core/firebase_core.dart';
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();
//   //print ("Firebase initialized");
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp (
//       debugShowCheckedModeBanner: false,
//       home: const AppRoot(),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:lifelens/lifelens_theme.dart';
import 'package:provider/provider.dart';
import 'app/app_root.dart';
import 'moodlog_store.dart';
import 'package:firebase_core/firebase_core.dart';
import 'restart.dart';
import 'theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<MoodLogStore>(create: (_) => MoodLogStore()),
        ChangeNotifierProvider<ThemeController>(
          create: (_) => ThemeController(),
        ),
      ],
      child: const RestartWidget(child: const MyApp()),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeController>(
      builder: (context, controller, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'LifeLens',
          home: const AppRoot(),
          theme: controller.theme,
        );
      },
    );
  }
}
