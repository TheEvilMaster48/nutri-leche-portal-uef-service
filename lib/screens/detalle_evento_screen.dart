import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/evento.dart';
import '../models/calendario_evento.dart';

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
        ? (evento.horaEvento.isNotEmpty ? evento.horaEvento : '—')
        : (evento.hora ?? '—');

    // DETERMINAR FUENTE DE IMAGEN (imagenPath o imagenBase64)
    final String? imagen = (evento is Evento)
        ? evento.imagenPath
        : (evento.imagenBase64 ?? '');

    Widget imagenWidget;

    // MOSTRAR IMAGEN DESDE BACKEND (URL O BASE64)
    if (imagen != null && imagen.isNotEmpty) {
      try {
        if (imagen.startsWith('http')) {
          imagenWidget = Image.network(
            imagen,
            width: 260,
            height: 260,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.image_not_supported,
              size: 130,
              color: Colors.grey,
            ),
          );
        } else {
          final bytes = base64Decode(imagen);
          imagenWidget = Image.memory(
            Uint8List.fromList(bytes),
            width: 260,
            height: 260,
            fit: BoxFit.cover,
          );
        }
      } catch (_) {
        imagenWidget =
            const Icon(Icons.broken_image, size: 130, color: Colors.grey);
      }
    } else {
      imagenWidget = const Icon(Icons.image, size: 130, color: Colors.grey);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Detalle del Evento',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0048FF),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFFF8F9FF),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // TÍTULO
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 25),

            // DETALLES PRINCIPALES
            _filaDetalle('Descripción', descripcion),
            const SizedBox(height: 10),
            _filaDetalle('Fecha', fecha),
            const SizedBox(height: 10),
            _filaDetalle('Hora', hora),
            const SizedBox(height: 25),

            // IMAGEN DEL EVENTO
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imagenWidget,
            ),
          ],
        ),
      ),
    );
  }

  Widget _filaDetalle(String titulo, String valor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            titulo,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: Text(
            valor,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}
