import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:nutri/screens/sorteo_screen.dart';
import 'package:provider/provider.dart';

import 'base/base.dart';
import 'core/locale_provider.dart';
import 'services/auth_service.dart';
import 'services/evento_service.dart';
import 'services/nutrisoft_service.dart';
import 'services/reaccion_service.dart';
import 'services/usuario_service.dart';
import 'services/global_notifier.dart';
import 'services/language_service.dart';
import 'services/sugerencia_service.dart';
import 'services/cumpleanios_service.dart';
import 'services/calendario_evento_service.dart';
import 'services/perfil_service.dart';
import 'services/push_service.dart';
import 'services/sorteo_service.dart';
import 'services/catalogo_evento_service.dart';
import 'services/viaje_chofer_service.dart';
import 'services/parametro_service.dart';
import 'services/registro_logo_service.dart';

import 'screens/login.dart';
import 'screens/menu.dart';
import 'screens/eventos_page.dart';
import 'screens/nutrisoft_page.dart';
import 'screens/recursos.dart';
import 'screens/cumpleanios_screen.dart';
import 'screens/sugerencia_screen.dart';
import 'screens/calendario_evento_screen.dart';
import 'screens/perfil.dart';
import 'screens/viajes_pendientes_screen.dart';
import 'screens/logo_nutri_screen.dart';
import 'screens/utilitarios_screen.dart';
import 'firebase_options.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        return host.contains(Base.HOST_SERVICIOS) ||
            host.contains("10.170.4.15");
      };
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Toda la app en vertical. También está fijado en el AndroidManifest y en
  // el Info.plist, que rigen antes de que arranque Flutter (splash).
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Borde a borde en todas las versiones de Android, no solo desde la 15
  // (donde el sistema ya lo impone al apuntar a SDK 35+). Así la app se ve
  // igual en todos los teléfonos y Play deja de advertirlo. Las pantallas ya
  // respetan los insets (SafeArea, `viewPadding` en la barra inferior).
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Inicializa media_kit (reproductor de video con fallback a software)
  MediaKit.ensureInitialized();

  HttpOverrides.global = MyHttpOverrides();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // El handler de background y el canal de Android deben quedar listos antes de
  // runApp: el tap sobre una notificación con la app cerrada depende de esto.
  await PushService.registrarHandlersTempranos();

  // media_store_plus es solo Android. En iOS no hay implementación nativa y
  // getPlatformSDKInt lanzaría MissingPluginException al iniciar.
  if (Platform.isAndroid) {
    await MediaStore.ensureInitialized();
    MediaStore.appFolder =
        "Nutri"; // 👈 nombre de carpeta que aparecerá en Descargas
  }

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
        ChangeNotifierProvider(create: (_) => NutrisoftService()),
        ChangeNotifierProvider(create: (_) => ReaccionService()),
        ChangeNotifierProvider(create: (_) => CumpleaniosService()),
        ChangeNotifierProvider(create: (_) => CalendarioEventoService()),
        ChangeNotifierProvider(create: (_) => SugerenciaService()),
        ChangeNotifierProvider(create: (_) => SorteoService()),
        ChangeNotifierProvider(create: (_) => CatalogoEventoService()),
        ChangeNotifierProvider(create: (_) => ViajeChoferService()),
        ChangeNotifierProvider(create: (_) => ParametroService()),
        ChangeNotifierProvider(create: (_) => RegistroLogoService()),
        ChangeNotifierProxyProvider<AuthService, PerfilService>(
          create: (context) => PerfilService(context.read<AuthService>()),
          // Se reutiliza la instancia: crear una nueva en cada aviso de
          // AuthService destruía la anterior mientras Perfil todavía la usaba
          // («PerfilService was used after being disposed»), porque el propio
          // obtenerPerfil() actualiza el usuario y dispara ese aviso.
          update:
              (context, auth, previous) =>
                  (previous ?? PerfilService(auth))..alCambiarSesion(),
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
          title: 'Nutri Notificaciones',
          debugShowCheckedModeBanner: false,
          // Permite que PushService abra el detalle al tocar una notificación.
          navigatorKey: navigatorKey,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('es', 'ES'), Locale('en', 'US')],
          initialRoute: '/',
          routes: {
            '/': (context) => const LoginScreen(),
            '/menu': (context) => const MenuScreen(),
            '/eventos_page': (context) => const EventosPage(),
            '/nutrisoft': (context) => const NutrisoftPage(),
            '/recursos': (context) => const RecursosScreen(),
            '/buzon': (context) => const SugerenciaScreen(),
            '/cumpleanios': (context) => const CumpleaniosScreen(),
            '/calendario_eventos': (context) => const CalendarioEventosScreen(),
            '/perfil': (context) => const PerfilScreen(),
            '/sorteos': (context) => const SorteoScreen(),
            '/rutas': (context) => const ViajesPendientesScreen(),
            '/logo_nutri': (context) => const LogoNutriScreen(),
            '/utilitarios': (context) => const UtilitariosScreen(),
          },
        );
      },
    );
  }
}
