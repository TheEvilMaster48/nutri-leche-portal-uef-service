import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/evento.dart';
import '../services/evento_service.dart';
import '../core/notification_banner.dart';
import '../services/auth_service.dart';
import 'detalle_evento_screen.dart';
import 'menu.dart';

class EventosPage extends StatefulWidget {
  const EventosPage({super.key});

  @override
  State<EventosPage> createState() => _EventosPageState();
}

class _EventosPageState extends State<EventosPage> {
  bool _cargando = true;
  int idUsuario = 0;

  @override
  void initState() {
    super.initState();
    _cargarEventos();
  }

  Future<void> _cargarEventos() async {
    final eventoService = context.read<EventoService>();

    try {
      final authService = context.read<AuthService>();
      final usuarioActual = authService.currentUser;
      idUsuario = usuarioActual?.id ?? 0;

      if (idUsuario == 0) {
        final prefs = await SharedPreferences.getInstance();
        idUsuario = prefs.getInt('idUsuario') ?? 0;
      }
    } catch (e) {
      debugPrint("No se pudo obtener el idUsuario: $e");
    }

    if (idUsuario == 0) {
      NotificationBanner.show(
        context,
        "No se encontró un usuario válido para cargar los eventos.",
        NotificationType.error,
      );
      setState(() => _cargando = false);
      return;
    }

    await eventoService.obtenerEventos(idUsuario: idUsuario);
    setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    final eventos = context.watch<EventoService>().eventos;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF003BCE),
              Color(0xFF1565C0),
              Color(0xFF42A5F5),
              Color(0xFFE3F2FD)
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ENCABEZADO CON BOTÓN REGRESAR
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0048FF), Color(0xFF64B5F6)],
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
                      'Eventos Corporativos',
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
                        child: eventos.isEmpty
                            ? const Center(
                                child: Text(
                                  'No hay eventos disponibles actualmente.',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.black54,
                                  ),
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: () async {
                                  await context
                                      .read<EventoService>()
                                      .obtenerEventos(idUsuario: idUsuario);
                                },
                                child: ListView.builder(
                                  itemCount: eventos.length,
                                  itemBuilder: (context, i) {
                                    final evento = eventos[i];
                                    return _EventoItem(
                                      evento: evento,
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

class _EventoItem extends StatelessWidget {
  const _EventoItem({required this.evento, required this.idUsuario});
  final Evento evento;
  final int idUsuario;

  @override
  Widget build(BuildContext context) {
    final textoEstado = evento.estado == 0 ? 'Pendiente' : 'Leído';
    final colorEstado = evento.estado == 0 ? Colors.orange : Colors.green;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      elevation: 3,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        leading: const Icon(Icons.event, color: Color(0xFF0048FF)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                evento.titulo,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0048FF),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              textoEstado,
              style: TextStyle(
                color: colorEstado,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
        subtitle: Text("${evento.fecha}  ${evento.horaEvento}"),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetalleEventoScreen(evento: evento),
            ),
          );

          if (evento.estado == 0) {
            evento.estado = 1;
            Future.microtask(() {
              context.read<EventoService>().marcarEventoComoVisto(
                    idUsuario: idUsuario,
                    idEvento: evento.idEvento,
                  );
            });
          }
        },
      ),
    );
  }
}
