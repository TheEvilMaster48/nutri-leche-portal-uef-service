import 'package:flutter/material.dart';
import '../models/evento.dart';

// MUESTRA EL DETALLE COMPLETO DE UN EVENTO (COMPATIBLE CON EVENTO Y CALENDARIOEVENTO)
class DetalleEventoScreen extends StatelessWidget {
  final dynamic evento; // ACEPTA AMBOS TIPOS: Evento o CalendarioEvento

  const DetalleEventoScreen({super.key, required this.evento});

  @override
  Widget build(BuildContext context) {
    // CAMPOS COMPATIBLES ENTRE AMBOS MODELOS
    final String titulo = evento.titulo ?? '';
    final String descripcion = evento.descripcion ?? '';
    final String fecha =
        (evento is Evento) ? evento.fecha : (evento.fecha ?? '');
    final String hora = (evento is Evento)
        ? (evento.horaEvento.isNotEmpty ? evento.horaEvento : '')
        : (evento.hora ?? '');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          // Fondo azul superior con curva
          ClipPath(
            clipper: DetalleEventoWaveClipper(),
            child: Container(
              height: 120,
              decoration: const BoxDecoration(
                color: Color(0xFF0052A3),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'DETALLE DEL EVENTO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Card principal con toda la información
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // IMAGEN
                                ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(20),
                                    topRight: Radius.circular(20),
                                  ),
                                  child: Image.asset(
                                    'assets/icono/detalleevento.jpg',
                                    height: 220,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        height: 220,
                                        color: const Color(0xFFE0E0E0),
                                        child: const Icon(
                                          Icons.image_not_supported,
                                          size: 80,
                                          color: Color(0xFF999999),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                
                                // CONTENIDO
                                Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // TÍTULO
                                      Text(
                                        titulo,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0052A3),
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      
                                      // Divider decorativo
                                      Container(
                                        height: 3,
                                        width: 60,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0052A3),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      
                                      // DESCRIPCIÓN
                                      _buildInfoRow(
                                        icon: Icons.description,
                                        label: 'Descripción',
                                        value: descripcion,
                                      ),
                                      const SizedBox(height: 16),
                                      
                                      // FECHA
                                      _buildInfoRow(
                                        icon: Icons.calendar_today,
                                        label: 'Fecha',
                                        value: fecha,
                                      ),
                                      
                                      // HORA (solo si existe)
                                      if (hora.isNotEmpty) ...[
                                        const SizedBox(height: 16),
                                        _buildInfoRow(
                                          icon: Icons.access_time,
                                          label: 'Hora',
                                          value: hora,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0052A3).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF0052A3),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF666666),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF333333),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DetalleEventoWaveClipper extends CustomClipper<Path> {
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