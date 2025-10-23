import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

// Core y servicios principales
import 'core/locale_provider.dart';
import 'services/auth_service.dart';
import 'services/evento_service.dart';
import 'services/usuario_service.dart';
import 'services/global_notifier.dart';
import 'services/language_service.dart';

// Pantallas principales
import 'screens/login.dart';
import 'screens/registro.dart';
import 'screens/menu.dart';
import 'screens/eventos.dart';
import 'screens/notificaciones.dart';
import 'screens/chat.dart';
import 'screens/recursos.dart';
import 'screens/nuevo_chat.dart';
import 'screens/chat_detalle.dart';
import 'screens/crear_evento.dart';
import 'screens/configuracion_screen.dart';
import 'screens/ayuda_screen.dart';
import 'screens/acerca_screen.dart';
import 'screens/noticias.dart';
import 'screens/crear_publicacion.dart';
import 'screens/perfil.dart';
import 'services/perfil_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => EventoService()),
        ChangeNotifierProvider(create: (_) => UsuarioService()),
        ChangeNotifierProvider(create: (_) => GlobalNotifier()),
        ChangeNotifierProvider(create: (_) => LanguageService()),

        // PerfilService
        ChangeNotifierProxyProvider<AuthService, PerfilService>(
          create: (context) => PerfilService(context.read<AuthService>()),
          update: (context, auth, previous) => PerfilService(auth),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        return MaterialApp(
          title: 'Nutri Leche Portal',
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
          locale: localeProvider.locale ?? const Locale('es', 'ES'),
          theme: ThemeData(
            colorSchemeSeed: Colors.blue,
            useMaterial3: true,
          ),

          initialRoute: '/',
          routes: {
            '/': (context) => const LoginScreen(),
            '/registro': (context) => const RegistroScreen(),
            '/menu': (context) => const MenuScreen(),
            '/eventos': (context) => const EventosScreen(),
            '/notificaciones': (context) => const NotificacionesScreen(),
            '/chat': (context) => const ChatScreen(),
            '/recursos': (context) => const RecursosScreen(),
            '/nuevo_chat': (context) => const NuevoChatScreen(contacts: []),
            '/crear_evento': (context) => const CrearEventoScreen(),
            '/configuracion': (context) => const ConfiguracionScreen(),
            '/ayuda': (context) => const AyudaScreen(),
            '/acerca': (context) => const AcercaScreen(),
            '/noticias': (context) => const NoticiasScreen(),
            '/crear_publicacion': (context) => const CrearPublicacionScreen(),
            '/perfil': (context) => const PerfilScreen(),
          },
          onGenerateRoute: (settings) {
            if (settings.name?.startsWith('/chat_detalle/') ?? false) {
              final contactoNombre = settings.name!.split('/').last;
              return MaterialPageRoute(
                builder: (context) => ChatDetalleScreen(
                  chatId: 'defaultChat',
                  contactoNombre: contactoNombre,
                ),
              );
            }
            return null;
          },
        );
      },
    );
  }
}
