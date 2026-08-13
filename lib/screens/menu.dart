import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../base/base.dart';
import '../services/auth_service.dart';
import '../services/evento_service.dart';
import '../services/cumpleanios_service.dart';
import '../services/nutrisoft_service.dart';
import '../models/usuario.dart';
import '../services/push_service.dart';
import '../services/badge_service.dart';
import '../services/reaccion_service.dart';
import '../services/notification_bus.dart';
import '../services/sorteo_service.dart';
import '../services/calendario_evento_service.dart';
import '../services/sugerencia_service.dart';
import '../services/usuario_service.dart';

export '../services/notification_bus.dart' show FirebaseNotificationBus;

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;

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

  Future<void> _cerrarSesion() async {
    final auth = context.read<AuthService>();
    final reacciones = context.read<ReaccionService>();

    // Los providers viven por encima de MaterialApp y sobreviven al logout, así
    // que hay que vaciarlos a mano: si no, el siguiente usuario que entre ve por
    // un instante los datos del anterior. Se leen ANTES del await para no tocar
    // el context después del gap asíncrono.
    final eventos = context.read<EventoService>();
    final cumpleanios = context.read<CumpleaniosService>();
    final nutrisoft = context.read<NutrisoftService>();
    final sorteos = context.read<SorteoService>();
    final calendario = context.read<CalendarioEventoService>();
    final sugerencias = context.read<SugerenciaService>();
    final usuarios = context.read<UsuarioService>();
    // PerfilService NO se captura: es un ChangeNotifierProxyProvider sobre
    // AuthService, así que `logout()` (que notifica) lo reconstruye desde cero
    // y descarta esta instancia. Usarla después del await explota con
    // "used after being disposed", y limpiarla no haría falta igual.

    final confirmLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Base().COLOR_BLANCO,
          title: Text('Cerrar Sesión', style: TextStyle(color: Base().COLOR_AZUL_CORP)),
          content: Text('¿Estás seguro que deseas cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancelar',
                style: TextStyle(color: Base().COLOR_AZUL_CORP),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Cerrar Sesión'),
            ),
          ],
        );
      },
    );

    if (confirmLogout == true) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return const Center(child: CircularProgressIndicator());
        },
      );

      await auth.logout();
      await PushService.instance.stopCompletely();
      await BadgeService.limpiar();
      // La caché de reacciones es por usuario: se descarta al salir.
      await reacciones.limpiar();

      // Resto de datos de la sesión que quedaban en memoria.
      eventos.limpiar();
      cumpleanios.limpiar();
      nutrisoft.limpiar();
      sorteos.limpiar();
      calendario.limpiar();
      sugerencias.limpiar();
      usuarios.cerrarSesion();

      // Imágenes descargadas (fotos de perfil, adjuntos de eventos): son del
      // usuario que sale y no deben reaparecer en la sesión siguiente.
      imageCache.clear();
      imageCache.clearLiveImages();

      // Los contadores del menú se reinician para que el badge no arrastre
      // pendientes del usuario anterior.
      _notificaciones.updateAll((clave, cantidad) => 0);

      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
    }
  }

  String _obtenerImagenPorGenero(Usuario? usuario) {
    if (usuario == null) return 'assets/icono/masculino.jpg';
    final genero = usuario.genero?.toLowerCase().trim() ?? '';
    if (genero == 'femenino' || genero == 'f' || genero == 'mujer') {
      return 'assets/icono/femenino.jpg';
    } else {
      return 'assets/icono/masculino.jpg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final Usuario? usuario = auth.currentUser;

    // Inset inferior (home indicator de iPhone). La barra inferior debe
    // reservar este espacio extra, si no se desborda en iOS.
    final double bottomInset = MediaQuery.of(context).viewPadding.bottom;

    // Inset superior (barra de estado / notch). El fondo azul debe crecer con
    // él para que el nombre y el subtítulo no caigan sobre la curva blanca.
    final double topInset = MediaQuery.of(context).viewPadding.top;

    final List<Map<String, dynamic>> menus = [
      {
        'titulo': 'Gestión de Eventos',
        'subtitulo': 'Eventos y Notificaciones',
        'imagen': 'assets/icono/eventos.jpg',
        'ruta': '/eventos_page',
        'tipo': 'eventos',
      },
      {
        'titulo': 'Cumpleaños',
        'subtitulo': 'Notificacion de cumpleañeros',
        'imagen': 'assets/icono/cumpleanos.jpg',
        'ruta': '/cumpleanios',
        'tipo': 'cumpleanios',
      },
      {
        'titulo': 'Nutrisoft',
        'subtitulo': 'Comunicados del sistema',
        // Ícono en vez de imagen: el logo no decía nada del módulo.
        'icono': Icons.work_outline,
        'ruta': '/nutrisoft',
        'tipo': 'nutrisoft',
      },
      {
        'titulo': 'Calendario',
        'subtitulo': 'Agenda de actividades',
        'imagen': 'assets/icono/calendario.jpg',
        'ruta': '/calendario_eventos',
        'tipo': 'calendario',
      },
      {
        'titulo': 'Buzón de Sugerencias',
        'subtitulo': 'Nueva Sugerencia',
        'imagen': 'assets/icono/correo.jpg',
        'ruta': '/buzon',
      },
    ];

    return Scaffold(
      body: Stack(
        children: [
          Container(color: Colors.white),
          ClipPath(
            clipper: MenuWaveClipper(),
            child: Container(
              height: 320 + topInset,
              decoration: const BoxDecoration(color: Color(0xFF0052A3)),
            ),
          ),
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
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            _obtenerImagenPorGenero(usuario),
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        usuario?.nombre.toUpperCase() ?? '',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _obtenerDescripcionUsuario(usuario),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
                    itemCount: menus.length,
                    itemBuilder: (context, index) {
                      final tipo = menus[index]['tipo'] as String?;
                      final badge =
                          (tipo != null) ? (_notificaciones[tipo] ?? 0) : 0;

                      return _buildMenuButton(
                        context,
                        menus[index]['titulo'],
                        menus[index]['subtitulo'],
                        menus[index]['imagen'] as String?,
                        menus[index]['ruta'],
                        tipo: tipo,
                        badge: badge,
                        icono: menus[index]['icono'] as IconData?,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 10,
            top: MediaQuery.of(context).viewPadding.top + 6,
            child: IconButton(
              icon: const Icon(
                Icons.exit_to_app,
                color: Colors.white,
                size: 30,
              ),
              onPressed: _cerrarSesion,
              tooltip: 'Cerrar Sesión',
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 65 + bottomInset,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBottomNavItem(
                      icon: Icons.home_outlined,
                      label: 'Inicio',
                      index: 0,
                    ),
                    _buildBottomNavItem(
                      icon: Icons.person_outline,
                      label: 'Perfil',
                      index: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required int index,
    int? badge,
  }) {
    final isSelected = _selectedIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () {
          if (index == 2) {
            // Perfil es otra pantalla: al volver, "Inicio" queda seleccionado.
            Navigator.pushNamed(context, '/perfil').then((_) {
              if (mounted) setState(() => _selectedIndex = 0);
            });
          } else {
            setState(() => _selectedIndex = index);
          }
        },
        child: SizedBox(
          height: 65,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    color: isSelected ? const Color(0xFF0052A3) : Colors.grey,
                    size: 24,
                  ),
                  if (badge != null)
                    Positioned(
                      right: -6,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          badge > 9 ? '9+' : badge.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF0052A3) : Colors.grey,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color:
                      isSelected ? const Color(0xFF0052A3) : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _obtenerDescripcionUsuario(Usuario? usuario) {
    if (usuario == null) return 'Sin datos de usuario';
    if (usuario.areaUsuario.isNotEmpty) return 'Área Administrativa';
    if (usuario.cargo.isNotEmpty) return 'Cargo: ${usuario.cargo}';
    return 'Empleado Nutri';
  }

  Widget _buildMenuButton(
    BuildContext context,
    String title,
    String subtitle,
    String? imagePath,
    String route, {
    String? tipo,
    int badge = 0,
    IconData? icono,
  }) {
    double iconWidth = 60;
    double iconHeight = 60;
    BoxFit iconFit = BoxFit.contain;

    if (imagePath == null) {
      // Entrada dibujada con ícono; los tamaños de imagen no aplican.
    } else if (imagePath.contains('eventos.jpg')) {
      iconWidth = 80;
      iconHeight = 80;
    } else if (imagePath.contains('cumpleanos.jpg')) {
      iconWidth = 80;
      iconHeight = 80;
    } else if (imagePath.contains('calendario.jpg')) {
      iconWidth = 80;
      iconHeight = 80;
    } else if (imagePath.contains('nutri.png')) {
      iconWidth = 70;
      iconHeight = 70;
    } else if (imagePath.contains('correo.jpg')) {
      iconWidth = 40;
      iconHeight = 40;
      iconFit = BoxFit.scaleDown;
    }

    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, route).then((_) async {
          if (tipo == 'eventos' ||
              tipo == 'cumpleanios' ||
              tipo == 'nutrisoft') {
            await _actualizarContadoresPendientes();
          } else if (tipo != null) {
            setState(() => _notificaciones[tipo] = 0);
            await BadgeService.actualizar(_totalNotificaciones);
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (icono != null)
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Base().COLOR_AZUL_CORP.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        icono,
                        size: 34,
                        color: Base().COLOR_AZUL_CORP,
                      ),
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        imagePath!,
                        width: iconWidth,
                        height: iconHeight,
                        fit: iconFit,
                      ),
                    ),

                  // ✅ BADGE (pendientes)
                  if (badge > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          badge > 99 ? '99+' : badge.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF0052A3),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MenuWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 50);
    var firstControlPoint = Offset(size.width * 0.25, size.height - 70);
    var firstEndPoint = Offset(size.width * 0.5, size.height - 50);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );
    var secondControlPoint = Offset(size.width * 0.75, size.height - 30);
    var secondEndPoint = Offset(size.width, size.height - 50);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
