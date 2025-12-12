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
            Navigator.pushReplacementNamed(context, '/menu');
          }
          if (index == 2) {
            Navigator.pushReplacementNamed(context, '/perfil');
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final Usuario? usuario = auth.currentUser;

    if (usuario == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Perfil'),
          backgroundColor: const Color(0xFF0052A3),
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
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // FONDO AZUL CON CURVA
          ClipPath(
            clipper: PerfilWaveClipper(),
            child: Container(
              height: 340,
              decoration: const BoxDecoration(
                color: Color(0xFF0052A3),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                    child: Column(
                      children: [
                        // FOTO DE PERFIL USUARIO
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              usuario.genero == 'femenino'
                                  ? 'assets/icono/femenino.jpg'
                                  : 'assets/icono/masculino.jpg',
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // NOMBRE DEL USUARIO
                        Text(
                          usuario.nombre.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // CARGO O ÁREA
                        Text(
                          usuario.cargo.isNotEmpty ? usuario.cargo : 'Área Administrativa',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                            fontWeight: FontWeight.w400,
                          ),
                        ),

                        const SizedBox(height: 40),

                        // CARD CONTENEDOR DE TODA LA INFORMACIÓN
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0E0E0),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              // ID (con imagen)
                              _buildInfoItemWithImage(
                                imagePath: 'assets/icono/id.jpg',
                                label: 'ID',
                                value: usuario.id.toString(),
                              ),
                              
                              const Divider(height: 32, thickness: 1, color: Color(0xFFD0D0D0)),
                              
                              // CORREO (con imagen)
                              _buildInfoItemWithImage(
                                imagePath: 'assets/icono/correo.jpg',
                                label: 'Correo',
                                value: usuario.correo,
                              ),
                              
                              const Divider(height: 32, thickness: 1, color: Color(0xFFD0D0D0)),
                              
                              // TELÉFONO (con imagen)
                              _buildInfoItemWithImage(
                                imagePath: 'assets/icono/telefono.jpg',
                                label: 'Teléfono',
                                value: usuario.telefono,
                              ),
                              
                              const Divider(height: 32, thickness: 1, color: Color(0xFFD0D0D0)),
                              
                              // ÁREA (con imagen)
                              _buildInfoItemWithImage(
                                imagePath: 'assets/icono/area.jpg',
                                label: 'Área',
                                value: usuario.areaUsuario.isNotEmpty ? usuario.areaUsuario : 'Administración',
                              ),
                              
                              const Divider(height: 32, thickness: 1, color: Color(0xFFD0D0D0)),
                              
                              // GÉNERO (con icono)
                              _buildInfoItemWithIcon(
                                icon: Icons.wc,
                                label: 'Género',
                                value: usuario.genero == 'femenino' ? 'Femenino' : 'Masculino',
                              ),
                              
                              const Divider(height: 32, thickness: 1, color: Color(0xFFD0D0D0)),
                              
                              // MÓDULOS (con imagen)
                              _buildInfoItemWithImage(
                                imagePath: 'assets/icono/modulos.jpg',
                                label: 'Módulos',
                                value: usuario.modulos.isNotEmpty 
                                    ? usuario.modulos 
                                    : 'Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat. Ut wisi enim ad minim veniam, quis nostrudliquip ex ea',
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
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

  // ITEM DE INFORMACIÓN CON IMAGEN DESDE ASSETS
  Widget _buildInfoItemWithImage({
    required String imagePath,
    required String label,
    required String value,
  }) {
    // DETERMINAR TAMAÑO DEL ICONO SEGÚN EL TIPO
    double iconWidth = 60;
    double iconHeight = 60;
    BoxFit iconFit = BoxFit.contain;
    
    // ICONO DE ID: 60 X 60
    if (imagePath.contains('id.jpg')) {
      iconWidth = 60;
      iconHeight = 60;
      iconFit = BoxFit.contain;
    }
    // ICONO DE CORREO: 40 X 40
    else if (imagePath.contains('correo.jpg')) {
      iconWidth = 40;
      iconHeight = 40;
      iconFit = BoxFit.scaleDown;
    }
    // ICONO DE TELÉFONO: 60 X 60
    else if (imagePath.contains('telefono.jpg')) {
      iconWidth = 60;
      iconHeight = 60;
      iconFit = BoxFit.contain;
    }
    // ICONO DE ÁREA: 60 X 60
    else if (imagePath.contains('area.jpg')) {
      iconWidth = 60;
      iconHeight = 60;
      iconFit = BoxFit.contain;
    }
    // ICONO DE MÓDULOS: 40 X 40
    else if (imagePath.contains('modulos.jpg')) {
      iconWidth = 40;
      iconHeight = 40;
      iconFit = BoxFit.scaleDown;
    }
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // IMAGENES DESDE ASSETS
        Container(
          width: 60,
          height: 60,
          alignment: Alignment.center,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.asset(
              imagePath,
              width: iconWidth,
              height: iconHeight,
              fit: iconFit,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 20,
                  height: 20,
                  color: const Color(0xFFE0E0E0),
                  child: const Icon(
                    Icons.image_not_supported,
                    color: Color(0xFF0052A3),
                    size: 20,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 16),
        // CONTENIDO
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0052A3),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value.isNotEmpty ? value : 'No registrado',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ITEM DE INFORMACIÓN CON ICONO (GÉNERO)
  Widget _buildInfoItemWithIcon({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ICONO GENERO
        Container(
          width: 60,
          height: 40,
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: const Color(0xFF0052A3),
            size: 30,
          ),
        ),
        const SizedBox(width: 16),
        // CONTENIDO
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0052A3),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value.isNotEmpty ? value : 'No registrado',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
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