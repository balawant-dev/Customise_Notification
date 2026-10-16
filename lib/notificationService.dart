import 'dart:async';
import 'dart:io';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

/// Notification dikhane ka kaam ab poori tarah native Android (MyFcmService) karti hai.
/// Dart side sirf permission, token aur device id sambhalti hai.
///
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Display native service (MyFcmService) karti hai. Yahan kuch nahi dikhana.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('BG FCM received: ${message.data}');
}
class NotificationService {
  NotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static bool _initialized = false;
  static StreamSubscription<String>? _tokenSubscription;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await AwesomeNotifications().initialize(null, [
        NotificationChannel(
          channelKey: 'basic_channel',
          channelName: 'ToppersWisdom Notifications',
          channelDescription: 'ToppersWisdom alerts and offers',
          defaultColor: const Color(0xFF03045E),
          importance: NotificationImportance.High,
          playSound: true,
          enableVibration: true,
        ),
      ], debug: kDebugMode);

      await _requestPermission();
      await getFCMToken();
      await getDeviceId();

      _tokenSubscription = _messaging.onTokenRefresh.listen((token) {
        debugPrint('FCM token refreshed: $token');
      });

      FirebaseMessaging.onMessage.listen((message) {
        debugPrint('Foreground FCM data: ${message.data}');
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        debugPrint('Notification tapped: ${message.data}');
      });

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('App opened from notification: ${initialMessage.data}');
      }

      debugPrint('ToppersWisdom NotificationService initialized');
    } catch (e, stack) {
      _initialized = false;
      debugPrint('Notification initialization error: $e');
      debugPrintStack(stackTrace: stack);
    }
  }

  static Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('FCM permission: ${settings.authorizationStatus}');

    final allowed = await AwesomeNotifications().isNotificationAllowed();
    if (!allowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  static Future<String?> getFCMToken() async {
    try {
      final token = await _messaging.getToken();
      debugPrint('FCM TOKEN: $token');
      return token;
    } catch (e) {
      debugPrint('FCM token error: $e');
      return null;
    }
  }

  static Future<String?> getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String? deviceId;
      if (Platform.isAndroid) {
        deviceId = (await deviceInfo.androidInfo).id;
      } else if (Platform.isIOS) {
        deviceId = (await deviceInfo.iosInfo).identifierForVendor;
      }
      debugPrint('Device ID: $deviceId');
      return deviceId;
    } catch (e) {
      debugPrint('Device ID error: $e');
      return null;
    }
  }

  static Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
    _initialized = false;
  }
}