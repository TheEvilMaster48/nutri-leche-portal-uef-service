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
  String url =
      "https://servicioslsa.nutri.com.ec/resources/output-onlinegiftools.gif";

  Widget _ImagenNutri() {
    if (useLocalGif) {
      return Image.asset('assets/icono/nutri.png', width: 120);
    } else {
      return Image.network(
        url,
        width: 120,
        loadingBuilder: (
          BuildContext context,
          Widget child,
          ImageChunkEvent? loadingProgress,
        ) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
      );
    }
  }

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      await PushService.instance.init();
    });

    FirebaseNotificationBus.stream.listen((data) {
      setState(() {
        final tipo = data['tipo'] ?? '';
        if (tipo == 'evento') {
          _notificaciones['eventos'] = (_notificaciones['eventos'] ?? 0) + 1;
        } else if (tipo == 'cumpleanios') {
          _notificaciones['cumpleanios'] =
              (_notificaciones['cumpleanios'] ?? 0) + 1;
        } else if (tipo == 'sorteo') {
          _notificaciones['sorteos'] = (_notificaciones['sorteos'] ?? 0) + 1;
        } else if (tipo == 'calendario') {
          _notificaciones['calendario'] =
              (_notificaciones['calendario'] ?? 0) + 1;
        }
      });
    });

    _actualizarContadoresPendientes();

    Future.delayed(const Duration(seconds: 1), () {
      final auth = context.read<AuthService>();
      auth.showNotification(
        "Bienvenido ${auth.currentUser?.nombre ?? ''}",
        "success",
      );
    });

    _timer = Timer.periodic(const Duration(minutes: 2), (_) {
      _actualizarContadoresPendientes();
    });
  }

  Future<void> _actualizarContadoresPendientes() async {
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
      final sorteos = sorteoService.sorteos;

      setState(() {
        _notificaciones['eventos'] = pendientesEventos;
        _notificaciones['cumpleanios'] = pendientesCumples;
      });
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final Usuario? usuario = auth.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;

    final List<Map<String, dynamic>> menus = [
      {
        'titulo': 'Calendario',
        'subtitulo': 'Agenda de actividades',
        'icono': Image.asset('assets/icono/calendario.png', width: 60, height: 60),
        'ruta': '/calendario_eventos',
        'tipo': 'calendario',
      },
      {
        'titulo': 'Gestión de eventos',
        'subtitulo': 'Crea y organiza',
        'icono': Image.asset('assets/icono/evento.png', width: 60, height: 60),
        'ruta': '/eventos_page',
        'tipo': 'eventos',
      },
      {
        'titulo': 'Cumpleaños',
        'subtitulo': 'Crea y organiza',
        'icono': Image.asset('assets/icono/cumpleanos.png', width: 60, height: 60),
        'ruta': '/cumpleanios',
        'tipo': 'cumpleanios',
      },
      {
        'titulo': 'Buzón de sugerencias',
        'subtitulo': 'Crea y organiza',
        'icono': Image.asset('assets/icono/correo.png', width: 60, height: 60),
        'ruta': '/buzon',
      },
      {
        'titulo': 'Sorteo',
        'subtitulo': 'Ver Sorteos y Resultados',
        'icono': Image.asset('assets/icono/eventodetalle.png', width: 60, height: 60),
        'ruta': '/sorteos',
        'tipo': 'sorteos',
      },
    ];

    return Scaffold(
      body: Stack(
        children: [
          // Fondo blanco
          Container(
            color: Colors.white,
          ),

          // Fondo azul con curva ondulada
          ClipPath(
            clipper: MenuWaveClipper(),
            child: Container(
              height: 320,
              decoration: const BoxDecoration(
                color: Color(0xFF0052A3),
              ),
            ),
          ),

          // Contenido
          SafeArea(
            child: Column(
              children: [
                // Header con info de usuario
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Avatar izquierdo
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person_outline,
                              size: 50,
                              color: Color(0xFF0052A3),
                            ),
                          ),
                          const SizedBox(width: 20),
                          // Avatar derecho
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person_outline,
                              size: 50,
                              color: Color(0xFF0052A3),
                            ),
                          ),
                        ],
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

                // Lista de menús
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
                    itemCount: menus.length,
                    itemBuilder: (context, index) {
                      final menu = menus[index];
                      return _buildMenuButton(
                        context,
                        menu['titulo'],
                        menu['subtitulo'],
                        menu['icono'],
                        menu['ruta'],
                        tipo: menu['tipo'],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Bottom Navigation Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 70,
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildBottomNavItem(
                    icon: Icons.home_outlined,
                    label: 'Inicio',
                    index: 0,
                  ),
                  _buildBottomNavItem(
                    icon: Icons.notifications_outlined,
                    label: 'Notificaciones',
                    index: 1,
                    badge: _totalNotificaciones > 0 ? _totalNotificaciones : null,
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

    return InkWell(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });

        // Navegación según el índice
        if (index == 2) {
          Navigator.pushNamed(context, '/perfil');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isSelected ? const Color(0xFF0052A3) : Colors.grey,
                  size: 28,
                ),
                if (badge != null)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        badge > 9 ? '9+' : badge.toString(),
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
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF0052A3) : Colors.grey,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF0052A3),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _obtenerDescripcionUsuario(Usuario? usuario) {
    if (usuario == null) return 'Sin datos de usuario';
    if (usuario.areaUsuario.isNotEmpty) {
      return 'Área Administrativa';
    }
    if (usuario.cargo.isNotEmpty) {
      return 'Cargo: ${usuario.cargo}';
    }
    return 'Empleado Nutri';
  }

  Widget _buildMenuButton(
    BuildContext context,
    String title,
    String subtitle,
    Widget icon,
    String route, {
    String? tipo,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, route).then((_) async {
          if (tipo == 'eventos' || tipo == 'cumpleanios') {
            await _actualizarContadoresPendientes();
          } else if (tipo != null) {
            setState(() {
              _notificaciones[tipo] = 0;
            });
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFE0E0E0),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF0052A3),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
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

// Custom clipper para la curva ondulada del menú
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