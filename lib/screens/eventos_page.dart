import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nutri/base/base.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/evento.dart';
import '../services/evento_service.dart';
import '../core/notification_banner.dart';
import '../services/auth_service.dart';
import '../widget/eliminar_notificacion.dart';
import 'detalle_evento_screen.dart';

class EventosPage extends StatefulWidget {
  const EventosPage({super.key});

  @override
  State<EventosPage> createState() => _EventosPageState();
}

class _EventosPageState extends State<EventosPage> {
  bool _cargando = true;
  int idUsuario = 0;

  /// Selección múltiple: se activa manteniendo pulsada una tarjeta.
  bool _modoSeleccion = false;
  final Set<int> _seleccionados = <int>{};

  void _alternarSeleccion(int idEvento) {
    setState(() {
      if (!_seleccionados.remove(idEvento)) _seleccionados.add(idEvento);
      // Al deseleccionar el último ítem se sale del modo: quedarse con la barra
      // de selección vacía no aporta nada.
      if (_seleccionados.isEmpty) _modoSeleccion = false;
    });
  }

  void _iniciarSeleccion(int idEvento) {
    setState(() {
      _modoSeleccion = true;
      _seleccionados.add(idEvento);
    });
  }

  /// Entra al modo selección sin marcar nada (botón del encabezado).
  void _activarModoSeleccion() {
    setState(() => _modoSeleccion = true);
  }

  void _salirDeSeleccion() {
    setState(() {
      _modoSeleccion = false;
      _seleccionados.clear();
    });
  }

  void _seleccionarTodos(List<Evento> eventos) {
    setState(() {
      if (_seleccionados.length == eventos.length) {
        _seleccionados.clear();
        _modoSeleccion = false;
      } else {
        _seleccionados
          ..clear()
          ..addAll(eventos.map((e) => e.idEvento));
      }
    });
  }

  /// Los seleccionados que el usuario todavía no vio.
  List<int> _sinVer(List<Evento> lista) => [
    for (final x in lista)
      if (x.estado == 0 && _seleccionados.contains(x.idEvento)) x.idEvento,
  ];

  /// Marca como vistos [ids] en el servidor. La selección se conserva para
  /// que el usuario pueda eliminarlos a continuación.
  Future<void> _marcarComoVistos(List<int> ids) async {
    final service = context.read<EventoService>();
    final messenger = ScaffoldMessenger.of(context);

    var fallidos = 0;
    for (final id in ids) {
      final ok = await service.marcarEventoComoVisto(
        idUsuario: idUsuario,
        idEvento: id,
      );
      if (!ok) fallidos++;
    }

    if (!mounted) return;
    setState(() {});
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          fallidos == 0
              ? (ids.length == 1
                  ? 'Marcada como vista'
                  : '${ids.length} marcadas como vistas')
              : 'No se pudieron marcar $fallidos. Revisa tu conexión.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Elimina todo lo seleccionado con una sola confirmación.
  ///
  /// Se reusa `eliminarEvento` uno por uno: ya hace el borrado optimista, el
  /// registro en los ocultos locales y el POST. El backend no tiene un endpoint
  /// de borrado en lote.
  Future<void> _eliminarSeleccionados() async {
    final service = context.read<EventoService>();
    final messenger = ScaffoldMessenger.of(context);
    final ids = _seleccionados.toList();
    if (ids.isEmpty) return;

    // Solo se elimina lo que ya se vio. Si queda algo sin ver no se borra
    // nada: se ofrece marcarlo y el usuario vuelve a eliminar.
    final sinVer = _sinVer(service.eventos);
    if (sinVer.isNotEmpty) {
      if (await avisarNoVisto(context, cantidad: sinVer.length)) {
        await _marcarComoVistos(sinVer);
      }
      return;
    }
    if (!mounted) return;

    final confirmado = await confirmarEliminacion(
      context,
      titulo:
          ids.length == 1
              ? 'Eliminar notificación'
              : 'Eliminar ${ids.length} notificaciones',
      mensaje:
          ids.length == 1
              ? '¿Quieres quitar la notificación seleccionada de tu lista? '
                  'No volverá a aparecer en la app.'
              : '¿Quieres quitar las ${ids.length} notificaciones seleccionadas de '
                  'tu lista? No volverán a aparecer en la app.',
    );
    if (!confirmado) return;

    var fallidos = 0;
    for (final id in ids) {
      final ok = await service.eliminarEvento(
        idUsuario: idUsuario,
        idEvento: id,
      );
      if (!ok) fallidos++;
    }

    if (!mounted) return;
    _salirDeSeleccion();

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          fallidos == 0
              ? (ids.length == 1
                  ? 'Notificación eliminada'
                  : '${ids.length} notificaciones eliminadas')
              : 'Se quitaron de tu lista, pero $fallidos no se pudieron '
                  'sincronizar.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

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
              decoration: BoxDecoration(color: Base().COLOR_AZUL_CORP),
            ),
          ),

          Column(
            children: [
              // Header (debajo de la barra de estado en ambas plataformas).
              // En modo selección se reemplaza por la barra de acciones.
              Padding(
                padding: EdgeInsets.fromLTRB(16, topInset + 12, 16, 12),
                child:
                    _modoSeleccion
                        ? Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 26,
                              ),
                              tooltip: 'Cancelar selección',
                              onPressed: _salirDeSeleccion,
                            ),
                            Expanded(
                              child: Text(
                                '${_seleccionados.length} seleccionado'
                                '${_seleccionados.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.select_all,
                                color: Colors.white,
                                size: 24,
                              ),
                              tooltip: 'Seleccionar todos',
                              onPressed: () => _seleccionarTodos(eventos),
                            ),
                            // Marcar como vistos: es el paso previo a eliminar lo que
                            // todavía no se abrió.
                            IconButton(
                              icon: Icon(
                                Icons.done_all,
                                color:
                                    _sinVer(eventos).isEmpty
                                        ? Colors.white38
                                        : Colors.white,
                                size: 24,
                              ),
                              tooltip: 'Marcar como vistos',
                              onPressed:
                                  _sinVer(eventos).isEmpty
                                      ? null
                                      : () =>
                                          _marcarComoVistos(_sinVer(eventos)),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color:
                                    _seleccionados.isEmpty
                                        ? Colors.white38
                                        : Colors.white,
                                size: 26,
                              ),
                              tooltip: 'Eliminar seleccionados',
                              onPressed:
                                  _seleccionados.isEmpty
                                      ? null
                                      : _eliminarSeleccionados,
                            ),
                          ],
                        )
                        : Row(
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
                                'EVENTOS CORPORATIVOS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            // Entrada visible al borrado múltiple: el long-press
                            // sobre una tarjeta hace lo mismo, pero no se ve.
                            if (eventos.isNotEmpty)
                              IconButton(
                                icon: const Icon(
                                  Icons.checklist,
                                  color: Colors.white,
                                  size: 26,
                                ),
                                tooltip: 'Seleccionar varios',
                                onPressed: _activarModoSeleccion,
                              ),
                          ],
                        ),
              ),

              Expanded(
                child: SafeArea(
                  top: false,
                  child:
                      _cargando
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Texto a la izquierda
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
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
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                                    margin: const EdgeInsets.fromLTRB(
                                      16,
                                      8,
                                      16,
                                      16,
                                    ),
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
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        child: Column(
                                          children:
                                              eventos.map((evento) {
                                                return _EventoItem(
                                                  evento: evento,
                                                  idUsuario: idUsuario,
                                                  modoSeleccion: _modoSeleccion,
                                                  seleccionado: _seleccionados
                                                      .contains(
                                                        evento.idEvento,
                                                      ),
                                                  onIniciarSeleccion:
                                                      () => _iniciarSeleccion(
                                                        evento.idEvento,
                                                      ),
                                                  onAlternarSeleccion:
                                                      () => _alternarSeleccion(
                                                        evento.idEvento,
                                                      ),
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
  const _EventoItem({
    required this.evento,
    required this.idUsuario,
    required this.modoSeleccion,
    required this.seleccionado,
    required this.onIniciarSeleccion,
    required this.onAlternarSeleccion,
  });
  final Evento evento;
  final int idUsuario;
  final bool modoSeleccion;
  final bool seleccionado;
  final VoidCallback onIniciarSeleccion;
  final VoidCallback onAlternarSeleccion;

  IconData _getEventIcon() {
    if (evento.titulo.toLowerCase().contains('navidad')) {
      return Icons.card_giftcard;
    } else if (evento.titulo.toLowerCase().contains('capacitación') ||
        evento.titulo.toLowerCase().contains('capacitacion')) {
      return Icons.school;
    }
    return Icons.event;
  }

  Future<bool> _confirmarEliminar(BuildContext context) {
    return confirmarEliminacion(
      context,
      titulo: 'Eliminar notificación',
      mensaje:
          '¿Quieres quitar "${evento.titulo}" de tu lista? No volverá a aparecer en la app.',
    );
  }

  /// Pide confirmación y elimina. Se toman el servicio y el messenger antes de
  /// abrir el diálogo porque la tarjeta desaparece del árbol al eliminarse.
  Future<void> _eliminarConConfirmacion(BuildContext context) async {
    final service = context.read<EventoService>();
    final messenger = ScaffoldMessenger.of(context);

    if (evento.estado == 0) {
      if (await avisarNoVisto(context)) {
        await service.marcarEventoComoVisto(
          idUsuario: idUsuario,
          idEvento: evento.idEvento,
        );
      }
      return;
    }

    if (!await _confirmarEliminar(context)) return;

    await _eliminar(service, messenger);
  }

  /// Envía el POST al backend y avisa el resultado. La tarjeta ya se quitó de
  /// la lista antes de llegar aquí (borrado optimista en el servicio).
  Future<void> _eliminar(
    EventoService service,
    ScaffoldMessengerState messenger,
  ) async {
    final ok = await service.eliminarEvento(
      idUsuario: idUsuario,
      idEvento: evento.idEvento,
    );

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Notificación eliminada'
              : 'Se quitó de tu lista, pero no se pudo sincronizar.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isPendiente = (evento.estado == 0);

    return Dismissible(
      key: ValueKey('evento_${evento.idEvento}'),
      // Con la selección activa el swipe estorba: el gesto lo maneja la lista.
      direction:
          modoSeleccion ? DismissDirection.none : DismissDirection.endToStart,
      background: const FondoEliminar(),
      // Sin ver no se desliza a eliminar: se ofrece marcarla y la tarjeta
      // vuelve a su lugar.
      confirmDismiss: (_) async {
        if (evento.estado != 0) return _confirmarEliminar(context);
        final service = context.read<EventoService>();
        if (await avisarNoVisto(context)) {
          await service.marcarEventoComoVisto(
            idUsuario: idUsuario,
            idEvento: evento.idEvento,
          );
        }
        return false;
      },
      onDismissed:
          (_) => _eliminar(
            context.read<EventoService>(),
            ScaffoldMessenger.of(context),
          ),
      child: _buildTarjeta(context, isPendiente),
    );
  }

  Widget _buildTarjeta(BuildContext context, bool isPendiente) {
    return GestureDetector(
      // Mantener pulsado entra al modo selección, como en las apps de correo.
      onLongPress: modoSeleccion ? null : onIniciarSeleccion,
      onTap: () async {
        // Con la selección activa, tocar marca/desmarca en vez de abrir.
        if (modoSeleccion) {
          onAlternarSeleccion();
          return;
        }

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
            await context.read<EventoService>().obtenerEventos(
              idUsuario: idUsuario,
            );
          } catch (e) {
            debugPrint("Error marcando visto: $e");
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              seleccionado
                  ? Base().COLOR_AZUL_CORP.withOpacity(0.08)
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border:
              seleccionado
                  ? Border.all(color: Base().COLOR_AZUL_CORP, width: 1.5)
                  : null,
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
                    style: TextStyle(fontSize: 13, color: Base().COLOR_GRIS),
                  ),

                  if (evento.horaEvento.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      evento.horaEvento,
                      style: TextStyle(fontSize: 13, color: Base().COLOR_GRIS),
                    ),
                  ],
                ],
              ),
            ),

            // En modo selección el botón de borrar cede su lugar a la casilla:
            // el borrado pasa a hacerse desde la barra superior, en lote.
            if (modoSeleccion)
              Checkbox(
                value: seleccionado,
                onChanged: (_) => onAlternarSeleccion(),
                activeColor: Base().COLOR_AZUL_CORP,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              )
            else
              // Eliminar de la lista. Se deja visible (además del swipe) para
              // que la opción sea evidente.
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: Base().COLOR_GRIS,
                  size: 22,
                ),
                tooltip: 'Eliminar notificación',
                onPressed: () => _eliminarConConfirmacion(context),
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
