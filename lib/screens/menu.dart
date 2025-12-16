import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nutri/services/sorteo_service.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/evento_service.dart';
import '../services/cumpleanios_service.dart';
import '../models/usuario.dart';
import '../services/push_service.dart';

class FirebaseNotificationBus {
  static final _controller = StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get stream => _controller.stream;
  static void add(Map<String, dynamic> data) => _controller.add(data);
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  Timer? _timer;
  int _selectedIndex = 0;

  final Map<String, int> _notificaciones = {
    'eventos': 0,
    'cumpleanios': 0,
    'sorteos': 0,
    'calendario': 0,
  };

  bool useLocalGif = true;
  String url = "https://servicioslsaqas.nutri.com.ec/resources/output-onlinegiftools.gif";

  @override
  void initState() {
    super.initState();

    // Inicializar PushService PRIMERO
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializePushService();
    });

    // Escuchar notificaciones
    FirebaseNotificationBus.stream.listen((data) {
      if (!mounted) return;
      setState(() {
        final tipo = data['tipo'] ?? '';
        if (tipo == 'evento') {
          _notificaciones['eventos'] = (_notificaciones['eventos'] ?? 0) + 1;
        } else if (tipo == 'cumpleanios') {
          _notificaciones['cumpleanios'] = (_notificaciones['cumpleanios'] ?? 0) + 1;
        } else if (tipo == 'sorteo') {
          _notificaciones['sorteos'] = (_notificaciones['sorteos'] ?? 0) + 1;
        } else if (tipo == 'calendario') {
          _notificaciones['calendario'] = (_notificaciones['calendario'] ?? 0) + 1;
        }
      });
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

    _timer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (mounted) _actualizarContadoresPendientes();
    });
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
      final sorteoService = context.read<SorteoService>();
      final auth = context.read<AuthService>();
      final usuario = auth.currentUser;
      if (usuario == null) return;

      await eventoService.obtenerEventos(idUsuario: usuario.id);
      final eventos = eventoService.eventos;
      final pendientesEventos = eventos.where((e) => e.estado == 0).length;

      await cumpleService.obtenerCumpleanios(idUsuario: usuario.id);
      final cumpleanios = cumpleService.cumpleanios;
      final pendientesCumples = cumpleanios.where((c) => c.estado == 0).length;

      await sorteoService.obtenerSorteos(idUsuario: usuario.id);

      if (mounted) {
        setState(() {
          _notificaciones['eventos'] = pendientesEventos;
          _notificaciones['cumpleanios'] = pendientesCumples;
        });
      }
    } catch (e) {
      debugPrint('Error al actualizar contadores: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int get _totalNotificaciones {
    return _notificaciones.values.fold(0, (sum, count) => sum + count);
  }

  Future<void> _cerrarSesion() async {
    final auth = context.read<AuthService>();

    final confirmLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Cerrar Sesión'),
          content: const Text('¿Estás seguro que deseas cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
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

      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
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

    final List<Map<String, dynamic>> menus = [
      {
        'titulo': 'Gestión de Eventos',
        'subtitulo': 'Crea y organiza',
        'imagen': 'assets/icono/eventos.jpg',
        'ruta': '/eventos_page',
        'tipo': 'eventos',
      },
      {
        'titulo': 'Cumpleaños',
        'subtitulo': 'Crea y organiza',
        'imagen': 'assets/icono/cumpleanos.jpg',
        'ruta': '/cumpleanios',
        'tipo': 'cumpleanios',
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
        'subtitulo': 'Crea y organiza',
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
              height: 320,
              decoration: const BoxDecoration(color: Color(0xFF0052A3)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
                      return _buildMenuButton(
                        context,
                        menus[index]['titulo'],
                        menus[index]['subtitulo'],
                        menus[index]['imagen'],
                        menus[index]['ruta'],
                        tipo: menus[index]['tipo'],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 10,
            top: 50,
            child: IconButton(
              icon: const Icon(Icons.exit_to_app, color: Colors.white, size: 30),
              onPressed: _cerrarSesion,
              tooltip: 'Cerrar Sesión',
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 65,
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
                    _buildBottomNavItem(icon: Icons.home_outlined, label: 'Inicio', index: 0),
                    _buildBottomNavItem(icon: Icons.person_outline, label: 'Perfil', index: 2),
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
          setState(() => _selectedIndex = index);
          if (index == 2) Navigator.pushNamed(context, '/perfil');
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
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
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
                  color: isSelected ? const Color(0xFF0052A3) : Colors.transparent,
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
    String imagePath,
    String route, {
    String? tipo,
  }) {
    double iconWidth = 60;
    double iconHeight = 60;
    BoxFit iconFit = BoxFit.contain;

    if (imagePath.contains('eventos.jpg')) {
      iconWidth = 80;
      iconHeight = 80;
    } else if (imagePath.contains('cumpleanos.jpg')) {
      iconWidth = 80;
      iconHeight = 80;
    } else if (imagePath.contains('calendario.jpg')) {
      iconWidth = 80;
      iconHeight = 80;
    } else if (imagePath.contains('correo.jpg')) {
      iconWidth = 40;
      iconHeight = 40;
      iconFit = BoxFit.scaleDown;
    }

    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, route).then((_) async {
          if (tipo == 'eventos' || tipo == 'cumpleanios') {
            await _actualizarContadoresPendientes();
          } else if (tipo != null) {
            setState(() => _notificaciones[tipo] = 0);
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  imagePath,
                  width: iconWidth,
                  height: iconHeight,
                  fit: iconFit,
                ),
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