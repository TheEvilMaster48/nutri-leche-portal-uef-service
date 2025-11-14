/*import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/evento.dart';

class EventoDetalleScreen extends StatelessWidget {
  final Evento evento;

  const EventoDetalleScreen({super.key, required this.evento});

  @override
  Widget build(BuildContext context) {
    Uint8List? imagenBytes;
    if (evento.imagenPath != null && evento.imagenPath!.isNotEmpty) {
      try {
        final base64Str = evento.imagenPath!.split(',').last;
        imagenBytes = base64Decode(base64Str);
      } catch (_) {}
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          evento.titulo,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF3B82F6),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: const Color(0xFFF4F6FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imagenBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  imagenBytes,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.image_not_supported_outlined,
                    size: 100, color: Colors.grey),
              ),
            const SizedBox(height: 20),
            Text(
              evento.titulo,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E40AF),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 18, color: Colors.redAccent),
                const SizedBox(width: 6),
                Text(evento.fecha, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 20),
                const Icon(Icons.access_time_rounded,
                    size: 18, color: Colors.blueAccent),
                const SizedBox(width: 6),
                Text(evento.horaEvento ?? "—",
                    style: const TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              "Descripción:",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              evento.descripcion,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  "Creado por: ${evento.creadoPor}",
                  style: const TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
*/