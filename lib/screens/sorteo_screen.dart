import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sorteo.dart';
import '../services/sorteo_service.dart';
import '../core/notification_banner.dart';
import '../services/auth_service.dart';
import 'detalle_sorteo_screen.dart';
import 'menu.dart';

class SorteoScreen extends StatefulWidget {
  const SorteoScreen({super.key});

  @override
  State<SorteoScreen> createState() => _SorteoScreenState();
}

class _SorteoScreenState extends State<SorteoScreen> {
  bool _cargando = true;
  int idUsuario = 0;

  @override
  void initState() {
    super.initState();
    _cargarSorteos();
  }

  Future<void> _cargarSorteos() async {
    final sorteoService = context.read<SorteoService>();

    try {
      final authService = context.read<AuthService>();
      final usuarioActual = authService.currentUser;
      idUsuario = usuarioActual?.id ?? 0;

      if (idUsuario == 0) {
        final prefs = await SharedPreferences.getInstance();
        idUsuario = prefs.getInt('idUsuario') ?? 0;
      }
    } catch (_) {}

    if (idUsuario == 0) {
      NotificationBanner.show(
        context,
        "No se encontró un usuario válido para cargar los sorteos.",
        NotificationType.error,
      );
      setState(() => _cargando = false);
      return;
    }

    await sorteoService.obtenerSorteos(idUsuario: idUsuario);
    setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    final sorteos = context.watch<SorteoService>().sorteos;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF8B0000),
              Color(0xFFB71C1C),
              Color(0xFFEF5350),
              Color(0xFFFFCDD2),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFC62828), Color(0xFFEF5350)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const MenuScreen()),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Sorteos Corporativos',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _cargando
                    ? const Center(child: CircularProgressIndicator())
                    : Padding(
                        padding: const EdgeInsets.all(12),
                        child: sorteos.isEmpty
                            ? const Center(
                                child: Text(
                                  'No hay sorteos disponibles actualmente.',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.black54,
                                  ),
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: () async {
                                  await context
                                      .read<SorteoService>()
                                      .obtenerSorteos(idUsuario: idUsuario);
                                },
                                child: ListView.builder(
                                  itemCount: sorteos.length,
                                  itemBuilder: (context, i) {
                                    final sorteo = sorteos[i];
                                    return _SorteoItem(
                                      sorteo: sorteo,
                                      idUsuario: idUsuario,
                                    );
                                  },
                                ),
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SorteoItem extends StatelessWidget {
  final Sorteo sorteo;
  final int idUsuario;

  const _SorteoItem({
    required this.sorteo,
    required this.idUsuario,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      elevation: 3,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        leading: const Icon(Icons.casino_rounded, color: Color(0xFFC62828)),

        title: Text(
          sorteo.titulo,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFFC62828),
          ),
          overflow: TextOverflow.ellipsis,
        ),

        subtitle: Text(
          sorteo.descripcion,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.black87),
        ),

        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetalleSorteoScreen(sorteo: sorteo),
            ),
          );
        },
      ),
    );
  }
}
