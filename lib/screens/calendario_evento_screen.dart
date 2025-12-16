import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/calendario_evento.dart';
import '../models/cumpleanios.dart';
import '../services/calendario_evento_service.dart';
import '../core/notification_banner.dart';
import 'detalle_evento_screen.dart';
import 'detalle_cumpleanios_screen.dart';

class CalendarioEventosScreen extends StatefulWidget {
  const CalendarioEventosScreen({super.key});

  @override
  State<CalendarioEventosScreen> createState() =>
      _CalendarioEventosScreenState();
}

class _CalendarioEventosScreenState extends State<CalendarioEventosScreen> {
  final Map<DateTime, List<dynamic>> _eventosPorFecha = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _cargando = true;

  CalendarioEventoService? _servicioGuardado;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _servicioGuardado = context.read<CalendarioEventoService>();
      await _inicializarConexion();
    });
  }

  Future<void> _inicializarConexion() async {
    try {
      await _servicioGuardado?.cargarTodo(context);
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) _refrescarCalendario();
      if (mounted) setState(() => _cargando = false);
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        NotificationBanner.show(
          context,
          '⚠️ Error al conectar con el servidor: $e',
          NotificationType.error,
        );
      }
    }

    _servicioGuardado?.addListener(() {
      if (mounted) _refrescarCalendario();
    });
  }

  void _refrescarCalendario() {
    if (!mounted) return;
    final servicio = _servicioGuardado;
    if (servicio == null) return;

    final eventos = servicio.eventos;
    final cumpleanios = servicio.cumpleanios;
    final Map<DateTime, List<dynamic>> agrupados = {};

    DateTime? parseFecha(String fecha) {
      try {
        if (fecha.isEmpty || fecha == "0000-00-00") return null;
        if (fecha.contains("/")) {
          return DateFormat("dd/MM/yyyy").parse(fecha);
        } else if (fecha.contains("-")) {
          return DateFormat("yyyy-MM-dd").parse(fecha);
        }
      } catch (_) {}
      return null;
    }

    // EVENTOS
    for (var e in eventos) {
      final fechaParseada = parseFecha(e.fecha) ?? DateTime.now();
      final dia =
          DateTime(fechaParseada.year, fechaParseada.month, fechaParseada.day);
      agrupados.putIfAbsent(dia, () => []);
      agrupados[dia]!.add(e);
    }

    // CUMPLEAÑOS
    for (var c in cumpleanios) {
      final fechaParseada = parseFecha(c.fecha) ?? DateTime.now();
      final dia =
          DateTime(fechaParseada.year, fechaParseada.month, fechaParseada.day);
      agrupados.putIfAbsent(dia, () => []);
      if (!agrupados[dia]!
          .any((x) => x is Cumpleanios && x.idCumpleanios == c.idCumpleanios)) {
        agrupados[dia]!.add(c);
      }
    }

    setState(() {
      _eventosPorFecha
        ..clear()
        ..addAll(agrupados);
    });
  }

  List<dynamic> _obtenerEventos(DateTime day) {
    final normalizado = DateTime(day.year, day.month, day.day);
    return _eventosPorFecha[normalizado] ?? [];
  }

  // MODIFICADO: Ahora muestra eventos según el contexto
  List<dynamic> _obtenerEventosParaMostrar() {
    // Si hay una fecha seleccionada, mostrar SOLO los eventos de esa fecha (pasados o futuros)
    if (_selectedDay != null) {
      final normalizado = DateTime(
        _selectedDay!.year,
        _selectedDay!.month,
        _selectedDay!.day,
      );
      return _eventosPorFecha[normalizado] ?? [];
    }
    
    // Si NO hay fecha seleccionada, mostrar TODOS los próximos eventos (futuros)
    final hoy = DateTime.now();
    final hoyNormalizado = DateTime(hoy.year, hoy.month, hoy.day);
    
    List<MapEntry<DateTime, List<dynamic>>> proximosList = [];
    
    _eventosPorFecha.forEach((fecha, items) {
      // Incluir eventos de hoy y futuros
      if (fecha.isAfter(hoyNormalizado) || fecha.isAtSameMomentAs(hoyNormalizado)) {
        proximosList.add(MapEntry(fecha, items));
      }
    });
    
    // Ordenar por fecha ascendente
    proximosList.sort((a, b) => a.key.compareTo(b.key));
    
    // Retornar TODOS los eventos futuros (no limitado a 5)
    List<dynamic> resultado = [];
    for (var entry in proximosList) {
      resultado.addAll(entry.value);
    }
    
    return resultado;
  }

  @override
  Widget build(BuildContext context) {
    final servicio = context.watch<CalendarioEventoService>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0052A3)))
          : Stack(
              children: [
                // Fondo azul superior con curva
                ClipPath(
                  clipper: CalendarioWaveClipper(),
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
                              'CALENDARIO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.white, size: 26),
                              onPressed: () async {
                                setState(() => _cargando = true);
                                await _servicioGuardado?.cargarTodo(context);
                                if (mounted) _refrescarCalendario();
                                setState(() => _cargando = false);
                              },
                            ),
                          ],
                        ),
                      ),
                      
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              // Card del Calendario
                              Container(
                                margin: const EdgeInsets.all(16),
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
                                  children: [
                                    // Título y leyendas
                                    Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        children: [
                                          const Text(
                                            'Visualiza Eventos Programados\ny Cumpleaños Corporativos',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF666666),
                                              height: 1.5,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              _buildLeyendaChip(
                                                icon: Icons.event_note,
                                                label: 'Eventos',
                                                color: const Color(0xFF0052A3),
                                              ),
                                              const SizedBox(width: 12),
                                              _buildLeyendaChip(
                                                icon: Icons.cake,
                                                label: 'Cumpleaños',
                                                color: const Color(0xFF0052A3),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    const Divider(height: 1),
                                    
                                    // Calendario
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: _buildCalendario(),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Próximos Eventos o Eventos del día seleccionado
                              Container(
                                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F4F8),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // MODIFICADO: Título con botón para limpiar selección
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _selectedDay != null
                                                ? 'EVENTOS DEL ${DateFormat('dd/MM/yyyy').format(_selectedDay!)}'
                                                : 'PRÓXIMOS EVENTOS',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0052A3),
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                        // Botón para ver todos los próximos eventos
                                        if (_selectedDay != null)
                                          TextButton.icon(
                                            onPressed: () {
                                              setState(() {
                                                _selectedDay = null;
                                              });
                                            },
                                            icon: const Icon(
                                              Icons.calendar_month,
                                              size: 18,
                                              color: Color(0xFF0052A3),
                                            ),
                                            label: const Text(
                                              'Ver Próximos',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF0052A3),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              backgroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(20),
                                                side: const BorderSide(
                                                  color: Color(0xFF0052A3),
                                                  width: 1.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    _buildProximosEventos(),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 20),
                            ],
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

  Widget _buildLeyendaChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendario() {
    return TableCalendar(
      focusedDay: _focusedDay,
      firstDay: DateTime(2000),
      lastDay: DateTime(2100),
      locale: 'es_ES',
      calendarFormat: CalendarFormat.month,
      startingDayOfWeek: StartingDayOfWeek.monday,
      eventLoader: _obtenerEventos,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: (selected, focused) {
        setState(() {
          _selectedDay = selected;
          _focusedDay = focused;
        });
      },
      calendarStyle: CalendarStyle(
        outsideDaysVisible: true,
        outsideTextStyle: const TextStyle(color: Color(0xFFCCCCCC)),
        weekendTextStyle: const TextStyle(color: Colors.black87),
        todayDecoration: BoxDecoration(
          color: const Color(0xFF0052A3).withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        todayTextStyle: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
        ),
        selectedDecoration: const BoxDecoration(
          color: Color(0xFF0052A3),
          shape: BoxShape.circle,
        ),
        selectedTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        markerDecoration: const BoxDecoration(
          color: Color(0xFF0052A3),
          shape: BoxShape.circle,
        ),
        markersMaxCount: 1,
        defaultTextStyle: const TextStyle(color: Colors.black87),
      ),
      headerStyle: HeaderStyle(
        titleTextStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Color(0xFF0052A3),
        ),
        titleCentered: true,
        formatButtonVisible: false,
        leftChevronIcon: const Icon(Icons.chevron_left, color: Color(0xFF0052A3)),
        rightChevronIcon: const Icon(Icons.chevron_right, color: Color(0xFF0052A3)),
        headerPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: Colors.black54,
        ),
        weekendStyle: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: Colors.black54,
        ),
      ),
    );
  }

  Widget _buildProximosEventos() {
    // MODIFICADO: Usa la nueva función que decide qué mostrar
    final eventosAMostrar = _obtenerEventosParaMostrar();
    
    if (eventosAMostrar.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            _selectedDay != null
                ? 'No hay eventos programados para esta fecha'
                : 'No hay eventos próximos programados',
            style: const TextStyle(
              color: Color(0xFF666666),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: eventosAMostrar.map((item) {
        if (item is CalendarioEvento) {
          return _buildEventoCard(
            icon: Icons.event,
            titulo: item.titulo,
            subtitulo: item.descripcion,
            color: const Color(0xFF0052A3),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetalleEventoScreen(evento: item),
                ),
              );
            },
          );
        } else if (item is Cumpleanios) {
          return _buildEventoCard(
            icon: Icons.cake,
            titulo: item.titulo,
            subtitulo: item.descripcion,
            color: const Color(0xFF0052A3),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetalleCumpleaniosScreen(cumple: item),
                ),
              );
            },
          );
        }
        return const SizedBox.shrink();
      }).toList(),
    );
  }

  Widget _buildEventoCard({
    required IconData icon,
    required String titulo,
    required String subtitulo,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0052A3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitulo,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF666666),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CalendarioWaveClipper extends CustomClipper<Path> {
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