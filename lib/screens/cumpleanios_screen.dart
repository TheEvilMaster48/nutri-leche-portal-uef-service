import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nutri/base/base.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cumpleanios.dart';
import '../services/cumpleanios_service.dart';
import '../core/notification_banner.dart';
import '../services/auth_service.dart';
import '../widget/eliminar_notificacion.dart';
import 'detalle_cumpleanios_screen.dart';

class CumpleaniosScreen extends StatefulWidget {
  const CumpleaniosScreen({super.key});

  @override
  State<CumpleaniosScreen> createState() => _CumpleaniosScreenState();
}

class _CumpleaniosScreenState extends State<CumpleaniosScreen> {
  bool _cargando = true;
  int idUsuario = 0;

  /// Selección múltiple: se activa manteniendo pulsada una tarjeta.
  bool _modoSeleccion = false;
  final Set<int> _seleccionados = <int>{};

  void _alternarSeleccion(int idCumpleanios) {
    setState(() {
      if (!_seleccionados.remove(idCumpleanios)) {
        _seleccionados.add(idCumpleanios);
      }
      if (_seleccionados.isEmpty) _modoSeleccion = false;
    });
  }

  void _iniciarSeleccion(int idCumpleanios) {
    setState(() {
      _modoSeleccion = true;
      _seleccionados.add(idCumpleanios);
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

  void _seleccionarTodos(List<Cumpleanios> lista) {
    setState(() {
      if (_seleccionados.length == lista.length) {
        _seleccionados.clear();
        _modoSeleccion = false;
      } else {
        _seleccionados
          ..clear()
          ..addAll(lista.map((c) => c.idCumpleanios));
      }
    });
  }

  /// Elimina todo lo seleccionado con una sola confirmación. Reusa
  /// `eliminarCumpleanios` uno por uno: el backend no tiene borrado en lote.
  Future<void> _eliminarSeleccionados() async {
    final service = context.read<CumpleaniosService>();
    final messenger = ScaffoldMessenger.of(context);
    final ids = _seleccionados.toList();
    if (ids.isEmpty) return;

    final confirmado = await confirmarEliminacion(
      context,
      titulo: ids.length == 1
          ? 'Eliminar notificación'
          : 'Eliminar ${ids.length} notificaciones',
      mensaje: ids.length == 1
          ? '¿Quieres quitar la notificación seleccionada de tu lista? '
              'No volverá a aparecer en la app.'
          : '¿Quieres quitar las ${ids.length} notificaciones seleccionadas de '
              'tu lista? No volverán a aparecer en la app.',
    );
    if (!confirmado) return;

    var fallidos = 0;
    for (final id in ids) {
      final ok = await service.eliminarCumpleanios(
        idUsuario: idUsuario,
        idCumpleanios: id,
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

  @override
  void initState() {
    super.initState();
    _cargarCumpleanios();
  }

  Future<void> _cargarCumpleanios() async {
    final cumpleaniosService = context.read<CumpleaniosService>();

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
        "No se encontró un usuario válido para cargar los cumpleaños.",
        NotificationType.error,
      );
      setState(() => _cargando = false);
      return;
    }

    await cumpleaniosService.obtenerCumpleanios(idUsuario: idUsuario);
    setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    final cumpleanios = context.watch<CumpleaniosService>().cumpleanios;
    final pendientes = cumpleanios.where((c) => c.estado == 0).length;

    // Inset físico de la barra de estado / notch (consistente iOS/Android).
    final double topInset = MediaQuery.of(context).viewPadding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          // Fondo azul superior con curva (se extiende bajo la barra de estado)
          ClipPath(
            clipper: CumpleanosWaveClipper(),
            child: Container(
              height: 120 + topInset,
              decoration: const BoxDecoration(
                color: Color(0xFF0052A3),
              ),
            ),
          ),

          Column(
            children: [
                // Header. En modo selección cede el lugar a la barra de
                // acciones sobre lo marcado.
                Padding(
                  padding: EdgeInsets.fromLTRB(16, topInset + 12, 16, 12),
                  child: _modoSeleccion
                      ? Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.white, size: 26),
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
                              icon: const Icon(Icons.select_all,
                                  color: Colors.white, size: 24),
                              tooltip: 'Seleccionar todos',
                              onPressed: () => _seleccionarTodos(cumpleanios),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: _seleccionados.isEmpty
                                    ? Colors.white38
                                    : Colors.white,
                                size: 26,
                              ),
                              tooltip: 'Eliminar seleccionados',
                              onPressed: _seleccionados.isEmpty
                                  ? null
                                  : _eliminarSeleccionados,
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back,
                                  color: Colors.white, size: 28),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'CUMPLEAÑOS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            // Entrada visible al borrado múltiple: el
                            // long-press hace lo mismo, pero no se ve.
                            if (cumpleanios.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.checklist,
                                    color: Colors.white, size: 26),
                                tooltip: 'Seleccionar varios',
                                onPressed: _activarModoSeleccion,
                              ),
                          ],
                        ),
                ),

                Expanded(
                  child: SafeArea(
                    top: false,
                    child: _cargando
                      ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF0052A3),
                    ),
                  )
                      : RefreshIndicator(
                    onRefresh: () async {
                      await context
                          .read<CumpleaniosService>()
                          .obtenerCumpleanios(idUsuario: idUsuario);
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
                                      const Text(
                                        'Cumpleaños',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0052A3),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Revisa Todos los Cumpleaños',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF666666),
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      // ✅ TEXTO PENDIENTES
                                      if (pendientes > 0)
                                        Row(
                                          children: [
                                            Text(
                                              "Pendientes: $pendientes" ,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF0052A3),
                                              ),
                                            ),

                                          ],
                                        )
                                      else
                                        const Text(
                                          "No tienes pendientes",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF666666),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Imagen a la derecha
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.asset(
                                    'assets/icono/cumpleanosdetalle.jpg',
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
                            child: Row(
                              children: [
                                const Text(
                                  'Cumpleaños',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0052A3),
                                  ),
                                ),
                                const SizedBox(width: 8),


                              ],
                            ),
                          ),

                          // Lista de cumpleaños
                          cumpleanios.isEmpty
                              ? Container(
                            padding: const EdgeInsets.all(40),
                            child: const Center(
                              child: Text(
                                'No hay cumpleaños disponibles actualmente.',
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
                              children: cumpleanios.map((cumple) {
                                return _CumpleanosItem(
                                  cumpleanios: cumple,
                                  idUsuario: idUsuario,
                                  modoSeleccion: _modoSeleccion,
                                  seleccionado: _seleccionados
                                      .contains(cumple.idCumpleanios),
                                  onIniciarSeleccion: () =>
                                      _iniciarSeleccion(cumple.idCumpleanios),
                                  onAlternarSeleccion: () =>
                                      _alternarSeleccion(cumple.idCumpleanios),
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

class _CumpleanosItem extends StatelessWidget {
  const _CumpleanosItem({
    required this.cumpleanios,
    required this.idUsuario,
    required this.modoSeleccion,
    required this.seleccionado,
    required this.onIniciarSeleccion,
    required this.onAlternarSeleccion,
  });

  final Cumpleanios cumpleanios;
  final int idUsuario;
  final bool modoSeleccion;
  final bool seleccionado;
  final VoidCallback onIniciarSeleccion;
  final VoidCallback onAlternarSeleccion;

  Future<bool> _confirmarEliminar(BuildContext context) {
    return confirmarEliminacion(
      context,
      titulo: 'Eliminar notificación',
      mensaje:
          '¿Quieres quitar "${cumpleanios.titulo}" de tu lista? No volverá a aparecer en la app.',
    );
  }

  /// Pide confirmación y elimina. Se toman el servicio y el messenger antes de
  /// abrir el diálogo porque la tarjeta desaparece del árbol al eliminarse.
  Future<void> _eliminarConConfirmacion(BuildContext context) async {
    final service = context.read<CumpleaniosService>();
    final messenger = ScaffoldMessenger.of(context);

    if (!await _confirmarEliminar(context)) return;

    await _eliminar(service, messenger);
  }

  Future<void> _eliminar(
    CumpleaniosService service,
    ScaffoldMessengerState messenger,
  ) async {
    final ok = await service.eliminarCumpleanios(
      idUsuario: idUsuario,
      idCumpleanios: cumpleanios.idCumpleanios,
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
    final esPendiente = cumpleanios.estado == 0;

    return Dismissible(
      key: ValueKey('cumpleanios_${cumpleanios.idCumpleanios}'),
      // Con la selección activa el swipe estorba: el gesto lo maneja la lista.
      direction:
          modoSeleccion ? DismissDirection.none : DismissDirection.endToStart,
      background: const FondoEliminar(),
      confirmDismiss: (_) => _confirmarEliminar(context),
      onDismissed: (_) => _eliminar(
        context.read<CumpleaniosService>(),
        ScaffoldMessenger.of(context),
      ),
      child: _buildTarjeta(context, esPendiente),
    );
  }

  Widget _buildTarjeta(BuildContext context, bool esPendiente) {
    return GestureDetector(
      // Mantener pulsado entra al modo selección, como en las apps de correo.
      onLongPress: modoSeleccion ? null : onIniciarSeleccion,
      onTap: () {
        // Con la selección activa, tocar marca/desmarca en vez de abrir.
        if (modoSeleccion) {
          onAlternarSeleccion();
          return;
        }

        // 1) navegar a detalle
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetalleCumpleaniosScreen(cumple: cumpleanios),
          ),
        );

        // 2) si era pendiente: marcar (optimista) y enviar a WS
        if (esPendiente) {
          cumpleanios.estado = 1;

          Future.microtask(() {
            context.read<CumpleaniosService>().marcarCumpleaniosComoVisto(
              idUsuario: idUsuario,
              idCumpleanios: cumpleanios.idCumpleanios,
            );
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: seleccionado
              ? Base().COLOR_AZUL_CORP.withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: seleccionado
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
            // Icono del cumpleaños + indicador pendiente
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0052A3).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.cake,
                    color: Color(0xFF0052A3),
                    size: 32,
                  ),
                ),
                if (esPendiente)
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

            // Información del cumpleaños
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          cumpleanios.titulo,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0052A3),
                          ),
                        ),
                      ),

                    ],
                  ),
                  const SizedBox(height: 6),

                  if (cumpleanios.descripcion.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      cumpleanios.descripcion,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF666666),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFF666666),
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

// ====== UI helpers ======

class _BadgeRed extends StatelessWidget {
  final String text;
  const _BadgeRed({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(14),
      ),
      constraints: const BoxConstraints(minWidth: 22),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class CumpleanosWaveClipper extends CustomClipper<Path> {
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
