import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/usuario.dart';

class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  // MÉTODO PARA OBTENER LA IMAGEN SEGÚN EL GÉNERO DESDE EL BACKEND
  Future<String> _obtenerImagenPorGenero(Usuario? usuario, BuildContext context) async {
    if (usuario == null) return 'assets/icono/masculino.jpg';

    // LLAMAR AL MÉTODO 'obtenerGenero' PARA OBTENER EL GÉNERO DEL USUARIO
    final genero = await Provider.of<AuthService>(context, listen: false)
        .obtenerGenero(usuario.id.toString()); // LLAMADA AL MÉTODO ESTÁTICO

    if (genero == 'femenino' || genero == 'f' || genero == 'mujer') {
      return 'assets/icono/femenino.jpg';
    } else {
      return 'assets/icono/masculino.jpg';
    }
  }

  // MÉTODO PARA FORMATEAR EL TEXTO DEL GÉNERO
  String _formatearGenero(String? genero) {
    if (genero == null || genero.isEmpty) return 'No especificado';

    final generoLower = genero.toLowerCase().trim();

    if (generoLower == 'masculino' || generoLower == 'm' || generoLower == 'hombre') {
      return 'Masculino';
    } else if (generoLower == 'femenino' || generoLower == 'f' || generoLower == 'mujer') {
      return 'Femenino';
    } else {
      return genero;
    }
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
                  FutureBuilder<String>(
                    future: _obtenerImagenPorGenero(usuario, context), // LLAMADA AL MÉTODO ASÍNCRONO
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator(); // MOSTRAR INDICADOR DE CARGA
                      }

                      if (snapshot.hasError) {
                        return const Icon(Icons.error); // MANEJO DE ERROR
                      }

                      final imagePath = snapshot.data ?? 'assets/icono/masculino.jpg';

                      return Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          color: Colors.white, // FONDO BLANCO
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 2), // BORDE NEGRO
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
                            imagePath,
                            width: 130,
                            height: 130,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
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
                  // CAMPO DE GÉNERO
                  _buildInfoRow(Icons.wc, 'Género', _formatearGenero(usuario.genero)),
                  _buildInfoRow(Icons.phone_rounded, 'Teléfono', usuario.telefono),
                  _buildInfoRow(Icons.apartment_rounded, 'Área', usuario.areaUsuario),
                  _buildInfoRow(Icons.widgets_rounded, 'Módulos', usuario.modulos),

                  const SizedBox(height: 40),

                  // BOTÓN REGRESAR AL MENÚ
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 1, 121, 145),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 35, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    label: const Text(
                      'Volver al Menú',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
