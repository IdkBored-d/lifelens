import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:lifelens/app_services.dart';
import 'package:lifelens/services/background_eod_service.dart';
import 'package:lifelens/services/tracking_reminder_service.dart';

Future<void> initializeApp() async {
  // Raised to 30 s: MiniGen GGUF OTA download on first launch
  // can take longer on slow connections. NOTE: replacing old OnnxLLM asset copy.
  try {
    await AppServices.init()
        .timeout(const Duration(seconds: 30));
  } catch (_) {
    // Non-fatal at startup; services may still finish shortly after.
  }

  try {
    await TrackingReminderService.instance.init();
    await TrackingReminderService.instance.requestPermissionsIfEnabled();
    await TrackingReminderService.instance.refreshReminderState();
  } catch (_) {
    // Non-fatal; reminder setup should never block startup.
  }

  // Register scheduled background tasks only outside debug to avoid
  // emulator/Play-services stalls that can look like ANR.
  if (!kDebugMode) {
    unawaited(
      BackgroundEodService.register().catchError((_) {
        // Non-fatal; background scheduling can fail on some devices.
      }),
    );
  }

  // Do not block startup indefinitely waiting for auth stream on emulator.
  try {
    await FirebaseAuth.instance
        .authStateChanges()
        .first
        .timeout(const Duration(seconds: 2));
  } catch (_) {
    // Ignore timeout/errors; AppRoot handles auth state via StreamBuilder.
  }
}
