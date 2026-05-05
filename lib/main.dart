import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'app/app_root.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:background_fetch/background_fetch.dart';
import 'services/background_eod_service.dart';
import 'services/fcm_token_service.dart';
import 'package:provider/provider.dart';
import 'moodlog_store.dart';
import 'avatar_store.dart';
import 'package:lifelens/services/mini_me_suggestions_inbox.dart';
import 'sleep_store.dart';
import 'theme_controller.dart';

/// Must be a top-level function — called by FCM when app is terminated.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised by the system before this is called.
  // Nothing else is needed here; FCM auto-displays the notification.
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseReady = await _initializeFirebaseSafely();

  if (firebaseReady) {
    // Register FCM background handler before runApp.
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request notification permission + persist FCM token.
    unawaited(FcmTokenService.instance.init());
  } else {
    debugPrint(
      '[main] Firebase initialization failed; continuing without Firebase services.',
    );
  }

  debugPaintSizeEnabled = false;
  debugPaintBaselinesEnabled = false;
  debugPaintPointersEnabled = false;
  debugRepaintRainbowEnabled = false;

  // Register headless background fetch only on platforms that support it.
  if (Platform.isAndroid || Platform.isIOS) {
    BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MoodLogStore()),
        ChangeNotifierProvider(create: (_) => AvatarStore()),
        ChangeNotifierProvider(create: (_) => SleepStore()),
        ChangeNotifierProvider(create: (_) => MiniMeSuggestionsInbox()),
        ChangeNotifierProvider(create: (_) => ThemeController()),
      ],
      child: const MyApp(),
    ),
  );
}

Future<bool> _initializeFirebaseSafely() async {
  try {
    await Firebase.initializeApp();
    return true;
  } catch (e) {
    debugPrint('[main] Firebase.initializeApp() failed: $e');
    return false;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeController>(
      builder: (context, controller, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          color: const Color(0xFF0F1014),
          theme: controller.theme,
          themeAnimationCurve: Curves.easeOutCubic,
          themeAnimationDuration: const Duration(milliseconds: 220),
          home: const AppRoot(),
        );
      },
    );
  }
}
