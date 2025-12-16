import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nutri/screens/sorteo_screen.dart';
import 'package:provider/provider.dart';

import 'core/locale_provider.dart';
import 'services/auth_service.dart';
import 'services/evento_service.dart';
import 'services/usuario_service.dart';
import 'services/global_notifier.dart';
import 'services/language_service.dart';
import 'services/sugerencia_service.dart';
import 'services/cumpleanios_service.dart';
import 'services/calendario_evento_service.dart';
import 'services/perfil_service.dart';
import 'services/sorteo_service.dart';

import 'screens/login.dart';
import 'screens/menu.dart';
import 'screens/eventos_page.dart';
import 'screens/recursos.dart';
import 'screens/cumpleanios_screen.dart';
import 'screens/sugerencia_screen.dart';
import 'screens/calendario_evento_screen.dart';
import 'screens/perfil.dart';
import 'firebase_options.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) {
        return host.contains("servicioslsa.nutri.com.ec") ||
            host.contains("10.170.4.15");
      };
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  HttpOverrides.global = MyHttpOverrides();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const NutriLechePortalApp());
}

class NutriLechePortalApp extends StatelessWidget {
  const NutriLechePortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => AuthService()),
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
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