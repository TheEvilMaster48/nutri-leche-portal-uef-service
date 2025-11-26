import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sorteo.dart';
import '../services/sorteo_service.dart';
import '../services/auth_service.dart';
import '../screens/menu.dart';

class DetalleSorteoScreen extends StatefulWidget {
  final Sorteo sorteo;

  const DetalleSorteoScreen({super.key, required this.sorteo});

  @override
  State<DetalleSorteoScreen> createState() => _DetalleSorteoScreenState();
}

class _DetalleSorteoScreenState extends State<DetalleSorteoScreen> {
  bool registrado = false;
  bool cargado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!cargado) {
      verificar();
      cargado = true;
    }
  }

  Future<void> verificar() async {
    setState(() => registrado = false);

    final auth = context.read<AuthService>();
    final usuario = auth.currentUser;
    final idUsuario = usuario?.id ?? 0;

    if (idUsuario != 0) {
      final r = await context
          .read<SorteoService>()
          .verificarRegistroLocal(idUsuario, widget.sorteo.id);

      setState(() => registrado = r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.sorteo.titulo;
    final descripcion = widget.sorteo.descripcion;

    Widget imagenWidget;
    if (widget.sorteo.imagenBase64 != null &&
        widget.sorteo.imagenBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(widget.sorteo.imagenBase64!);
        imagenWidget = Image.memory(
          Uint8List.fromList(bytes),
          width: 260,
          height: 260,
          fit: BoxFit.cover,
        );
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
          'Detalle del Sorteo',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFC62828),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFFFFEBEE),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
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
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imagenWidget,
            ),
            const SizedBox(height: 25),

            if (!registrado)
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
                    final auth = context.read<AuthService>();
                    final usuario = auth.currentUser;
                    final idUsuario = usuario?.id ?? 0;

                    if (idUsuario == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Usuario no válido.")),
                      );
                      return;
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Registrándose al Sorteo"),
                        duration: Duration(seconds: 2),
                      ),
                    );

                    await context.read<SorteoService>().marcarSorteoComoRegistro(
                          idUsuario: idUsuario,
                          idSorteo: widget.sorteo.id,
                        );

                    await Future.delayed(const Duration(seconds: 2));

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text("✅ Registrado al Sorteo Correctamente"),
                        duration: Duration(seconds: 3),
                      ),
                    );

                    await Future.delayed(const Duration(seconds: 3));

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MenuScreen(),
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

            if (registrado)
              const Text(
                "Ya estás registrado en este sorteo...",
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
