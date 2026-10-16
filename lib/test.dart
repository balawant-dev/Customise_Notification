// import 'dart:async';
// import 'dart:io';
//
// import 'package:awesome_notifications/awesome_notifications.dart';
// import 'package:device_info_plus/device_info_plus.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
//
// import 'firebase_options.dart';
//
// @pragma('vm:entry-point')
// Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); // zaroori hai
//   debugPrint('BG FCM received: ${message.data}');
//   await NotificationService.showCustomOfferNotification(message, isBackground: true);
// }
//
// class NotificationService {
//   NotificationService._();
//
//   static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
//
//   static const MethodChannel _nativeChannel = MethodChannel(
//     'topperswisdom/custom_notification',
//   );
//
//   static bool _initialized = false;
//   static StreamSubscription<RemoteMessage>? _messageSubscription;
//   static StreamSubscription<String>? _tokenSubscription;
//
//   // Track last shown messageId to prevent double notification
//   static String? _lastShownMessageId;
//
//   static Future<void> initialize() async {
//     if (_initialized) return;
//     _initialized = true;
//
//     try {
//       await AwesomeNotifications().initialize(null, [
//         NotificationChannel(
//           channelKey: 'basic_channel',
//           channelName: 'ToppersWisdom Notifications',
//           channelDescription: 'ToppersWisdom alerts and offers',
//           defaultColor: const Color(0xFF03045E),
//           importance: NotificationImportance.High,
//           playSound: true,
//           enableVibration: true,
//         ),
//       ], debug: kDebugMode);
//
//       await _requestPermission();
//       await getFCMToken();
//       await getDeviceId();
//
//       _tokenSubscription = _messaging.onTokenRefresh.listen((token) {
//         debugPrint('FCM token refreshed: $token');
//       });
//
//       // Foreground only
//       _messageSubscription = FirebaseMessaging.onMessage.listen((
//           message,
//           ) async {
//         debugPrint('Foreground FCM data: ${message.data}');
//         // await showCustomOfferNotification(message, isBackground: false);
//       });
//
//       FirebaseMessaging.onMessageOpenedApp.listen((message) {
//         debugPrint('Notification tapped: ${message.data}');
//       });
//
//       final initialMessage = await _messaging.getInitialMessage();
//       if (initialMessage != null) {
//         debugPrint('App opened from notification: ${initialMessage.data}');
//       }
//
//       debugPrint('ToppersWisdom NotificationService initialized');
//     } catch (e, stack) {
//       _initialized = false;
//       debugPrint('Notification initialization error: $e');
//       debugPrintStack(stackTrace: stack);
//     }
//   }
//
//   static Future<void> _requestPermission() async {
//     final settings = await _messaging.requestPermission(
//       alert: true,
//       badge: true,
//       sound: true,
//       provisional: false,
//     );
//
//     debugPrint('FCM permission: ${settings.authorizationStatus}');
//
//     final allowed = await AwesomeNotifications().isNotificationAllowed();
//     if (!allowed) {
//       await AwesomeNotifications().requestPermissionToSendNotifications();
//     }
//   }
//
//   static Future<String?> getFCMToken() async {
//     try {
//       final token = await _messaging.getToken();
//       debugPrint('FCM TOKEN: $token');
//       return token;
//     } catch (e) {
//       debugPrint('FCM token error: $e');
//       return null;
//     }
//   }
//
//   static Future<String?> getDeviceId() async {
//     try {
//       final deviceInfo = DeviceInfoPlugin();
//       String? deviceId;
//
//       if (Platform.isAndroid) {
//         deviceId = (await deviceInfo.androidInfo).id;
//       } else if (Platform.isIOS) {
//         deviceId = (await deviceInfo.iosInfo).identifierForVendor;
//       }
//
//       debugPrint('Device ID: $deviceId');
//       return deviceId;
//     } catch (e) {
//       debugPrint('Device ID error: $e');
//       return null;
//     }
//   }
//
//   /// Main method – now has protection against double + empty notifications
//   static Future<void> showCustomOfferNotification(
//       RemoteMessage message, {
//         bool isBackground = false,
//       }) async {
//     // 1. Prevent same message showing twice
//     final messageId = message.messageId;
//
//     // Duplicate protection (background isolate mein limited kaam karega)
//     if (messageId != null && messageId == _lastShownMessageId) {
//       debugPrint('Duplicate messageId → skipping');
//       return;
//     }
//     _lastShownMessageId = messageId;
//
//     final data = message.data;
//     final hasData = data.isNotEmpty;
//     final hasNotification = message.notification != null;
//
//     // Agar notification payload hai aur data nahi → skip (FCM already dikha chuka hoga)
//     // if (!hasData && hasNotification) {
//     //   debugPrint('Only notification payload → skipping custom (FCM will handle)');
//     //   return;
//     // }
//
//     if (!hasData && !hasNotification) {
//       debugPrint('No data and no notification → skipping');
//       return;
//     }
//
//     final title =
//         data['title']?.toString() ?? message.notification?.title ?? '';
//
//     final body = data['body']?.toString() ?? message.notification?.body ?? '';
//
//     // 3. Skip if title & body both empty (null/empty case)
//     if (title.trim().isEmpty && body.trim().isEmpty) {
//       debugPrint('Title and body empty → skipping notification');
//       return;
//     }
//
//     final brand = data['brand']?.toString() ?? 'Toppers Wisdom';
//     final logoText = data['logoText']?.toString() ?? 'T';
//     final type = data['type']?.toString().toLowerCase() ?? 'book';
//     final imageUrl = _getNotificationImageUrl(message);
//
//     final expiresAt =
//         data['expiresAt']?.toString() ??
//             data['countdownEnd']?.toString() ??
//             data['expiryTime']?.toString() ??
//             "2026-10-15T14:01:00.000Z";
//
//     final price = data['price']?.toString() ?? '250';
//     final buttonText = data['buttonText']?.toString() ?? 'SHOP';
//     final subtitle = data['subtitle']?.toString() ?? body;
//
//     final nativeData = <String, dynamic>{
//       'type': type,
//       'brand': brand,
//       'logoText': logoText,
//       'title': title.isEmpty ? 'Special offer just for you!' : title,
//       'body': body.isEmpty ? 'Avail the offer NOW!' : body,
//       'imageUrl': imageUrl ?? '',
//       // 'expiresAt': expiresAt,
//       'price': price,
//       'buttonText': buttonText,
//       'subtitle': subtitle,
//     };
//
//     try {
//       await _nativeChannel.invokeMethod('showOfferNotification', nativeData);
//       debugPrint(
//         'Custom native notification shown (background: $isBackground)',
//       );
//     } on PlatformException catch (e) {
//       debugPrint('Native notification error: ${e.message}');
//       // Only fallback if we have valid title/body
//       if (title.isNotEmpty || body.isNotEmpty) {
//         await _showFallbackNotification(
//           title: title.isEmpty ? 'Special offer just for you!' : title,
//           body: body.isEmpty ? 'Avail the offer NOW!' : body,
//           data: data,
//           imageUrl: imageUrl,
//         );
//       }
//     } on MissingPluginException catch (e) {
//       debugPrint('Native channel missing: $e');
//       if (title.isNotEmpty || body.isNotEmpty) {
//         await _showFallbackNotification(
//           title: title.isEmpty ? 'Special offer just for you!' : title,
//           body: body.isEmpty ? 'Avail the offer NOW!' : body,
//           data: data,
//           imageUrl: imageUrl,
//         );
//       }
//     }
//   }
//
//   static String? _getNotificationImageUrl(RemoteMessage message) {
//     final data = message.data;
//
//     final candidates = <String?>[
//       data['imageUrl']?.toString(),
//       data['image']?.toString(),
//       data['banner']?.toString(),
//       message.notification?.android?.imageUrl,
//       message.notification?.apple?.imageUrl,
//     ];
//
//     for (final candidate in candidates) {
//       final url = candidate?.trim();
//       if (url != null &&
//           (url.startsWith('https://') || url.startsWith('http://'))) {
//         return url;
//       }
//     }
//     return null;
//   }
//
//   static Future<void> _showFallbackNotification({
//     required String title,
//     required String body,
//     required Map<String, dynamic> data,
//     String? imageUrl,
//   }) async {
//     if (title.trim().isEmpty && body.trim().isEmpty) return;
//
//     final payload = data.map((key, value) => MapEntry(key, value.toString()));
//     final hasImage = imageUrl != null && imageUrl.isNotEmpty;
//
//     await AwesomeNotifications().createNotification(
//       content: NotificationContent(
//         id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
//         channelKey: 'basic_channel',
//         title: title,
//         body: body,
//         notificationLayout: hasImage
//             ? NotificationLayout.BigPicture
//             : NotificationLayout.Default,
//         bigPicture: hasImage ? imageUrl : null,
//         payload: payload,
//       ),
//     );
//   }
//
//   static Future<void> cancelCustomNotification() async {
//     try {
//       await _nativeChannel.invokeMethod('cancelOfferNotification');
//     } catch (e) {
//       debugPrint('Cancel notification error: $e');
//     }
//   }
//
//   static Future<void> dispose() async {
//     await _messageSubscription?.cancel();
//     await _tokenSubscription?.cancel();
//     _messageSubscription = null;
//     _tokenSubscription = null;
//     _initialized = false;
//     _lastShownMessageId = null;
//   }
// }
