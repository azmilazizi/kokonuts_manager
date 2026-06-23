import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

// Top-level handler required by firebase_messaging for background messages.
// On web the service worker handles background messages instead, so this is a no-op.
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage _) async {}

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._();
  factory PushNotificationService() => _instance;
  PushNotificationService._();

  static void registerBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);
  }

  /// Request permission, obtain an FCM token, register it with the backend,
  /// and wire up the foreground message listener.
  ///
  /// [vapidKey] is the Web Push certificate key from Firebase Console →
  /// Project Settings → Cloud Messaging → Web Push certificates.
  Future<void> setup({
    required String authToken,
    required String vapidKey,
    required void Function(RemoteMessage) onMessage,
  }) async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final granted = settings.authorizationStatus ==
            AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    if (!granted) return;

    final token =
        await FirebaseMessaging.instance.getToken(vapidKey: vapidKey);
    if (token != null) await _registerToken(authToken, token);

    FirebaseMessaging.instance.onTokenRefresh
        .listen((t) => _registerToken(authToken, t));

    FirebaseMessaging.onMessage.listen(onMessage);
  }

  /// Remove the current FCM token from the backend and invalidate it locally.
  Future<void> deregister(String authToken) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await http.delete(
        Uri.parse('$kManagerApiBase/fcm-token'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'token': token}),
      );
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  Future<void> _registerToken(String authToken, String fcmToken) async {
    try {
      await http.post(
        Uri.parse('$kManagerApiBase/fcm-token'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'token': fcmToken}),
      );
    } catch (_) {}
  }
}
