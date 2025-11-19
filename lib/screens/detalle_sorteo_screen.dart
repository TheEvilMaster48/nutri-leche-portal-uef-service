import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sorteo.dart';
import '../services/sorteo_service.dart';
import '../services/auth_service.dart';

class DetalleSorteoScreen extends StatelessWidget {
  final Sorteo sorteo;

  const DetalleSorteoScreen({super.key, required this.sorteo});

  @override
  Widget build(BuildContext context) {
    final titulo = sorteo.titulo;
    final descripcion = sorteo.descripcion;

    // PROCESAR IMAGEN
    Widget imagenWidget;
    if (sorteo.imagenBase64 != null && sorteo.imagenBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(sorteo.imagenBase64!);
        imagenWidget = Image.memory(
          Uint8List.fromList(bytes),
          width: 260,
          height: 260,
          fit: BoxFit.cover,
        );
      } catch (_) {
        imagenWidget = const Icon(
          Icons.broken_image,
          size: 130,
          color: Colors.grey,
        );
      }
    } else {
      imagenWidget = const Icon(
        Icons.image,
        size: 130,
        color: Colors.grey,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Detalle del Sorteo',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFC62828),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFFFFEBEE),

      // CONTENIDO
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [

            // TÍTULO
            Column(
              children: [
                Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),

            // DESCRIPCIÓN
            Column(
              children: [
                Text(
                  descripcion,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),

            // IMAGEN
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imagenWidget,
            ),

            const SizedBox(height: 25),

            // BOTÓN REGISTRARSE
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC62828),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  // OBTENER ID USUARIO
                  final auth = context.read<AuthService>();
                  final usuario = auth.currentUser;
                  final idUsuario = usuario?.id ?? 0;

                  if (idUsuario == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Usuario no válido.")),
                    );
                    return;
                  }

                  // LLAMAR AL SERVICIO
                  await context.read<SorteoService>().marcarSorteoComoRegistro(
                        idUsuario: idUsuario,
                        idSorteo: sorteo.id,
                      );

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Registrado correctamente en el sorteo."),
                    ),
                  );
                },
                child: const Text(
                  "Registrarse",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
