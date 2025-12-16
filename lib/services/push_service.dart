import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../firebase_options.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  print('NOTIFICACIÓN en BACKGROUND');
  print('Título: ${message.notification?.title}');
  print('Body: ${message.notification?.body}');
  print('Data: ${message.data}');
}

const AndroidNotificationChannel highImportanceChannel =
    AndroidNotificationChannel(
  'high_importance_channel',
  'Notificaciones importantes',
  description: 'Canal para notificaciones importantes',
  importance: Importance.max,
);

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _initialized = false;
  StreamSubscription<RemoteMessage>? _listener;

  Future<void> dispose() async {
    await _listener?.cancel();
  }

  Future<void> stopCompletely() async {
    await _listener?.cancel();
    _listener = null;
    _initialized = false;
    print("🔴 PushService Detenido COMPLETAMENTE");
  }

  Future<void> init() async {
    if (_listener != null) {
      await _listener!.cancel();
      _listener = null;
    }

    if (_initialized) return;
    _initialized = true;

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const AndroidInitializationSettings initSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: initSettingsAndroid,
      iOS: initSettingsIOS,
    );

    await localNotifications.initialize(initSettings);

    if (Platform.isAndroid) {
      await localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(highImportanceChannel);
    }

    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    String? token;

    if (kIsWeb || Platform.isAndroid) {
      try {
        token = await messaging.getToken();
        print('FCM TOKEN (Android/Web) = $token');
      } catch (e) {
        print('Error obteniendo token: $e');
      }
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      print('TOKEN REFRESH = $newToken');
    });

    _listener =
        FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('NOTIFICACIÓN EN FOREGROUND - 1 SOLO LISTENER');

      final notification = message.notification;
      if (notification != null && Platform.isAndroid) {
        await localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'Notificaciones importantes',
              channelDescription: 'Canal para notificaciones importantes',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      } else if (notification != null && Platform.isIOS) {
        await localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
        );
      }
    });
  }

  Future<void> stop() async {
    await _listener?.cancel();
    _listener = null;
  }
}
