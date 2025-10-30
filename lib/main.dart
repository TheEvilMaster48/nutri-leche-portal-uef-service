import 'package:nutri_leche/screens/celebracion_screen.dart';
import 'package:nutri_leche/screens/noticias_screen.dart';
import 'package:nutri_leche/services/cumpleanios_service.dart';
import 'package:nutri_leche/services/noticias_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:nutri_leche/screens/cumpleanios_screen.dart';
import 'package:nutri_leche/screens/sugerencia_screen.dart';
import 'package:nutri_leche/screens/calendario_evento_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nutri_leche/screens/agenda_screen.dart';
import 'package:nutri_leche/screens/beneficios_screen.dart';
import 'package:nutri_leche/screens/reconocimientos_screen.dart';

// CORE
import 'core/locale_provider.dart';

// SERVICIOS PRINCIPALES
import 'services/auth_service.dart';
import 'services/evento_service.dart';
import 'services/usuario_service.dart';
import 'services/global_notifier.dart';
import 'services/language_service.dart';
import 'services/agenda_service.dart';
import 'services/reconocimiento_service.dart';
import 'services/beneficio_service.dart';
import 'services/celebracion_service.dart';
import 'services/sugerencia_service.dart';
import 'services/calendario_evento_service.dart';
import 'services/perfil_service.dart';

// PANTALLAS PRINCIPALES
import 'screens/login.dart';
import 'screens/registro.dart';
import 'screens/menu.dart';
import 'screens/eventos_screen.dart';
import 'screens/notificaciones.dart';
import 'screens/chat.dart';
import 'screens/recursos.dart';
import 'screens/chat_detalle.dart';
import 'screens/crear_evento.dart';
import 'screens/perfil.dart';

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
        ChangeNotifierProvider(create: (_) => AgendaService()),
        ChangeNotifierProvider(create: (_) => ReconocimientoService()),
        ChangeNotifierProvider(create: (_) => BeneficioService()),
        ChangeNotifierProvider(create: (_) => CelebracionService()),
        ChangeNotifierProvider(create: (_) => SugerenciaService()),
        ChangeNotifierProvider(create: (_) => CalendarioEventoService()),
        ChangeNotifierProvider(create: (_) => CumpleaniosService()),
        ChangeNotifierProvider(create: (_) => NoticiasService()),

        // PERFIL SERVICE DEPENDIENTE DE AUTHSERVICE
        ChangeNotifierProxyProvider<AuthService, PerfilService>(
          create: (context) => PerfilService(context.read<AuthService>()),
          update: (context, auth, previous) => PerfilService(auth),
        ),
      ],
      builder: (context, child) {
        // IMPORTANTE: ASEGURA QUE TODOS LOS PROVIDERS ESTÉN DISPONIBLES ANTES DE CONSTRUIR LA APP
        return const MyApp();
      },
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
          initialRoute: '/',
          routes: {
            '/': (context) => const LoginScreen(),
            '/registro': (context) => const RegistroScreen(),
            '/menu': (context) => const MenuScreen(),
            '/eventos': (context) => const EventosScreen(),
            '/notificaciones': (context) => const NotificacionesScreen(),
            '/chat': (context) => const ChatScreen(),
            '/recursos': (context) => const RecursosScreen(),
            '/crear_evento': (context) => const CrearEventoScreen(),
            '/agenda': (context) => const AgendaScreen(),
            '/reconocimientos': (context) => const ReconocimientosScreen(),
            '/beneficios': (context) => const BeneficiosScreen(),
            '/celebraciones': (context) => const CelebracionesScreen(),
            '/buzon': (context) => const SugerenciaScreen(),
            '/cumpleanios': (context) => const CumpleaniosScreen(),
            '/calendario_eventos': (context) => const CalendarioEventosScreen(),
            '/perfil': (context) => const PerfilScreen(),
            '/noticias': (context) => const NoticiasScreen(),
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
