import 'package:flutter/material.dart';
import 'package:nutri/base/base.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/nutrisoft.dart';
import '../services/nutrisoft_service.dart';
import '../core/notification_banner.dart';
import '../services/auth_service.dart';
import '../widget/eliminar_notificacion.dart';
import 'detalle_nutrisoft_screen.dart';

class NutrisoftPage extends StatefulWidget {
  const NutrisoftPage({super.key});

  @override
  State<NutrisoftPage> createState() => _NutrisoftPageState();
}

class _NutrisoftPageState extends State<NutrisoftPage> {
  bool _cargando = true;
  int idUsuario = 0;

  /// Selección múltiple: se activa manteniendo pulsada una tarjeta.
  bool _modoSeleccion = false;
  final Set<int> _seleccionados = <int>{};

  void _alternarSeleccion(int idMensaje) {
    setState(() {
      if (!_seleccionados.remove(idMensaje)) _seleccionados.add(idMensaje);
      if (_seleccionados.isEmpty) _modoSeleccion = false;
    });
  }

  void _iniciarSeleccion(int idMensaje) {
    setState(() {
      _modoSeleccion = true;
      _seleccionados.add(idMensaje);
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

  void _seleccionarTodos(List<Nutrisoft> lista) {
    setState(() {
      if (_seleccionados.length == lista.length) {
        _seleccionados.clear();
        _modoSeleccion = false;
      } else {
        _seleccionados
          ..clear()
          ..addAll(lista.map((n) => n.idMensaje));
      }
    });
  }

  /// Elimina todo lo seleccionado con una sola confirmación. Reusa
  /// `eliminarNutrisoft` uno por uno: el backend no tiene borrado en lote.
  Future<void> _eliminarSeleccionados() async {
    final service = context.read<NutrisoftService>();
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
      final ok = await service.eliminarNutrisoft(
        idUsuario: idUsuario,
        idMensaje: id,
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
    _cargar();
  }

  Future<void> _cargar() async {
    final service = context.read<NutrisoftService>();

    try {
      final authService = context.read<AuthService>();
      idUsuario = authService.currentUser?.id ?? 0;

      if (idUsuario == 0) {
        // La sesión persistida vive en 'currentUser' como JSON.
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('currentUser');
        if (raw != null && raw.isNotEmpty) {
          final decoded = json.decode(raw);
          if (decoded is Map) {
            final valor = decoded['id'] ?? decoded['idUsuario'];
            idUsuario = valor is int ? valor : int.tryParse('$valor') ?? 0;
          }
        }
      }
    } catch (e) {
      debugPrint("No se pudo obtener el idUsuario: $e");
    }

    if (idUsuario == 0) {
      if (!mounted) return;
      NotificationBanner.show(
        context,
        "No se encontró un usuario válido para cargar Nutrisoft.",
        NotificationType.error,
      );
      setState(() => _cargando = false);
      return;
    }

    await service.obtenerNutrisoft(idUsuario: idUsuario);
    if (!mounted) return;
    setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    final items = context.watch<NutrisoftService>().items;

    // Inset físico de la barra de estado / notch.
    final double topInset = MediaQuery.of(context).viewPadding.top;

    return Scaffold(
      backgroundColor: Base().COLOR_BLANCO,
      body: Stack(
        children: [
          ClipPath(
            clipper: NutrisoftWaveClipper(),
            child: Container(
              height: 120 + topInset,
              decoration: BoxDecoration(color: Base().COLOR_AZUL_CORP),
            ),
          ),

          Column(
            children: [
              // En modo selección el encabezado cede el lugar a la barra de
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
                            onPressed: () => _seleccionarTodos(items),
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
                              'NUTRISOFT',
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
                          if (items.isNotEmpty)
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
                      ? Center(
                          child: CircularProgressIndicator(
                            color: Base().COLOR_AZUL_CORP,
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            await context
                                .read<NutrisoftService>()
                                .obtenerNutrisoft(idUsuario: idUsuario);
                          },
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                              children: [
                                // Encabezado del módulo
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
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Nutrisoft',
                                              style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: Base().COLOR_AZUL_CORP,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Comunicados del sistema',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Base().COLOR_AZUL_CORP,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        child: Image.asset(
                                          'assets/icono/nutri.png',
                                          height: 120,
                                          width: 120,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                Container(
                                  margin:
                                      const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Notificaciones',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Base().COLOR_AZUL_CORP,
                                    ),
                                  ),
                                ),

                                items.isEmpty
                                    ? Container(
                                        padding: const EdgeInsets.all(40),
                                        child: Center(
                                          child: Text(
                                            'No hay notificaciones de Nutrisoft actualmente.',
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
                                            horizontal: 16),
                                        child: Column(
                                          children: items.map((item) {
                                            return _NutrisoftItem(
                                              item: item,
                                              idUsuario: idUsuario,
                                              modoSeleccion: _modoSeleccion,
                                              seleccionado: _seleccionados
                                                  .contains(item.idMensaje),
                                              onIniciarSeleccion: () =>
                                                  _iniciarSeleccion(
                                                      item.idMensaje),
                                              onAlternarSeleccion: () =>
                                                  _alternarSeleccion(
                                                      item.idMensaje),
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

class _NutrisoftItem extends StatelessWidget {
  const _NutrisoftItem({
    required this.item,
    required this.idUsuario,
    required this.modoSeleccion,
    required this.seleccionado,
    required this.onIniciarSeleccion,
    required this.onAlternarSeleccion,
  });

  final Nutrisoft item;
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
          '¿Quieres quitar "${item.titulo}" de tu lista? No volverá a aparecer en la app.',
    );
  }

  /// Pide confirmación y elimina. Se toman el servicio y el messenger antes de
  /// abrir el diálogo porque la tarjeta desaparece del árbol al eliminarse.
  Future<void> _eliminarConConfirmacion(BuildContext context) async {
    final service = context.read<NutrisoftService>();
    final messenger = ScaffoldMessenger.of(context);

    if (!await _confirmarEliminar(context)) return;

    await _eliminar(service, messenger);
  }

  Future<void> _eliminar(
    NutrisoftService service,
    ScaffoldMessengerState messenger,
  ) async {
    final ok = await service.eliminarNutrisoft(
      idUsuario: idUsuario,
      idMensaje: item.idMensaje,
    );

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Notificación eliminada'
              : 'No se pudo eliminar la notificación. Intenta de nuevo.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isPendiente = item.pendiente;

    return Dismissible(
      key: ValueKey('nutrisoft_${item.idMensaje}'),
      // Con la selección activa el swipe estorba: el gesto lo maneja la lista.
      direction:
          modoSeleccion ? DismissDirection.none : DismissDirection.endToStart,
      background: const FondoEliminar(),
      confirmDismiss: (_) => _confirmarEliminar(context),
      onDismissed: (_) => _eliminar(
        context.read<NutrisoftService>(),
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

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetalleNutrisoftScreen(item: item),
          ),
        );

        if (!context.mounted) return;

        // Si estaba pendiente, se marca como visto y se refresca la lista.
        if (isPendiente) {
          try {
            final service = context.read<NutrisoftService>();
            await service.marcarComoVisto(
              idUsuario: idUsuario,
              idMensaje: item.idMensaje,
            );
            await service.obtenerNutrisoft(idUsuario: idUsuario);
          } catch (e) {
            debugPrint("Error marcando Nutrisoft como visto: $e");
          }
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
            // Icono + badge pendiente
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
                    Icons.campaign_outlined,
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

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.titulo,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Base().COLOR_AZUL_CORP,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Sin fecha ni hora: se adelanta la descripción.
                  if (item.descripcion.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.descripcion,
                      style: TextStyle(
                        fontSize: 13,
                        color: Base().COLOR_GRIS,
                      ),
                      maxLines: 2,
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

class NutrisoftWaveClipper extends CustomClipper<Path> {
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
