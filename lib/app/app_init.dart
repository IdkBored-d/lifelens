import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lifelens/app_services.dart';
import 'package:lifelens/services/background_eod_service.dart';

Future<void> initializeApp() async {
  // Keep startup responsive: if heavy model init runs long, continue rendering
  // and let the rest of the app come up instead of appearing frozen.
  try {
    await AppServices.init().timeout(const Duration(seconds: 8));
  } catch (_) {
    // Non-fatal at startup; services may still finish shortly after.
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
