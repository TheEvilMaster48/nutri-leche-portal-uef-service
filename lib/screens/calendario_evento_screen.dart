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

class _CalendarioEventosScreenState extends State<CalendarioEventosScreen>
    with SingleTickerProviderStateMixin {
  final Map<DateTime, List<dynamic>> _eventosPorFecha = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _panelVisible = false;
  bool _cargando = true;

  late final AnimationController _controller;
  CalendarioEventoService? _servicioGuardado;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

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

    DateTime? _parseFecha(String fecha) {
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
      final fechaParseada = _parseFecha(e.fecha) ?? DateTime.now();
      final dia =
          DateTime(fechaParseada.year, fechaParseada.month, fechaParseada.day);
      agrupados.putIfAbsent(dia, () => []);
      agrupados[dia]!.add(e);
    }

    // CUMPLEAÑOS
    for (var c in cumpleanios) {
      final fechaParseada = _parseFecha(c.fecha) ?? DateTime.now();
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

  void _togglePanel() {
    if (!mounted) return;
    setState(() {
      _panelVisible = !_panelVisible;
      _panelVisible ? _controller.forward() : _controller.reverse();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final servicio = context.watch<CalendarioEventoService>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 3,
        backgroundColor: Colors.white,
        title: const Text(
          'Calendario Corporativo',
          style: TextStyle(
            color: Colors.teal,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.teal),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.teal),
            onPressed: () async {
              setState(() => _cargando = true);
              await _servicioGuardado?.cargarTodo(context);
              if (mounted) _refrescarCalendario();
              setState(() => _cargando = false);
            },
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : Stack(
              children: [
                Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "Visualiza Eventos Programados y Cumpleaños Corporativos",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildLeyendaProfesional(),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 7,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _buildCalendario(),
                      ),
                    ),
                    const SizedBox(height: 90),
                  ],
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 400),
                  bottom: _panelVisible ? 0 : -260,
                  left: 0,
                  right: 0,
                  height: 300,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(22)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 16,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          height: 5,
                          width: 50,
                          decoration: BoxDecoration(
                            color: Colors.teal.shade100,
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _panelVisible
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_up,
                            color: Colors.teal.shade700,
                            size: 30,
                          ),
                          onPressed: _togglePanel,
                        ),
                        Expanded(child: _buildEventosDelDia(servicio)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLeyendaProfesional() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 20,
      runSpacing: 10,
      children: [
        _leyendaItem(Icons.cake, Colors.pinkAccent, 'Cumpleaños'),
        _leyendaItem(Icons.event, Colors.blue, 'Evento'),
      ],
    );
  }

  Widget _leyendaItem(IconData icon, Color color, String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.6)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            texto,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.black87,
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
          _panelVisible = true;
          _controller.forward();
        });
      },
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        todayDecoration:
            BoxDecoration(color: Colors.teal.shade200, shape: BoxShape.circle),
        selectedDecoration:
            BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
      ),
      headerStyle: HeaderStyle(
        titleTextStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: Colors.teal,
        ),
        titleCentered: true,
        formatButtonVisible: false,
        leftChevronIcon:
            Icon(Icons.chevron_left, color: Colors.teal.shade700),
        rightChevronIcon:
            Icon(Icons.chevron_right, color: Colors.teal.shade700),
      ),
    );
  }

  Widget _buildEventosDelDia(CalendarioEventoService servicio) {
    final eventos = _obtenerEventos(_selectedDay ?? DateTime.now());
    if (eventos.isEmpty) {
      return const Center(
        child: Text(
          'No hay actividades registradas para esta fecha.',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: eventos.length,
      itemBuilder: (context, index) {
        final item = eventos[index];
        late final Color color;
        late final IconData icono;
        late final String titulo;
        late final String detalle;

        if (item is Cumpleanios) {
          color = Colors.pinkAccent;
          icono = Icons.cake;
          titulo = item.titulo;
          detalle = item.descripcion;
        } else if (item is CalendarioEvento) {
          color = Colors.blue;
          icono = Icons.event;
          titulo = item.titulo;
          detalle = item.descripcion;
        } else {
          color = Colors.grey;
          icono = Icons.info_outline;
          titulo = 'Evento desconocido';
          detalle = '';
        }

        return GestureDetector(
          onTap: () {
            if (item is Cumpleanios) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetalleCumpleaniosScreen(cumple: item),
                ),
              );
            } else if (item is CalendarioEvento) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetalleEventoScreen(evento: item),
                ),
              );
            }
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color, width: 1.5),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: color,
                child: Icon(icono, color: Colors.white),
              ),
              title: Text(
                titulo,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              subtitle:
                  Text(detalle, style: const TextStyle(color: Colors.black54)),
            ),
          ),
        );
      },
    );
  }
}
