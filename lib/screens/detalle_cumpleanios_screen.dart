import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/cumpleanios.dart';

class DetalleCumpleaniosScreen extends StatelessWidget {
  final Cumpleanios cumple;

  const DetalleCumpleaniosScreen({super.key, required this.cumple});

  DateTime _parseFecha(String fecha) {
    try {
      if (fecha.isEmpty || fecha == '0000-00-00') return DateTime.now();
      if (fecha.contains('/')) {
        final partes = fecha.split('/');
        if (partes.length == 3) {
          final dia = int.tryParse(partes[0]) ?? 1;
          final mes = int.tryParse(partes[1]) ?? 1;
          final anio = int.tryParse(partes[2]) ?? DateTime.now().year;
          return DateTime(anio, mes, dia);
        }
      }
      return DateTime.tryParse(fecha) ?? DateTime.now();
    } catch (_) {
      return DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget imagenWidget;

    if (cumple.imagenPath != null && cumple.imagenPath!.isNotEmpty) {
      try {
        if (cumple.imagenPath!.startsWith('http')) {
          imagenWidget = Image.network(
            cumple.imagenPath!,
            width: 260,
            height: 260,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.image_not_supported, size: 130, color: Colors.grey),
          );
        } else {
          final bytes = base64Decode(cumple.imagenPath!);
          imagenWidget = Image.memory(
            Uint8List.fromList(bytes),
            width: 260,
            height: 260,
            fit: BoxFit.cover,
          );
        }
      } catch (_) {
        imagenWidget = const Icon(Icons.broken_image, size: 130, color: Colors.grey);
      }
    } else {
      imagenWidget = const Icon(Icons.image, size: 130, color: Colors.grey);
    }

    final fecha = _parseFecha(cumple.fecha);
    final fechaFormateada =
        "${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}";

    final descripcionFiltrada = _limpiarDescripcion(cumple.descripcion);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Detalle del Cumpleaños',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFFFF4081),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFFFFF0F4),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              cumple.titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 25),
            Text(
              descripcionFiltrada,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_month, color: Color(0xFFFF4081)),
                const SizedBox(width: 8),
                Text(
                  fechaFormateada,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imagenWidget,
            ),
          ],
        ),
      ),
    );
  }

  String _limpiarDescripcion(String descripcion) {
    final lineas = descripcion
        .split('\n')
        .map((l) => l.trim())
        .where((l) =>
            l.isNotEmpty &&
            !RegExp(r'^[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+\s[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+$').hasMatch(l))
        .toList();
    return lineas.join('\n');
  }
}
