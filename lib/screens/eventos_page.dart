import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nutri/base/base.dart';
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

  int _getEstado(dynamic evento) {
    try {
      // Caso: modelo Evento
      if (evento is Evento) {
        final v = evento.estado;
        if (v is int) return v;
        if (v is String) return int.tryParse(v as String) ?? 1;
        return 1;
      }

      // Caso: Map (cuando viene como dynamic)
      if (evento is Map) {
        final v = evento['estado'];
        if (v is int) return v;
        if (v is String) return int.tryParse(v) ?? 1;
      }
    } catch (_) {}

    return 1; // default: NO pendiente
  }


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

    // Inset físico de la barra de estado / notch. Usamos viewPadding (no
    // padding) para que siempre refleje el notch real en iOS aunque algún
    // ancestro haya consumido el SafeArea.
    final double topInset = MediaQuery.of(context).viewPadding.top;

    return Scaffold(
      backgroundColor: Base().COLOR_BLANCO,
      body: Stack(
        children: [
          // Fondo azul superior con curva (se extiende bajo la barra de estado)
          ClipPath(
            clipper: EventosWaveClipper(),
            child: Container(
              height: 120 + topInset,
              decoration: BoxDecoration(
                color: Base().COLOR_AZUL_CORP,
              ),
            ),
          ),

          Column(
            children: [
              // Header (debajo de la barra de estado en ambas plataformas)
              Padding(
                padding: EdgeInsets.fromLTRB(16, topInset + 12, 16, 12),
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
                  child: SafeArea(
                    top: false,
                    child: _cargando
                      ? Center(
                          child: CircularProgressIndicator(
                            color: Base().COLOR_AZUL_CORP,
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
                                          children: [
                                            Text(
                                              'Eventos Corporativos',
                                              style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: Base().COLOR_AZUL_CORP,
                                              ),
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Revisa Todos los Eventos',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Base().COLOR_AZUL_CORP,
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
                                  child: Text(
                                    'Eventos',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Base().COLOR_AZUL_CORP,
                                    ),
                                  ),
                                ),
                                
                                // Lista de eventos
                                eventos.isEmpty
                                    ? Container(
                                        padding: const EdgeInsets.all(40),
                                        child: Center(
                                          child: Text(
                                            'No hay eventos disponibles actualmente.',
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: Base().COLOR_GRIS,
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
                ),
              ],
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
    final bool isPendiente = (evento.estado == 0);

    return GestureDetector(
      onTap: () async {
        // 1) Abre detalle
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetalleEventoScreen(evento: evento),
          ),
        );

        // 2) Si estaba pendiente, márcalo como visto (backend) y refresca lista
        if (isPendiente) {
          try {
            // Actualiza backend
            await context.read<EventoService>().marcarEventoComoVisto(
              idUsuario: idUsuario,
              idEvento: evento.idEvento, // revisa: idEvento vs id
            );

            // Refresca lista para que cambie el estado en UI
            await context.read<EventoService>().obtenerEventos(idUsuario: idUsuario);
          } catch (e) {
            debugPrint("Error marcando visto: $e");
          }
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
            // Icono del evento + badge pendiente
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Base().COLOR_AZUL_CORP.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getEventIcon(),
                    color: Base().COLOR_AZUL_CORP,
                    size: 32,
                  ),
                ),

                if (isPendiente)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 16),

            // Información del evento
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título + chip "Pendiente"
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          evento.titulo,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Base().COLOR_AZUL_CORP,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  Text(
                    evento.fecha,
                    style: TextStyle(
                      fontSize: 13,
                      color: Base().COLOR_GRIS,
                    ),
                  ),

                  if (evento.horaEvento.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      evento.horaEvento,
                      style: TextStyle(
                        fontSize: 13,
                        color: Base().COLOR_GRIS,
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