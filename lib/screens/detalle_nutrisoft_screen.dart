import 'package:flutter/material.dart';
import 'package:nutri/base/base.dart';

import '../models/nutrisoft.dart';
import '../widget/texto_con_enlaces.dart';

/// Detalle de una notificación Nutrisoft: solo título y descripción.
///
/// No hay imágenes, videos ni PDFs (a diferencia de [DetalleEventoScreen]), así
/// que la pantalla es puramente texto y no necesita estado.
class DetalleNutrisoftScreen extends StatelessWidget {
  const DetalleNutrisoftScreen({super.key, required this.item});

  final Nutrisoft item;

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.of(context).viewPadding.top;

    return Scaffold(
      backgroundColor: Base().COLOR_BLANCO,
      body: Stack(
        children: [
          ClipPath(
            clipper: DetalleNutrisoftWaveClipper(),
            child: Container(
              height: 120 + topInset,
              decoration: BoxDecoration(color: Base().COLOR_AZUL_CORP),
            ),
          ),

          Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, topInset + 12, 16, 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'DETALLE NUTRISOFT',
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
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
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
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.titulo,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Base().COLOR_AZUL_CORP,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Base().COLOR_AZUL_CORP,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildDescripcion(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescripcion() {
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
              color: Base().COLOR_AZUL_CORP.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.description,
                color: Base().COLOR_AZUL_CORP, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Descripción',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Base().COLOR_AZUL_CORP,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                TextoConEnlaces(
                  texto: item.descripcion,
                  estilo: TextStyle(
                    fontSize: 15,
                    color: Base().COLOR_GRIS,
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

class DetalleNutrisoftWaveClipper extends CustomClipper<Path> {
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
