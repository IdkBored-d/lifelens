import 'package:flutter/material.dart';
import 'app/app_root.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:background_fetch/background_fetch.dart';
import 'services/background_eod_service.dart';
import 'package:provider/provider.dart';
import 'moodlog_store.dart';
import 'avatar_store.dart';
import 'theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize the FlutterGemma plugin (required before using Gemma APIs).
  try {
    await FlutterGemma.initialize();
    debugPrint('[main] FlutterGemma initialized');
  } catch (e) {
    debugPrint('[main] FlutterGemma.initialize() failed: $e');
  }

  // Register the headless background fetch callback for when the app is terminated.
  // Must be called before runApp().
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MoodLogStore()),
        ChangeNotifierProvider(create: (_) => AvatarStore()),
        ChangeNotifierProvider(create: (_) => ThemeController()),
      ],
      child: const MyApp(),
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
          theme: controller.theme,
          themeAnimationCurve: Curves.easeOutCubic,
          themeAnimationDuration: const Duration(milliseconds: 220),
          home: const AppRoot(),
        );
      },
    );
  }
}
