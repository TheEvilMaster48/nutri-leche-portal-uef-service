import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sorteo_service.dart';

class SorteoScreen extends StatefulWidget {
  const SorteoScreen({super.key});

  @override
  State<SorteoScreen> createState() => _SorteoScreenState();
}

class _SorteoScreenState extends State<SorteoScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int? _numeroGanador;
  bool _girando = false;

  @override
  void initState() {
    super.initState();
    final service = context.read<SorteoService>();
    service.crearNuevoSorteo();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCirc);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _iniciarSorteo() async {
    if (_girando) return;

    setState(() => _girando = true);
    _controller.reset();
    _controller.forward();

    await Future.delayed(const Duration(seconds: 3));

    final ganador = context.read<SorteoService>().girarRuleta();

    setState(() {
      _numeroGanador = ganador;
      _girando = false;
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Número ganador: $ganador"),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SorteoService>();
    final sorteo = service.sorteoActual;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sorteo - Ruleta"),
        backgroundColor: const Color(0xFF01579B),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0288D1), Color(0xFF03A9F4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _animation,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    for (int i = 0; i < 100; i++)
                      Transform.rotate(
                        angle: (i * (2 * pi / 100)),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            width: 3,
                            height: 15,
                            color: i % 5 == 0 ? Colors.blueAccent : Colors.grey.shade400,
                          ),
                        ),
                      ),
                    Text(
                      _numeroGanador != null ? '$_numeroGanador' : '?',
                      style: const TextStyle(
                        fontSize: 70,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 50),
            ElevatedButton.icon(
              onPressed: _iniciarSorteo,
              icon: const Icon(Icons.casino_rounded),
              label: Text(_girando ? "Girando..." : "Girar Ruleta"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0048FF),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            if (_numeroGanador != null)
              Text(
                "Número ganador: $_numeroGanador",
                style: const TextStyle(fontSize: 22, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}
