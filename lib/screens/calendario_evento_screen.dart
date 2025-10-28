import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/calendario_evento.dart';
import '../models/cumpleanios.dart';
import '../services/calendario_evento_service.dart';
import '../services/cumpleanios_service.dart';
import '../core/notification_banner.dart';
import 'celebracion_screen.dart';

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
  late AnimationController _controller;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _cargarEventosYCumpleanios();
  }

  // CARGAR EVENTOS Y CUMPLEAÑOS DESDE EL BACKEND
  Future<void> _cargarEventosYCumpleanios() async {
    try {
      final eventoService = context.read<CalendarioEventoService>();
      final cumpleService = CumpleaniosService();

      await eventoService.obtenerEventos(context);
      final eventos = eventoService.eventos;
      final cumpleanios = await cumpleService.listarCumpleanios(context);

      final Map<DateTime, List<dynamic>> agrupados = {};

      // AGRUPAR EVENTOS
      for (var e in eventos) {
        final dia = DateTime(e.fechaInicio.year, e.fechaInicio.month, e.fechaInicio.day);
        agrupados.putIfAbsent(dia, () => []);
        agrupados[dia]!.add(e);
      }

      // AGRUPAR CUMPLEAÑOS
      for (var c in cumpleanios) {
        final dia = DateTime(DateTime.now().year, c.fechaNacimiento.month, c.fechaNacimiento.day);
        agrupados.putIfAbsent(dia, () => []);
        agrupados[dia]!.add(c);
      }

      setState(() {
        _eventosPorFecha
          ..clear()
          ..addAll(agrupados);
        _cargando = false;
      });
    } catch (e) {
      setState(() => _cargando = false);
      NotificationBanner.show(
        context,
        'Error al cargar eventos: $e',
        NotificationType.error,
      );
    }
  }

  List<dynamic> _obtenerEventos(DateTime day) {
    final normalizado = DateTime(day.year, day.month, day.day);
    return _eventosPorFecha[normalizado] ?? [];
  }

  void _togglePanel() {
    setState(() {
      _panelVisible = !_panelVisible;
      if (_panelVisible) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal.shade700,
        title: const Text(
          'Calendario de Eventos',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            tooltip: 'Ir a Celebraciones',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const CelebracionesScreen()),
              );
            },
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      flex: 7,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _buildCalendario(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.cake, color: Colors.pinkAccent, size: 22),
                          SizedBox(width: 6),
                          Text('Cumpleaños'),
                          SizedBox(width: 20),
                          Icon(Icons.event_note, color: Colors.teal, size: 22),
                          SizedBox(width: 6),
                          Text('Eventos'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  bottom: _panelVisible ? 0 : -250,
                  left: 0,
                  right: 0,
                  height: 280,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, -3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: Icon(
                              _panelVisible
                                  ? Icons.keyboard_arrow_down
                                  : Icons.keyboard_arrow_up,
                              color: Colors.teal.shade700,
                              size: 28,
                            ),
                            onPressed: _togglePanel,
                          ),
                        ),
                        Expanded(child: _buildEventosDelDia()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // CONSTRUCCIÓN DEL CALENDARIO
  Widget _buildCalendario() {
    return TableCalendar(
      focusedDay: _focusedDay,
      firstDay: DateTime(1900),
      lastDay: DateTime(4000),
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
        todayDecoration: BoxDecoration(color: Colors.teal.shade300, shape: BoxShape.circle),
        selectedDecoration: BoxDecoration(color: Colors.teal.shade700, shape: BoxShape.circle),
      ),
      headerStyle: HeaderStyle(
        titleCentered: true,
        formatButtonVisible: false,
        leftChevronIcon: Icon(Icons.chevron_left, color: Colors.teal.shade700),
        rightChevronIcon: Icon(Icons.chevron_right, color: Colors.teal.shade700),
      ),
      // MARCADOR UNIFICADO (UN SOLO PUNTO NEGRO)
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, date, eventos) {
          if (eventos.isEmpty) return const SizedBox();
          return Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 35),
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
          );
        },
      ),
    );
  }

  // PANEL INFERIOR CON DETALLES
  Widget _buildEventosDelDia() {
    final eventos = _obtenerEventos(_selectedDay ?? DateTime.now());
    if (eventos.isEmpty) {
      return const Center(
        child: Text(
          'No hay eventos ni cumpleaños en esta fecha.',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: eventos.length,
      itemBuilder: (context, index) {
        final item = eventos[index];
        final bool esCumple = item is Cumpleanios;

        final color = esCumple ? Colors.pinkAccent : Colors.teal;
        final icono = esCumple ? Icons.cake : Icons.event_note;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color,
              child: Icon(icono, color: Colors.white),
            ),
            title: Text(
              esCumple ? '${item.nombre} ${item.apellido}' : item.titulo,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              esCumple
                  ? 'Cumpleaños en ${item.planta}\nFecha: ${DateFormat('dd/MM/yyyy').format(item.fechaNacimiento)}'
                  : '${item.descripcion}\nLugar: ${item.lugar}\nInicio: ${DateFormat('dd/MM/yyyy HH:mm').format(item.fechaInicio)}',
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        );
      },
    );
  }
}
