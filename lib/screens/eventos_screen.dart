/*import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/evento_service.dart';
import '../services/auth_service.dart';
import '../models/evento.dart';
import '../models/usuario.dart';
import 'evento_detalle_screen.dart';

class EventosScreen extends StatefulWidget {
  const EventosScreen({super.key});

  @override
  State<EventosScreen> createState() => _EventosScreenState();
}

class _EventosScreenState extends State<EventosScreen> {
  bool mostrarEventosPasados = false;

  @override
  void initState() {
    super.initState();
    _cargarEventos();
  }

  Future<void> _cargarEventos() async {
    final eventoService = context.read<EventoService>();
    await eventoService.obtenerEventos();
  }

  @override
  Widget build(BuildContext context) {
    final eventoService = context.watch<EventoService>();
    final auth = context.watch<AuthService>();
    final Usuario? usuario = auth.currentUser;

    if (usuario == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Error: no hay sesión activa',
            style: TextStyle(fontSize: 18, color: Colors.red),
          ),
        ),
      );
    }

    final ahora = DateTime.now();
    final eventos = eventoService.eventos;

    List<Evento> eventosFiltrados = eventos.where((e) {
      try {
        final partes = e.fecha.split(' - ');
        final fechaStr = partes[0];
        final horaStr = partes.length > 1 ? partes[1] : '00H00';
        final horaParseada = horaStr.replaceAll('H', ':');
        final fechaCompleta =
            DateFormat('yyyy-MM-dd HH:mm').parse('$fechaStr $horaParseada');

        return mostrarEventosPasados
            ? fechaCompleta.isBefore(ahora)
            : fechaCompleta.isAfter(ahora);
      } catch (_) {
        return false;
      }
    }).toList();

    eventosFiltrados.sort((a, b) {
      final fechaA = DateTime.tryParse(a.fecha.split(' ').first) ?? DateTime.now();
      final fechaB = DateTime.tryParse(b.fecha.split(' ').first) ?? DateTime.now();
      return fechaB.compareTo(fechaA);
    });

    final tituloSeccion =
        mostrarEventosPasados ? 'Eventos Pasados' : 'Eventos Programados';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tituloSeccion,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF3B82F6),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              mostrarEventosPasados
                  ? Icons.event_available_rounded
                  : Icons.history_rounded,
            ),
            tooltip: mostrarEventosPasados
                ? 'Ver próximos eventos'
                : 'Ver eventos pasados',
            onPressed: () {
              setState(() => mostrarEventosPasados = !mostrarEventosPasados);
            },
          ),
        ],
      ),
      body: eventosFiltrados.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 80, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'No hay eventos disponibles por el momento',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: eventosFiltrados.length,
              itemBuilder: (context, index) {
                final evento = eventosFiltrados[index];
                final eventoPasado = _esEventoPasado(evento);

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EventoDetalleScreen(evento: evento),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: eventoPasado
                          ? const Color(0xFFEDEDED)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          color: eventoPasado
                              ? Colors.grey.withOpacity(0.25)
                              : const Color(0xFF3B82F6).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          eventoPasado ? Icons.event_busy : Icons.event_note,
                          color:
                              eventoPasado ? Colors.grey : const Color(0xFF3B82F6),
                        ),
                      ),
                      title: Text(
                        evento.titulo,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: eventoPasado ? Colors.grey[700] : Colors.black,
                          decoration: eventoPasado
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(evento.descripcion),
                            if (evento.imagenPath != null &&
                                evento.imagenPath!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    base64Decode(evento.imagenPath!.split(',').last),
                                    fit: BoxFit.cover,
                                    height: 160,
                                    width: double.infinity,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today,
                                    size: 16, color: Colors.redAccent),
                                const SizedBox(width: 4),
                                Text(evento.fecha,
                                    style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.person,
                                    size: 16, color: Colors.blueAccent),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Creado por: ${evento.creadoPor} (#${evento.id})',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  bool _esEventoPasado(Evento evento) {
    try {
      final partes = evento.fecha.split(' - ');
      final fechaStr = partes[0];
      final horaStr = partes.length > 1 ? partes[1] : '00H00';
      final horaParseada = horaStr.replaceAll('H', ':');
      final fechaCompleta =
          DateFormat('yyyy-MM-dd HH:mm').parse('$fechaStr $horaParseada');
      return fechaCompleta.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }
}
*/
