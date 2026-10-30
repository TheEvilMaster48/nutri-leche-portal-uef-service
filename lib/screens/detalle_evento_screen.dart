import 'package:flutter/material.dart';
import 'package:nutri/base/base.dart';

import '../models/evento.dart';
import '../models/calendario_evento.dart';
import '../models/reaccion.dart';
import '../widget/adjunto_multimedia.dart';
import '../widget/barra_reacciones.dart';
import '../widget/texto_con_enlaces.dart';

class DetalleEventoScreen extends StatefulWidget {
  final dynamic evento;
  const DetalleEventoScreen({super.key, required this.evento});

  @override
  State<DetalleEventoScreen> createState() => _DetalleEventoScreenState();
}

class _DetalleEventoScreenState extends State<DetalleEventoScreen> {
  @override
  Widget build(BuildContext context) {
    final evento = widget.evento;

    final String titulo = evento.titulo ?? '';
    final String descripcion = evento.descripcion ?? '';
    final String fecha =
    (evento is Evento) ? evento.fecha : (evento.fecha ?? '');
    final String hora =
    (evento is Evento)
        ? (evento.horaEvento.isNotEmpty ? evento.horaEvento : '')
        : (evento.hora ?? '');

    // Las reacciones se guardan contra el id del evento corporativo.
    //
    // Esta pantalla se reutiliza para el calendario (CalendarioEvento), y esos
    // registros salen del MISMO `ObtenerEventos`: su `id` es el `idEvento`. Por
    // eso ambos casos reaccionan sobre el mismo contenido y lo que se marque
    // desde el calendario se ve también en la lista de eventos.
    final int idParaReacciones = (evento is Evento)
        ? evento.idEvento
        : (evento is CalendarioEvento ? evento.id : 0);

    // Inset físico de la barra de estado / notch (consistente iOS/Android).
    final double topInset = MediaQuery.of(context).viewPadding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          ClipPath(
            clipper: DetalleEventoWaveClipper(),
            child: Container(
              height: 120 + topInset,
              decoration: BoxDecoration(color: Base().COLOR_AZUL_CORP),
            ),
          ),
          Column(
            children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, topInset + 12, 16, 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'DETALLE DEL EVENTO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [

                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    titulo,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Base().COLOR_AZUL_CORP,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: Base().COLOR_AZUL_CORP,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _buildInfoRow(
                                    icon: Icons.description,
                                    label: 'Descripción',
                                    value: descripcion,
                                    detectarEnlaces: true,
                                  ),
                                  const SizedBox(height: 20),
                                  if (fecha.trim().isNotEmpty) ...[
                                    _buildInfoRow(
                                      icon: Icons.calendar_month_outlined,
                                      label: 'Fecha',
                                      value: fecha,
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  if (hora.trim().isNotEmpty) ...[
                                    _buildInfoRow(
                                      icon: Icons.access_time,
                                      label: 'Hora',
                                      value: hora,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // Solo se dibuja si el evento realmente trae un
                            // archivo (si no, el widget no ocupa espacio).
                            AdjuntoMultimedia(
                              url: (evento is Evento)
                                  ? evento.imagenPath
                                  : (evento is CalendarioEvento)
                                      ? evento.imagenBase64
                                      : (evento.imagenBase64 ??
                                          evento.imagenPath),
                              titulo: titulo,
                            ),
                            // id 0 = registro sin identificar: no hay contra qué
                            // guardar la reacción.
                            if (idParaReacciones > 0)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    24, 20, 24, 24),
                                child: BarraReacciones(
                                  origen: OrigenReaccion.evento,
                                  idContenido: idParaReacciones,
                                ),
                              ),
                          ],
                        ),
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

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool detectarEnlaces = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Base().COLOR_AZUL_CORP.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Base().COLOR_AZUL_CORP, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Base().COLOR_AZUL_CORP,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Builder(builder: (_) {
                  final estilo = TextStyle(
                    fontSize: 15,
                    color: Base().COLOR_GRIS,
                    height: 1.4,
                  );
                  return detectarEnlaces
                      ? TextoConEnlaces(texto: value, estilo: estilo)
                      : Text(value, style: estilo);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DetalleEventoWaveClipper extends CustomClipper<Path> {
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
      secondControlPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
