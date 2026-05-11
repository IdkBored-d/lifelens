import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:lifelens/app_services.dart';
import 'package:lifelens/services/minigen_downloader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print("Testing AppServices.init()...");
  try {
    await Firebase.initializeApp();
    await AppServices.init();
    print("Done. MiniGen loaded: ${AppServices.miniGen.isLoaded}");
  } catch (e) {
    print("Error: $e");
  }
}
