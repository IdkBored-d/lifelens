import 'package:firebase_auth/firebase_auth.dart';
import 'package:lifelens/app_services.dart';
import 'package:lifelens/services/background_eod_service.dart';
import 'package:lifelens/services/gemma_model_manager.dart';

Future<void> initializeApp() async {
  // Read a previously saved on-device model path so Gemma loads immediately
  // on subsequent launches after the user completes setup.
  final gemmaPath = await GemmaModelManager.getSavedPath();
  await AppServices.init(gemmaPath: gemmaPath);

  // Register the scheduled background EOD task.
  await BackgroundEodService.register();

  await FirebaseAuth.instance.authStateChanges().first;
}
