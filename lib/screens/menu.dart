import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../base/base.dart';
import '../services/auth_service.dart';
import '../services/cierre_sesion.dart';
import '../services/perfil_service.dart';
import '../services/evento_service.dart';
import '../services/cumpleanios_service.dart';
import '../services/nutrisoft_service.dart';
import '../services/parametro_service.dart';
import '../models/usuario.dart';
import '../services/push_service.dart';
import '../services/badge_service.dart';
import '../services/notification_bus.dart';
import '../widget/logo_nutri.dart';
import '../widget/barra_inferior.dart';
import '../widget/tarjeta_menu.dart';
import '../widget/saludo_usuario.dart';

export '../services/notification_bus.dart' show FirebaseNotificationBus;

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with WidgetsBindingObserver {
  final Map<String, int> _notificaciones = {
    'eventos': 0,
    'cumpleanios': 0,
    'calendario': 0,
    'nutrisoft': 0,
  };

  bool useLocalGif = true;
  String url = "${Base.URL_RECURSOS}/output-onlinegiftools.gif";

  @override
  void initState() {
    super.initState();

    // Observa el ciclo de vida para refrescar al volver a primer plano.
    WidgetsBinding.instance.addObserver(this);

    // Inicializar PushService PRIMERO
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializePushService();
      // Si la app se abrió tocando una notificación (o se tocó una sin sesión),
      // ahora que el menú está montado se salta al detalle correspondiente.
      // Un frame de gracia para que el Navigator del menú quede asentado.
      await Future.delayed(const Duration(milliseconds: 300));
      await PushService.instance.procesarPendiente();
    });

    // Escuchar notificaciones
    FirebaseNotificationBus.stream.listen((data) {
      if (!mounted) return;
      setState(() {
        final tipo = data['tipo'] ?? '';
        if (tipo == 'evento') {
          _notificaciones['eventos'] = (_notificaciones['eventos'] ?? 0) + 1;
        } else if (tipo == 'cumpleanios') {
          _notificaciones['cumpleanios'] =
              (_notificaciones['cumpleanios'] ?? 0) + 1;
        } else if (tipo == 'calendario') {
          _notificaciones['calendario'] =
              (_notificaciones['calendario'] ?? 0) + 1;
        } else if (tipo == 'nutrisoft') {
          _notificaciones['nutrisoft'] =
              (_notificaciones['nutrisoft'] ?? 0) + 1;
        }
      });
      // Refleja el nuevo total en el ícono de la app.
      BadgeService.actualizar(_totalNotificaciones);
    });

    _actualizarContadoresPendientes();
    _descargarParaTrabajoSinConexion();

    // Al entrar a Inicio se relee el perfil: si el WS dice que el usuario está
    // inactivo, se cierra la sesión. Va en paralelo para no demorar el push.
    WidgetsBinding.instance.addPostFrameCallback((_) => _validarUsuarioActivo());

    // Mostrar bienvenida después de inicializar
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      final auth = context.read<AuthService>();
      auth.showNotification(
        "Bienvenido ${auth.currentUser?.nombre ?? ''}",
        "success",
      );
    });

    // Antes había un Timer.periodic cada 2 min (drenaje de batería/datos).
    // Ahora confiamos en el push y refrescamos solo al volver a primer plano
    // (didChangeAppLifecycleState), que es cuando el usuario realmente mira la app.
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _actualizarContadoresPendientes();
      _descargarParaTrabajoSinConexion();
    }
  }

  Future<void> _validarUsuarioActivo() async {
    if (!mounted) return;
    final activo = await context.read<PerfilService>().obtenerPerfil();
    if (!activo && mounted) {
      await cerrarSesion(context, motivo: PerfilService.mensajeInactivo);
    }
  }

  Future<void> _initializePushService() async {
    try {
      debugPrint('🔔 Inicializando PushService...');
      await PushService.instance.init();
      debugPrint('✅ PushService inicializado correctamente');
    } catch (e) {
      debugPrint('❌ Error inicializando PushService: $e');
    }
  }

  /// Baja lo que los módulos de campo necesitan sin señal y lo guarda en el
  /// teléfono. Hoy son los parámetros de Logo Nutri.
  ///
  /// Va aparte de los contadores: si el catálogo falla, los badges igual se
  /// actualizan, y al revés. No se espera: el menú no tiene que demorarse por
  /// esto.
  void _descargarParaTrabajoSinConexion() {
    if (!mounted) return;
    unawaited(context.read<ParametroService>().iniciar());
  }

  Future<void> _actualizarContadoresPendientes() async {
    if (!mounted) return;
    try {
      final eventoService = context.read<EventoService>();
      final cumpleService = context.read<CumpleaniosService>();
      final nutrisoftService = context.read<NutrisoftService>();
      final auth = context.read<AuthService>();
      final usuario = auth.currentUser;
      if (usuario == null) return;

      await eventoService.obtenerEventos(idUsuario: usuario.id);
      final eventos = eventoService.eventos;
      final pendientesEventos = eventos.where((e) => e.estado == 0).length;

      await cumpleService.obtenerCumpleanios(idUsuario: usuario.id);
      final cumpleanios = cumpleService.cumpleanios;
      final pendientesCumples = cumpleanios.where((c) => c.estado == 0).length;

      await nutrisoftService.obtenerNutrisoft(idUsuario: usuario.id);
      final pendientesNutrisoft =
          nutrisoftService.items.where((n) => n.pendiente).length;

      if (mounted) {
        setState(() {
          _notificaciones['eventos'] = pendientesEventos;
          _notificaciones['cumpleanios'] = pendientesCumples;
          _notificaciones['nutrisoft'] = pendientesNutrisoft;
        });
        // Sincroniza el badge del ícono con el total real de pendientes.
        await BadgeService.actualizar(_totalNotificaciones);
      }
    } catch (e) {
      debugPrint('Error al actualizar contadores: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  int get _totalNotificaciones {
    return _notificaciones.values.fold(0, (sum, count) => sum + count);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final Usuario? usuario = auth.currentUser;

    // Un solo formato para todos: ícono vectorial + color del módulo. Antes
    // convivían .jpg con fondo propio y iconos sueltos, y la lista se veía
    // como piezas de dos juegos distintos. Los colores salen de la paleta
    // corporativa de [Base] para que el conjunto siga leyéndose como uno solo.
    //
    // Los del día a día quedan en la cuadrícula; los de uso ocasional pasaron
    // a «Utilitarios», en la barra de abajo, para que la pantalla de inicio no
    // crezca cada vez que aparece un módulo nuevo.
    final List<Map<String, dynamic>> menus = [
      {
        'titulo': 'Gestión de Eventos',
        'subtitulo': 'Eventos y notificaciones',
        'icono': Icons.campaign_outlined,
        'color': PaletaMenu.azulCorp,
        'ruta': '/eventos_page',
        'tipo': 'eventos',
      },
      {
        'titulo': 'Cumpleaños',
        'subtitulo': 'Notificación de cumpleañeros',
        'icono': Icons.cake_outlined,
        'color': PaletaMenu.azulCorp,
        'ruta': '/cumpleanios',
        'tipo': 'cumpleanios',
      },
      {
        'titulo': 'Nutrisoft',
        'subtitulo': 'Comunicados del sistema',
        'icono': Icons.work_outline,
        'color': PaletaMenu.azulCorp,
        'ruta': '/nutrisoft',
        'tipo': 'nutrisoft',
      },
      {
        'titulo': 'Calendario',
        'subtitulo': 'Agenda de actividades',
        'icono': Icons.calendar_month_outlined,
        'color': PaletaMenu.azulCorp,
        'ruta': '/calendario_eventos',
        'tipo': 'calendario',
      },
    ];

    return Scaffold(
      // Todo el fondo azul: las tarjetas blancas sobre él resaltan, que era lo
      // que la mitad blanca de antes les quitaba. Lo único claro es la barra
      // de abajo.
      backgroundColor: PaletaMenu.cabecera,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  child: Column(
                    children: [
                      // El logotipo reemplaza a la foto genérica por género:
                      // decía menos del usuario que su propio nombre y metía
                      // una foto de archivo donde va la marca. Sobre el azul
                      // de la cabecera corresponde la versión blanca.
                      const LogoNutri.claro(alto: 72),
                      const SizedBox(height: 16),
                      SaludoUsuario(nombre: usuario?.nombre ?? ''),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      // Algo más alta que ancha: deja sitio al subtítulo en dos
                      // líneas sin que la tarjeta se estire en pantallas anchas.
                      childAspectRatio: 0.85,
                    ),
                    itemCount: menus.length,
                    itemBuilder: (context, index) {
                      final menu = menus[index];
                      final tipo = menu['tipo'] as String?;

                      return TarjetaMenu(
                        titulo: menu['titulo'] as String,
                        subtitulo: menu['subtitulo'] as String,
                        icono: menu['icono'] as IconData,
                        color: menu['color'] as Color,
                        badge: tipo != null ? (_notificaciones[tipo] ?? 0) : 0,
                        alTocar:
                            () => _abrirModulo(menu['ruta'] as String, tipo),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BarraInferior(activa: PestanaInferior.inicio),
          ),
        ],
      ),
    );
  }

  /// Abre un módulo y, al volver, pone al día sus pendientes.
  ///
  /// Los tres módulos con contador se releen del servidor porque el usuario
  /// pudo haber atendido pendientes adentro; para el resto alcanza con apagar
  /// el badge local.
  Future<void> _abrirModulo(String ruta, String? tipo) async {
    await Navigator.pushNamed(context, ruta);
    if (!mounted) return;

    if (tipo == 'eventos' || tipo == 'cumpleanios' || tipo == 'nutrisoft') {
      await _actualizarContadoresPendientes();
    } else if (tipo != null) {
      setState(() => _notificaciones[tipo] = 0);
      await BadgeService.actualizar(_totalNotificaciones);
    }
  }
}
