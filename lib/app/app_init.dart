import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lifelens/app_services.dart';
import 'package:lifelens/services/background_eod_service.dart';
import 'package:lifelens/services/gemma_model_manager.dart';

Future<void> initializeApp() async {
  debugPrint('[app_init] initializeApp() START');
  // Read a previously saved on-device model path and verify the file exists.
  // If the file is missing (e.g. user cleared storage), clear the stale path
  // so the setup screen re-appears on next launch.
  final savedPath = await GemmaModelManager.getSavedPath();
  final pathIsValid = savedPath.isNotEmpty && await File(savedPath).exists();
  if (savedPath.isNotEmpty && !pathIsValid) {
    await GemmaModelManager.clearPath(); // wipe ghost path
  }
  final gemmaPath = pathIsValid ? savedPath : '';
  debugPrint('[app_init] resolved gemmaPath: "$gemmaPath"');

  await AppServices.init(gemmaPath: gemmaPath);
  debugPrint('[app_init] AppServices.init() completed');

  // Register the scheduled background EOD task.
  await BackgroundEodService.register();
  debugPrint('[app_init] BackgroundEodService registered');

  await FirebaseAuth.instance.authStateChanges().first;
  debugPrint('[app_init] Got first auth state');

  await Future.delayed(const Duration(milliseconds: 1300));
  debugPrint('[app_init] initializeApp() COMPLETE');
}
