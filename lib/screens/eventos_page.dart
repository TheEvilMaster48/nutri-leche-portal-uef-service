import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/evento.dart';
import '../services/evento_service.dart';
import '../core/notification_banner.dart';
import '../services/auth_service.dart';
import 'detalle_evento_screen.dart';

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
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          // Fondo azul superior con curva
          ClipPath(
            clipper: EventosWaveClipper(),
            child: Container(
              height: 120,
              decoration: const BoxDecoration(
                color: Color(0xFF0052A3),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'EVENTOS CORPORATIVOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: _cargando
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF0052A3),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            await context
                                .read<EventoService>()
                                .obtenerEventos(idUsuario: idUsuario);
                          },
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                              children: [
                                // Card con imagen y título
                                Container(
                                  margin: const EdgeInsets.all(16),
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0E0E0),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Texto a la izquierda
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: const [
                                            Text(
                                              'Eventos Corporativos',
                                              style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF0052A3),
                                              ),
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Revisa Todos los Eventos',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Color(0xFF666666),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Imagen a la derecha alineada arriba
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.asset(
                                          'assets/icono/detalleevento.jpg',
                                          height: 120,
                                          width: 120,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Título de la sección
                                Container(
                                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                  alignment: Alignment.centerLeft,
                                  child: const Text(
                                    'Eventos',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0052A3),
                                    ),
                                  ),
                                ),
                                
                                // Lista de eventos
                                eventos.isEmpty
                                    ? Container(
                                        padding: const EdgeInsets.all(40),
                                        child: const Center(
                                          child: Text(
                                            'No hay eventos disponibles actualmente.',
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: Color(0xFF666666),
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      )
                                    : Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: Column(
                                          children: eventos.map((evento) {
                                            return _EventoItem(
                                              evento: evento,
                                              idUsuario: idUsuario,
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
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

class _EventoItem extends StatelessWidget {
  const _EventoItem({required this.evento, required this.idUsuario});
  final Evento evento;
  final int idUsuario;

  IconData _getEventIcon() {
    // Puedes personalizar el icono según el tipo de evento
    if (evento.titulo.toLowerCase().contains('navidad')) {
      return Icons.card_giftcard;
    } else if (evento.titulo.toLowerCase().contains('capacitación') || 
               evento.titulo.toLowerCase().contains('capacitacion')) {
      return Icons.school;
    }
    return Icons.event;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icono del evento
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0052A3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getEventIcon(),
                color: const Color(0xFF0052A3),
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            
            // Información del evento
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    evento.titulo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0052A3),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    evento.fecha,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF666666),
                    ),
                  ),
                  if (evento.horaEvento.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      evento.horaEvento,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EventosWaveClipper extends CustomClipper<Path> {
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