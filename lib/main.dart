import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:nutri/screens/sorteo_screen.dart';
import 'package:nutri/services/sorteo_service.dart';
import 'package:provider/provider.dart';

// CORE
import 'core/locale_provider.dart';
import 'core/notification_banner.dart';

// SERVICIOS PRINCIPALES
import 'services/auth_service.dart';
import 'services/evento_service.dart';
import 'services/usuario_service.dart';
import 'services/global_notifier.dart';
import 'services/language_service.dart';
import 'services/sugerencia_service.dart';
import 'services/calendario_evento_service.dart';
import 'services/perfil_service.dart';
import 'services/cumpleanios_service.dart';

// PANTALLAS PRINCIPALES
import 'screens/login.dart';
import 'screens/menu.dart';
import 'screens/eventos_page.dart';
import 'screens/recursos.dart';
import 'screens/cumpleanios_screen.dart';
import 'screens/sugerencia_screen.dart';
import 'screens/calendario_evento_screen.dart';
import 'screens/perfil.dart';
import 'firebase_options.dart';

// IGNORAR CERTIFICADOS SSL (SOLO PARA PRUEBAS)
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        return host.contains("servicioslsa.nutri.com.ec") || host.contains("10.170.4.15");
      };
  }
}

final FlutterLocalNotificationsPlugin _local =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final auth = GlobalNotifier.auth;
  final loggedIn = auth?.isLoggedIn ?? false;

  if (!loggedIn) {
    print("NOTIFICACION BLOQUEADA (BACKGROUND - USUARIO NO LOGUEADO)");
    return;
  }

  print('NOTIFICACIÓN en BACKGROUND');
  print('Título: ${message.notification?.title}');
  print('Body: ${message.notification?.body}');
  print('Data: ${message.data}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  const AndroidInitializationSettings initSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings =
      InitializationSettings(android: initSettingsAndroid);

  await _local.initialize(initSettings);

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'Notificaciones importantes',
    description: 'Canal para notificaciones importantes',
    importance: Importance.max,
  );

  await _local
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  HttpOverrides.global = MyHttpOverrides();

  runApp(const NutriLechePortalApp());
}

class NutriLechePortalApp extends StatelessWidget {
  const NutriLechePortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),

        ChangeNotifierProvider(create: (_) {
          final auth = AuthService();
          GlobalNotifier.auth = auth;
          return auth;
        }),

        ChangeNotifierProvider(create: (_) => GlobalNotifier()),
        ChangeNotifierProvider(create: (_) => LanguageService()),
        ChangeNotifierProvider(create: (_) => UsuarioService()),
        ChangeNotifierProvider(create: (_) => EventoService()),
        ChangeNotifierProvider(create: (_) => CumpleaniosService()),
        ChangeNotifierProvider(create: (_) => CalendarioEventoService()),
        ChangeNotifierProvider(create: (_) => SugerenciaService()),
        ChangeNotifierProvider(create: (_) => SorteoService()),

        ChangeNotifierProxyProvider<AuthService, PerfilService>(
          create: (context) => PerfilService(context.read<AuthService>()),
          update: (context, auth, previous) => PerfilService(auth),
        ),
      ],
      child: const MyApp(),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final auth = GlobalNotifier.auth;
      final loggedIn = auth?.isLoggedIn ?? false;

      if (!loggedIn) {
        print("NOTIFICACION IGNORADA (FOREGROUND - NO LOGUEADO)");
        return;
      }

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
        await _local.show(
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

  @override
  Widget build(BuildContext context) {
    Future.microtask(() async {
      final auth = context.read<AuthService>();
      final sesionActiva = await auth.verificarSesionGuardada();
      if (sesionActiva && auth.isLoggedIn) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, '/menu');
        });
      }
    });

    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        return MaterialApp(
          title: 'Nutri Portal',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('es', 'ES'),
            Locale('en', 'US'),
          ],
          initialRoute: '/',
          routes: {
            '/': (context) => const LoginScreen(),
            '/menu': (context) => const MenuScreen(),
            '/eventos_page': (context) => const EventosPage(),
            '/recursos': (context) => const RecursosScreen(),
            '/buzon': (context) => const SugerenciaScreen(),
            '/cumpleanios': (context) => const CumpleaniosScreen(),
            '/calendario_eventos': (context) => const CalendarioEventosScreen(),
            '/perfil': (context) => const PerfilScreen(),
            '/sorteos': (context) => const SorteoScreen(),
          },
        );
      },
    );
  }
}
