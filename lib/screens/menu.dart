import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/evento_service.dart';
import '../services/cumpleanios_service.dart';
import '../core/notification_banner.dart' show NotificationBanner, NotificationType;
import '../models/notification_item.dart';
import '../models/usuario.dart';

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

  final Map<String, int> _notificaciones = {
    'eventos': 0,
    'cumpleanios': 0,
  };

  bool useLocalGif = true;
  String url = "https://tuservidor.com/tu_gif.gif";

  Widget _buildGifImage() {
    if (useLocalGif) {
      return Image.asset(
        'assets/gifs/nutri.gif',
        width: 200,
      );
    } else {
      return Image.network(
        url,
        width: 200,
        loadingBuilder: (BuildContext context, Widget child,
            ImageChunkEvent? loadingProgress) {
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

    FirebaseNotificationBus.stream.listen((data) {
      setState(() {
        final tipo = data['tipo'] ?? '';
        if (tipo == 'evento') {
          _notificaciones['eventos'] = (_notificaciones['eventos'] ?? 0) + 1;
        } else if (tipo == 'cumpleanios') {
          _notificaciones['cumpleanios'] = (_notificaciones['cumpleanios'] ?? 0) + 1;
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
      final auth = context.read<AuthService>();
      final usuario = auth.currentUser;
      if (usuario == null) return;

      await eventoService.obtenerEventos(idUsuario: usuario.id);
      final eventos = eventoService.eventos;
      final pendientesEventos = eventos.where((e) => e.estado == 0).length;

      await cumpleService.obtenerCumpleanios(idUsuario: usuario.id);
      final cumpleanios = cumpleService.cumpleanios;
      final pendientesCumples = cumpleanios.where((c) => c.estado == 0).length;

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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final Usuario? usuario = auth.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;

final List<Map<String, dynamic>> menus = [
      {
        'titulo': 'Gestión de Eventos',
        'subtitulo': 'Crea y organiza actividades corporativas',
        'icono': Icons.event_available_rounded,
        'ruta': '/eventos_page',
        'tipo': 'eventos', // NUEVO
        'colores': [const Color(0xFF0048FF), const Color(0xFF64B5F6)],
      },
      {
        'titulo': 'Gestión de Cumpleaños',
        'subtitulo': 'Administra cumpleaños del personal',
        'icono': Icons.cake_rounded,
        'ruta': '/cumpleanios',
        'tipo': 'cumpleanios', // NUEVO
        'colores': [const Color(0xFFFF4081), const Color(0xFFF8BBD0)],
      },
      {
        'titulo': 'Sorteo',
        'subtitulo': 'Ver Sorteos y Resultados',
        'icono': Icons.card_giftcard_rounded,
        'ruta': '/sorteos',
        'colores': [const Color(0xFFFA0000), const Color(0xFF00ACC1)],
      },
      /*
      {
        'titulo': 'Chat',
        'subtitulo': 'Comunicación interna',
        'icono': Icons.chat_rounded,
        'ruta': '/chat',
        'colores': [const Color(0xFF009607), const Color(0xFF81C784)],
      },
      {
        'titulo': 'Noticias',
        'subtitulo': 'Lee las últimas novedades y comunicados internos',
        'icono': Icons.newspaper_rounded,
        'ruta': '/noticias',
        'colores': [const Color(0xFF00796B), const Color(0xFF4DB6AC)],
      },
      {
        'titulo': 'Reconocimientos',
        'subtitulo': 'Premios y logros de empleados',
        'icono': Icons.emoji_events_rounded,
        'ruta': '/reconocimientos',
        'colores': [const Color(0xFFFFC107), const Color(0xFFFFE082)],
      },
      {
        'titulo': 'Beneficios',
        'subtitulo': 'Programas y descuentos exclusivos',
        'icono': Icons.card_giftcard_rounded,
        'ruta': '/beneficios',
        'colores': [const Color(0xFF00BCD4), const Color(0xFF4DD0E1)],
      },*/
      {
        'titulo': 'Calendario',
        'subtitulo': 'Agenda de actividades laborales',
        'icono': Icons.calendar_month_rounded,
        'ruta': '/calendario_eventos',
        'colores': [const Color(0xFF3F51B5), const Color(0xFF7986CB)],
      },
      /*{
        'titulo': 'Agenda',
        'subtitulo': 'Organiza tus reuniones y tareas',
        'icono': Icons.schedule_rounded,
        'ruta': '/agenda',
        'colores': [const Color(0xFF4CAF50), const Color(0xFFA5D6A7)],
      },
      {
        'titulo': 'Recursos',
        'subtitulo': 'Documentos y archivos compartidos',
        'icono': Icons.folder_copy_rounded,
        'ruta': '/recursos',
        'colores': [const Color(0xFF9D00FF), const Color(0xFF9575CD)],
      },*/
      {
        'titulo': 'Buzón de sugerencias',
        'subtitulo': 'Envía tus ideas y comentarios',
        'icono': Icons.mail_rounded,
        'ruta': '/buzon',
        'colores': [const Color(0xFFFF5722), const Color(0xFFFFAB91)],
      },
      {
        'titulo': 'Perfil',
        'subtitulo': 'Ver información personal',
        'icono': Icons.person_rounded,
        'ruta': '/perfil',
        'colores': [const Color(0xFFFF9900), const Color(0xFFFFB74D)],
      },
    ];

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF01579B),
                    Color(0xFF0277BD),
                    Color(0xFF03A9F4),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Image.asset(
                'assets/icono/nutrileche.png',
                width: 700,
                height: 700,
                fit: BoxFit.contain,
              ),
            ),
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: () async {
                            await context.read<AuthService>().logout();
                            if (context.mounted) {
                              Navigator.pushReplacementNamed(context, '/');
                            }
                          },
                          icon: const Icon(Icons.logout, color: Colors.white),
                          tooltip: 'Cerrar sesión',
                        ),
                      ],
                    ),

                    //SECCION DEL USUARIO
                    const SizedBox(height: 10),

                    Text(
                      usuario?.nombre.toUpperCase() ?? '',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    Text(
                      _obtenerDescripcionUsuario(usuario),
                      style: const TextStyle(color: Colors.white70, fontSize: 17),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 20),

                    _buildGifImage(),

                    const SizedBox(height: 30),

                    Container(
                      height: 4,
                      width: screenWidth * 0.9,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),

                    const SizedBox(height: 30),

                    Wrap(
                      spacing: 18,
                      runSpacing: 18,
                      alignment: WrapAlignment.center,
                      children: menus.map((menu) {
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _buildMenuButton(
                              context,
                              menu['titulo'],
                              menu['subtitulo'],
                              menu['icono'],
                              menu['colores'][0],
                              menu['colores'][1],
                              menu['ruta'],
                              screenWidth,
                              tipo: menu['tipo'],
                            ),
                            if (menu.containsKey('tipo') &&
                                (_notificaciones[menu['tipo']] ?? 0) > 0)
                              Positioned(
                                top: -6,
                                right: -6,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${_notificaciones[menu['tipo']]}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _obtenerDescripcionUsuario(Usuario? usuario) {
    if (usuario == null) return 'Sin datos de usuario';
    if (usuario.areaUsuario.isNotEmpty) return 'Área: ${usuario.areaUsuario}';
    if (usuario.cargo.isNotEmpty) return 'Cargo: ${usuario.cargo}';
    return 'Empleado Nutri';
  }

  Widget _buildMenuButton(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color1,
    Color color2,
    String route,
    double screenWidth, {
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: screenWidth * 0.42,
        height: 120,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color1, color2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color1.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 45, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
