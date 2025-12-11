import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/usuario.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  int _selectedIndex = 2;  // Perfil debe estar seleccionado por defecto

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final bool isSelected = _selectedIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
          if (index == 0) {
            Navigator.pushReplacementNamed(context, '/'); // Reemplazar pantalla actual con Inicio
          }
          if (index == 2) {
            Navigator.pushReplacementNamed(context, '/perfil'); // Reemplazar pantalla actual con Perfil
          }
        },
        child: SizedBox(
          height: 65,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF0052A3) : Colors.grey,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF0052A3) : Colors.grey,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
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

  // WIDGET AUXILIAR PARA MOSTRAR LA INFORMACIÓN CON ÍCONO
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color.fromARGB(255, 1, 121, 145)),
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          value.isNotEmpty ? value : 'No registrado',
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final Usuario? usuario = auth.currentUser;

    if (usuario == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Perfil'),
          backgroundColor: const Color.fromARGB(255, 1, 121, 145),
        ),
        body: const Center(
          child: Text(
            'No hay información de usuario disponible.',
            style: TextStyle(fontSize: 18, color: Colors.black54),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,  // FONDO BLANCO
      body: Stack(
        children: [
          // FONDO AZUL CON CURVA
          ClipPath(
            clipper: PerfilWaveClipper(),
            child: Container(
              height: 150,
              decoration: const BoxDecoration(
                color: Color(0xFF0052A3),  // AZUL
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // FOTO DE PERFIL USUARIO
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      color: Colors.white, // FONDO BLANCO
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
                      child: Image.asset(
                        usuario.genero == 'femenino'
                            ? 'assets/icono/femenino.jpg'
                            : 'assets/icono/masculino.jpg',  // Usamos imagen directamente
                        width: 130,
                        height: 130,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // NOMBRE DEL USUARIO
                  Text(
                    usuario.nombre,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // CARGO O ÁREA
                  Text(
                    usuario.cargo.isNotEmpty ? usuario.cargo : 'Empleado Nutri',
                    style: const TextStyle(fontSize: 18, color: Colors.black54),
                  ),

                  const Divider(height: 40, thickness: 1.2),

                  // INFORMACIÓN DETALLADA
                  _buildInfoRow(Icons.badge, 'ID', usuario.id.toString()),
                  _buildInfoRow(Icons.email_rounded, 'Correo', usuario.correo),
                  _buildInfoRow(Icons.wc, 'Género', usuario.genero  == 'femenino' ? 'Femenino' : 'Masculino'),
                  _buildInfoRow(Icons.phone_rounded, 'Teléfono', usuario.telefono),
                  _buildInfoRow(Icons.apartment_rounded, 'Área', usuario.areaUsuario),
                  _buildInfoRow(Icons.widgets_rounded, 'Módulos', usuario.modulos),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // MENÚ INFERIOR
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
}

class PerfilWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();

    path.lineTo(0, size.height - 30);

    var firstControlPoint = Offset(size.width * 0.25, size.height - 40);
    var firstEndPoint = Offset(size.width * 0.5, size.height - 30);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    var secondControlPoint = Offset(size.width * 0.75, size.height - 20);
    var secondEndPoint = Offset(size.width, size.height - 30);
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
