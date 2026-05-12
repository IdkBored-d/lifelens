import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Handles FCM permission request and saves/refreshes the device token
/// to the current user's Firestore doc so the backend can send push
/// notifications to this device.
class FcmTokenService {
  FcmTokenService._();

  static final FcmTokenService instance = FcmTokenService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> init() async {
    // Request permission (iOS shows a system dialog; Android 13+ too).
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] Notification permission denied.');
      return;
    }

    // Save the current token.
    await _saveToken(await _getTokenWhenReady());

    // Refresh token when FCM rotates it.
    _messaging.onTokenRefresh.listen(_saveToken);
  }

  Future<void> _saveToken(String? token) async {
    if (token == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
      debugPrint('[FCM] Token saved for $uid');
    } catch (e) {
      debugPrint('[FCM] Failed to save token: $e');
    }
  }

  Future<String?> _getTokenWhenReady() async {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      var apnsReady = false;
      for (var attempt = 0; attempt < 6; attempt++) {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken != null) {
          apnsReady = true;
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (!apnsReady) {
        debugPrint(
          '[FCM] APNS token unavailable yet; FCM token will refresh later.',
        );
        return null;
      }
    }

    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('[FCM] Token unavailable yet: $e');
      return null;
    }
  }

  /// Clear the token from Firestore on sign-out so we stop sending
  /// notifications to a device that's no longer logged in.
  Future<void> clearToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': FieldValue.delete(),
      });
    } catch (_) {}
  }
}
