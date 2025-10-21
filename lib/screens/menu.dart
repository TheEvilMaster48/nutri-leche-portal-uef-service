import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/usuario.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final Usuario? usuario = auth.currentUser;

    final screenWidth = MediaQuery.of(context).size.width;

    // Menús principales
    final List<Map<String, dynamic>> menus = [
      {
        'titulo': 'Eventos',
        'subtitulo': 'Ver calendario y actividades',
        'icono': Icons.event_available_rounded,
        'ruta': '/eventos',
        'colores': [
          const Color.fromARGB(255, 0, 72, 255),
          const Color(0xFF64B5F6)
        ],
      },
      {
        'titulo': 'Notificaciones',
        'subtitulo': 'Ver avisos importantes del sistema',
        'icono': Icons.notifications_active_rounded,
        'ruta': '/notificaciones',
        'colores': [
          const Color.fromARGB(255, 250, 0, 0),
          const Color(0xFF00ACC1)
        ],
      },
      {
        'titulo': 'Chat',
        'subtitulo': 'Comunicación interna',
        'icono': Icons.chat_rounded,
        'ruta': '/chat',
        'colores': [
          const Color.fromARGB(255, 0, 150, 7),
          const Color(0xFF81C784)
        ],
      },
      {
        'titulo': 'Recursos',
        'subtitulo': 'Descargar y administrar documentos',
        'icono': Icons.folder_copy_rounded,
        'ruta': '/recursos',
        'colores': [
          const Color.fromARGB(255, 157, 0, 255),
          const Color(0xFF9575CD)
        ],
      },
    ];

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 1, 121, 145),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              children: [
                // Botón cerrar sesión
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

                // Logo Nutri Leche
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    image: const DecorationImage(
                      image: AssetImage('assets/icono/nutrileche.png'),
                      fit: BoxFit.contain,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Nombre del usuario
                Text(
                  usuario?.nombre.isNotEmpty == true
                      ? usuario!.nombre
                      : 'Usuario Invitado',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                // Cargo o área del usuario
                Text(
                  _obtenerDescripcionUsuario(usuario),
                  style: const TextStyle(
                    fontSize: 17,
                    color: Colors.white70,
                  ),
                ),

                const SizedBox(height: 20),

                // Línea divisoria
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

                // Botones Principales
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
      ),
    );
  }

  /// Retorna descripción formateada del usuario (área o cargo)
  String _obtenerDescripcionUsuario(Usuario? usuario) {
    if (usuario == null) return 'Sin datos de usuario';
    if (usuario.areaUsuario.isNotEmpty) {
      return 'Área: ${usuario.areaUsuario}';
    } else if (usuario.cargo.isNotEmpty) {
      return 'Cargo: ${usuario.cargo}';
    } else {
      return 'Empleado Nutri Leche';
    }
  }

  /// Botón de Menú Principal
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
