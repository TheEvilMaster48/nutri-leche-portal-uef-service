import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/cumpleanios.dart';

class DetalleCumpleaniosScreen extends StatelessWidget {
  final Cumpleanios cumple;

  const DetalleCumpleaniosScreen({super.key, required this.cumple});

  String _limpiarDescripcion(String descripcion) {
    final lineas = descripcion
        .split('\n')
        .map((l) => l.trim())
        .where((l) =>
    l.isNotEmpty &&
        !RegExp(r'^[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+\s[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+$')
            .hasMatch(l))
        .toList();
    return lineas.join('\n');
  }

  // ✅ trata el campo "imagenBase64" como URL (porque el WS lo manda como link)
  String _getImagenUrl() {
    final raw = (cumple.imagenPath ?? '').toString().trim();

    if (raw.isEmpty) return '';

    // limpia comillas y basura
    final cleaned = raw
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll(RegExp(r'[\r\n]+'), '')
        .replaceAll(RegExp(r'[)\].,;]+$'), '');

    final uri = Uri.tryParse(cleaned);
    if (uri == null) return '';
    if (!(uri.isScheme('http') || uri.isScheme('https'))) return '';

    return cleaned;
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final cleaned = url
        .trim()
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll(RegExp(r'[\r\n]+'), '')
        .replaceAll(RegExp(r'[)\].,;]+$'), '');

    final uri = Uri.tryParse(cleaned);

    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("URL inválida: $cleaned")),
      );
      return;
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo abrir el enlace")),
      );
    }
  }

  Widget _buildTextWithLinks(BuildContext context, String text) {
    final RegExp urlRegex =
    RegExp(r'(https?:\/\/[^\s]+)', caseSensitive: false);

    final spans = <TextSpan>[];
    int start = 0;

    final matches = urlRegex.allMatches(text);

    for (final match in matches) {
      if (match.start > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, match.start),
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF333333),
              height: 1.4,
            ),
          ),
        );
      }

      final url = match.group(0)!;

      spans.add(
        TextSpan(
          text: url,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF0052A3),
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _openUrl(context, url),
        ),
      );

      start = match.end;
    }

    if (start < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(start),
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF333333),
            height: 1.4,
          ),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    final descripcionFiltrada = _limpiarDescripcion(cumple.descripcion);

    final imageUrl = _getImagenUrl();
    final tieneImagen = imageUrl.isNotEmpty;

    // Inset físico de la barra de estado / notch (consistente iOS/Android).
    final double topInset = MediaQuery.of(context).viewPadding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          ClipPath(
            clipper: DetalleCumpleanosWaveClipper(),
            child: Container(
              height: 120 + topInset,
              decoration: const BoxDecoration(color: Color(0xFF0052A3)),
            ),
          ),
          Column(
            children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, topInset + 12, 16, 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'DETALLE DEL CUMPLEAÑOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
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
                      child: Column(
                        children: [
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
                                // ✅ Imagen desde URL (NO base64)
                                ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(20),
                                    topRight: Radius.circular(20),
                                  ),
                                  child: tieneImagen
                                      ? CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    height: 220,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) {
                                      return Container(
                                        height: 220,
                                        color: const Color(0xFFE0E0E0),
                                        alignment: Alignment.center,
                                        child: const CircularProgressIndicator(
                                          color: Color(0xFF0052A3),
                                        ),
                                      );
                                    },
                                    errorWidget: (context, url, error) {
                                      return Container(
                                        height: 220,
                                        color: const Color(0xFFE0E0E0),
                                        child: const Icon(
                                          Icons.broken_image,
                                          size: 70,
                                          color: Color(0xFF999999),
                                        ),
                                      );
                                    },
                                  )
                                      : Container(
                                    height: 220,
                                    color: const Color(0xFFE0E0E0),
                                    child: const Icon(
                                      Icons.cake,
                                      size: 80,
                                      color: Color(0xFF999999),
                                    ),
                                  ),
                                ),

                                Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cumple.titulo,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0052A3),
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 20),

                                      Container(
                                        height: 3,
                                        width: 60,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0052A3),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(height: 20),

                                      _buildInfoRow(
                                        icon: Icons.description,
                                        label: 'Descripción',
                                        valueWidget: _buildTextWithLinks(
                                          context,
                                          descripcionFiltrada,
                                        ),
                                      ),

                                      // (Opcional) Si quieres mostrar el link de la imagen para abrirlo
                                      // const SizedBox(height: 16),
                                      // if (tieneImagen)
                                      //   _buildInfoRow(
                                      //     icon: Icons.link,
                                      //     label: 'Imagen',
                                      //     valueWidget: GestureDetector(
                                      //       onTap: () => _openUrl(context, imageUrl),
                                      //       child: const Text(
                                      //         'Abrir imagen',
                                      //         style: TextStyle(
                                      //           color: Color(0xFF0052A3),
                                      //           decoration: TextDecoration.underline,
                                      //           fontWeight: FontWeight.w600,
                                      //         ),
                                      //       ),
                                      //     ),
                                      //   ),
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
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    String? value,
    Widget? valueWidget,
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
            child: Icon(icon, color: const Color(0xFF0052A3), size: 20),
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
                valueWidget ??
                    Text(
                      value ?? '',
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

class DetalleCumpleanosWaveClipper extends CustomClipper<Path> {
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
