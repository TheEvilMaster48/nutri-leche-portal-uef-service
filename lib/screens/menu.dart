import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../core/notification_banner.dart';
import '../models/notification_item.dart';
import '../models/usuario.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Opcional: notificación inicial al entrar
    Future.delayed(const Duration(seconds: 1), () {
      final auth = context.read<AuthService>();
      auth.showNotification("Bienvenido ${auth.currentUser?.nombre ?? ''}", "success");
    });

    // Actualización automática cada 2 minutos
    _timer = Timer.periodic(const Duration(minutes: 2), (_) {
      setState(() {});
    });
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
        'titulo': 'Eventos',
        'subtitulo': 'Ver calendario y actividades',
        'icono': Icons.event_available_rounded,
        'ruta': '/eventos',
        'colores': [const Color(0xFF0048FF), const Color(0xFF64B5F6)],
      },
      {
        'titulo': 'Notificaciones',
        'subtitulo': 'Ver avisos importantes del sistema',
        'icono': Icons.notifications_active_rounded,
        'ruta': '/notificaciones',
        'colores': [const Color(0xFFFA0000), const Color(0xFF00ACC1)],
      },
      {
        'titulo': 'Chat',
        'subtitulo': 'Comunicación interna',
        'icono': Icons.chat_rounded,
        'ruta': '/chat',
        'colores': [const Color(0xFF009607), const Color(0xFF81C784)],
      },
      {
        'titulo': 'Recursos',
        'subtitulo': 'Descargar y administrar documentos',
        'icono': Icons.folder_copy_rounded,
        'ruta': '/recursos',
        'colores': [const Color(0xFF9D00FF), const Color(0xFF9575CD)],
      },
      {
        'titulo': 'Perfil',
        'subtitulo': 'Ver y editar información personal',
        'icono': Icons.person_rounded,
        'ruta': '/perfil',
        'colores': [const Color(0xFFFF9900), const Color(0xFFFFB74D)],
      },
    ];

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 1, 121, 145),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Column(
                  children: [
                    // 🔹 Botón cerrar sesión
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
                          tooltip: 'Cerrar Sesión',
                        ),
                      ],
                    ),

                    // 🔹 Foto de perfil del usuario
                    Container(
                      width: 130,
                      height: 130,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Builder(
                          builder: (context) {
                            final cedula = usuario?.cedula?.trim() ?? '';
                            final imageUrl = cedula.isNotEmpty
                                ? 'https://servicioslsa.nutri.com.ec/alimentacion/$cedula.jpeg'
                                : 'https://servicioslsa.nutri.com.ec/alimentacion/default.jpeg';

                            return Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.person,
                                  size: 100,
                                  color: Colors.white70,
                                );
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            (loadingProgress.expectedTotalBytes ?? 1)
                                        : null,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 🔹 Nombre del usuario
                    Text(
                      usuario?.nombre.toUpperCase() ?? '',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    // 🔹 Cargo o área del usuario
                    Text(
                      _obtenerDescripcionUsuario(usuario),
                      style: const TextStyle(
                        fontSize: 17,
                        color: Colors.white70,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 🔹 Línea divisoria
                    Container(
                      height: 4,
                      width: screenWidth * 0.9,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.6),
                            blurRadius: 8,
                            spreadRadius: 1,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // 🔹 Menús principales
                    Wrap(
                      spacing: 18,
                      runSpacing: 18,
                      alignment: WrapAlignment.center,
                      children: menus.map((menu) {
                        return _buildMenuButton(
                          context,
                          menu['titulo'],
                          menu['subtitulo'],
                          menu['icono'],
                          menu['colores'][0],
                          menu['colores'][1],
                          menu['ruta'],
                          screenWidth,
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // 🔔 Banner flotante de notificaciones (esquina superior derecha)
            NotificationBanner(
              load: () async {
                final auth = context.read<AuthService>();
                final usuario = auth.currentUser;

                // Mostrar mensajes locales de sesión (login/logout)
                if (auth.currentNotification != null) {
                  final notif = auth.currentNotification!;
                  return [
                    NotificationItem(
                      id: 'banner_sesion',
                      tipo: notif['type'] ?? 'info',
                      titulo: notif['type'] == 'success'
                          ? 'Inicio de Sesión Exitoso'
                          : notif['type'] == 'error'
                              ? 'Error en Sesión'
                              : 'Aviso del Sistema',
                      detalle: notif['message'] ?? '',
                      refId: '',
                      fecha: DateTime.now(),
                    ),
                  ];
                }

                // Si hay usuario, traer notificaciones reales del backend
                if (usuario != null) {
                  final data = await NotificationService.obtenerNotificaciones(usuario.id.toString());
                  return data.map((n) {
                    return NotificationItem(
                      tipo: n['tipo'] ?? 'info',
                      titulo: n['titulo'] ?? 'Notificación',
                      detalle: n['detalle'] ?? '',
                      fecha: DateTime.tryParse(n['fecha'] ?? '') ?? DateTime.now(),
                    );
                  }).toList();
                }

                return [];
              },
              onClose: () => context.read<AuthService>().clearNotification(),
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
    return 'Empleado Nutri Leche';
  }

  Widget _buildMenuButton(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color1,
    Color color2,
    String route,
    double screenWidth,
  ) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
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
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
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
