import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

enum VerificationEmailSendMode { customActionLink, defaultFirebaseLink }

class VerificationEmailService {
  // Keep this false until your continue URL is allowlisted in Firebase Auth.
  static const bool _useCustomActionLink = false;

  // Replace this with your real domain and whitelist it in Firebase Auth.
  static const String _continueUrl = 'https://lifelens.app/verify-email';
  static const String _androidPackageName = 'com.example.lifelens';

  static ActionCodeSettings _buildActionCodeSettings() {
    return ActionCodeSettings(
      url: _continueUrl,
      handleCodeInApp: false,
      androidPackageName: _androidPackageName,
      androidInstallApp: true,
    );
  }

  static Future<VerificationEmailSendMode> send(User user) async {
    FirebaseAuthException? lastAuthError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        if (!_useCustomActionLink) {
          await user.sendEmailVerification();
          return VerificationEmailSendMode.defaultFirebaseLink;
        }

        try {
          await user.sendEmailVerification(_buildActionCodeSettings());
          return VerificationEmailSendMode.customActionLink;
        } on FirebaseAuthException catch (e) {
          if (_isActionCodeConfigurationError(e.code, e.message)) {
            await user.sendEmailVerification();
            return VerificationEmailSendMode.defaultFirebaseLink;
          }
          rethrow;
        }
      } on FirebaseAuthException catch (e) {
        lastAuthError = e;
        final isTransient =
            e.code == 'network-request-failed' ||
            e.code == 'internal-error' ||
            e.code == 'unknown';
        final isLastAttempt = attempt == 1;
        if (!isTransient || isLastAttempt) {
          rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }
    }

    if (lastAuthError != null) {
      throw lastAuthError;
    }
    throw FirebaseAuthException(
      code: 'unknown',
      message: 'Unable to send verification email.',
    );
  }

  static bool _isActionCodeConfigurationError(String code, String? message) {
    const configCodes = <String>{
      'missing-continue-uri',
      'invalid-continue-uri',
      'unauthorized-continue-uri',
      'invalid-dynamic-link-domain',
      'dynamic-link-not-activated',
      'missing-android-pkg-name',
      'missing-ios-bundle-id',
    };

    if (configCodes.contains(code)) return true;

    final msg = (message ?? '').toLowerCase();
    return msg.contains('allowlisted') ||
        msg.contains('allowlist') ||
        msg.contains('continue uri') ||
        msg.contains('dynamic link domain');
  }
}
