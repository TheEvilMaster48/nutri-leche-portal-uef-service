import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';
import '../core/notification_banner.dart';
import '../screens/menu.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart'; // para kIsWeb


final FlutterLocalNotificationsPlugin localNotifications =
FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // En background puede no estar inicializado
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

  Future<void> init() async {
    if (_initialized) return; // para no inicializar 2 veces
    _initialized = true;

    // 1. Asegurar que Firebase está inicializado
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    // Handler de background
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 2. Inicializar notificaciones locales (Android + iOS)
    const AndroidInitializationSettings initSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: initSettingsAndroid,
      iOS: initSettingsIOS,
    );

    await localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Aquí podrías navegar a alguna pantalla si lo necesitas
      },
    );

    // 3. Canal para Android
    if (Platform.isAndroid) {
      await localNotifications
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(highImportanceChannel);
    }

    // 4. Permisos y token
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    String? token;

    if (kIsWeb || Platform.isAndroid) {
      // Web y Android: OK pedir token directamente
      try {
        token = await messaging.getToken();
        print('FCM TOKEN (Android/Web) = $token');
      } catch (e) {
        print('⚠️ Error obteniendo FCM token en Android/Web: $e');
      }
    } else if (Platform.isIOS) {
      // iOS: evitar llamar getToken mientras APNS no esté bien configurado
      print(
          'ℹ️ iOS: no se llama getToken en PushService.init para evitar apns-token-not-set. '
              'Cuando configures APNs correctamente podrás activarlo aquí.');
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      print('🔁 TOKEN REFRESH = $newToken');
      // Aquí más adelante podrías reenviar al backend si quieres
    });
    // 5. Listener de mensajes en foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('NOTIFICACIÓN EN FOREGROUND');
      print('Título: ${message.notification?.title}');
      print('Body: ${message.notification?.body}');
      print('Data: ${message.data}');

      try {
        FirebaseNotificationBus.add({
          'tipo': message.data['tipo'] ?? 'evento',
        });
      } catch (e) {
        print('Error al emitir notificación al menú: $e');
      }

      final notification = message.notification;
      if (notification != null) {
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
      }
    });
  }
}