import 'package:flutter/material.dart';
import 'package:nutri/base/base.dart';
import 'package:provider/provider.dart';

import '../models/reserva_pendiente.dart';
import '../models/resultado_reserva.dart';
import '../models/sede_comedor.dart';
import '../models/tipo_reserva_actual.dart';
import '../services/auth_service.dart';
import '../services/qr_store.dart';
import '../services/reserva_service.dart';
import '../services/ubicacion_service.dart';
import '../widget/qr_cedula.dart';

/// Reservas de comedor / alimentación.
///
/// Al entrar se consulta `get_tipo_reservaActual` para saber qué tipo de
/// reserva (desayuno, almuerzo…) se puede generar en este momento, y se avisa
/// con un mensaje. A la vez se listan las reservas del día que el empleado aún
/// no retira (`listar_reservas_pendientes`).
///
/// Al final va el QR del empleado para el lector del comedor. Queda fuera de
/// la carga: se dibuja desde el primer momento y también sin internet (lo
/// recupera de [QrStore]).
///
/// Para reservar hay que estar a [SedeComedor.radioMetros] o menos de un
/// comedor: la posición del teléfono decide si se envía a
/// `registrar_reservacu` o a `registrar_reservasa`.
class ReservasComedorScreen extends StatefulWidget {
  const ReservasComedorScreen({super.key});

  @override
  State<ReservasComedorScreen> createState() => _ReservasComedorScreenState();
}

class _ReservasComedorScreenState extends State<ReservasComedorScreen> {
  final ReservaService _service = ReservaService();
  bool _cargando = true;

  /// `null` cuando no hubo respuesta del servidor.
  TipoReservaActual? _tipoActual;

  /// Reservas del día sin retirar. `null` si no se pudieron consultar.
  List<ReservaPendiente>? _pendientes;

  bool _enviando = false;

  /// Lo que respondió el servidor al último intento de reserva.
  ResultadoReserva? _resultado;

  /// Por qué no se pudo ni siquiera enviar (GPS, distancia, red, cédula).
  String? _errorEnvio;

  /// Si el error de envío se arregla desde los ajustes del teléfono.
  FalloUbicacion? _falloUbicacion;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _resultado = null;
      _errorEnvio = null;
      _falloUbicacion = null;
    });
    final cedula = await _cedula();
    final respuestas = await Future.wait([
      _service.obtenerTipoReservaActual(),
      cedula.isEmpty
          ? Future<List<ReservaPendiente>?>.value(null)
          : _service.listarPendientes(cedula),
    ]);
    if (!mounted) return;
    setState(() {
      _tipoActual = respuestas[0] as TipoReservaActual?;
      _pendientes = respuestas[1] as List<ReservaPendiente>?;
      _cargando = false;
    });
  }

  /// Vuelve a listar las pendientes sin tapar la pantalla con el indicador.
  Future<void> _recargarPendientes() async {
    final cedula = await _cedula();
    if (cedula.isEmpty) return;
    final pendientes = await _service.listarPendientes(cedula);
    if (!mounted) return;
    setState(() => _pendientes = pendientes);
  }

  /// Cédula del usuario en sesión; si viene vacía, la guardada para el QR.
  Future<String> _cedula() async {
    final usuario = context.read<AuthService>().currentUser;
    final enMemoria = (usuario?.cedula ?? '').trim();
    if (enMemoria.isNotEmpty || usuario == null) return enMemoria;
    return (await QrStore.leer(usuario.id))?.cedula ?? '';
  }

  Future<void> _generarReserva() async {
    setState(() {
      _enviando = true;
      _resultado = null;
      _errorEnvio = null;
      _falloUbicacion = null;
    });

    void fallar(String mensaje, {FalloUbicacion? fallo}) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _errorEnvio = mensaje;
        _falloUbicacion = fallo;
      });
    }

    final cedula = await _cedula();
    if (cedula.isEmpty) {
      return fallar('Tu usuario no tiene cédula registrada.');
    }

    if (!mounted) return;

    // Explicación propia del módulo antes del diálogo del sistema.
    final continuar = await UbicacionService.explicarSiHaceFalta(
      context,
      ModuloUbicacion.alimentacion,
    );
    if (!continuar) {
      return fallar(
        'Necesitamos tu ubicación para '
        '${ModuloUbicacion.alimentacion.proposito}.',
        fallo: FalloUbicacion.permisoNegado,
      );
    }

    final ubicacion = await UbicacionService.obtener(
      modulo: ModuloUbicacion.alimentacion,
    );
    final posicion = ubicacion.posicion;
    if (posicion == null) {
      return fallar(
        ubicacion.mensaje ?? 'No se pudo obtener tu ubicación.',
        fallo: ubicacion.fallo,
      );
    }

    final sede = SedeComedor.dentroDelRadio(
      posicion.latitude,
      posicion.longitude,
    );
    if (sede == null) {
      final cercana = SedeComedor.masCercana(
        posicion.latitude,
        posicion.longitude,
      );
      var mensaje =
          'Debes estar a ${SedeComedor.radioMetros.toStringAsFixed(0)} m '
          'o menos del comedor para reservar. Estás a '
          '${_formatoDistancia(cercana.metros)} del comedor '
          '${cercana.sede.codigo}.';
      // Con mala precisión el GPS puede dejar fuera a alguien que sí está ahí.
      if (posicion.accuracy > SedeComedor.radioMetros) {
        mensaje +=
            ' La precisión del GPS es baja '
            '(±${posicion.accuracy.toStringAsFixed(0)} m); acércate a una '
            'ventana o sal a un lugar despejado.';
      }
      return fallar(mensaje);
    }

    debugPrint(
      'RESERVA: sede ${sede.codigo} a '
      '${sede.distanciaDesde(posicion.latitude, posicion.longitude).toStringAsFixed(0)} m',
    );

    final resultado = await _service.registrarReserva(
      sede: sede,
      cedula: cedula,
    );
    if (resultado == null) {
      return fallar(
        'No se pudo registrar la reserva. Revisa tu conexión e inténtalo '
        'de nuevo.',
      );
    }

    if (!mounted) return;
    setState(() {
      _enviando = false;
      _resultado = resultado;
    });

    // La reserva nueva (o la pendiente de TTHH) aparece en la lista.
    await _recargarPendientes();
  }

  static String _formatoDistancia(double metros) =>
      metros >= 1000
          ? '${(metros / 1000).toStringAsFixed(1)} km'
          : '${metros.toStringAsFixed(0)} m';

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthService>().currentUser;
    final double topInset = MediaQuery.of(context).viewPadding.top;

    return Scaffold(
      backgroundColor: Base().COLOR_BLANCO,
      body: Stack(
        children: [
          ClipPath(
            clipper: ReservasWaveClipper(),
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
                        'RESERVAS DE COMEDOR',
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
                  // Arrastrar hacia abajo vuelve a consultar el horario.
                  child: RefreshIndicator(
                    onRefresh: _cargar,
                    color: Base().COLOR_AZUL_CORP,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        const SizedBox(height: 25),
                        if (_cargando)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else ...[
                          _buildEstado(),
                          if (_tipoActual?.disponible ?? false) ...[
                            const SizedBox(height: 20),
                            _buildBotonReservar(),
                          ],
                          if (_errorEnvio != null) ...[
                            const SizedBox(height: 20),
                            _buildErrorEnvio(),
                          ],
                          if (_resultado != null) ...[
                            const SizedBox(height: 20),
                            _buildResultado(_resultado!),
                          ],
                          const SizedBox(height: 28),
                          _buildPendientes(),
                        ],
                        const SizedBox(height: 28),
                        QrCedula(
                          idUsuario: usuario?.id ?? 0,
                          cedula: usuario?.cedula,
                        ),
                      ],
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

  Widget _buildEstado() {
    final tipo = _tipoActual;

    if (tipo == null) {
      return _buildMensaje(
        icono: Icons.wifi_off,
        color: Base().COLOR_GRIS,
        titulo: 'No se pudo consultar',
        detalle: 'Revisa tu conexión y desliza hacia abajo para reintentar.',
      );
    }

    if (tipo.disponible) {
      return _buildMensaje(
        icono: Icons.restaurant_menu,
        color: const Color(0xFF2E7D32),
        titulo: 'Reserva disponible: ${tipo.tipoReserva}',
        detalle:
            tipo.horaFin != null
                ? 'Puedes generar tu reserva hasta las ${tipo.horaFin}.'
                : 'Puedes generar tu reserva ahora.',
      );
    }

    String detalle = '';
    if (tipo.proximoTipo != null && tipo.proximaHora != null) {
      final cuando = tipo.proximoManana ? 'mañana' : 'hoy';
      detalle =
          'Próximo horario: ${tipo.proximoTipo}, $cuando desde las '
          '${tipo.proximaHora}.';
    }

    return _buildMensaje(
      icono: Icons.schedule,
      color: const Color(0xFFE65100),
      titulo: tipo.mensaje ?? 'No hay reservas disponibles en este momento.',
      detalle: detalle,
    );
  }

  Widget _buildBotonReservar() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _enviando ? null : _generarReserva,
        icon:
            _enviando
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                : const Icon(Icons.how_to_reg, size: 22),
        label: Text(
          _enviando ? 'Verificando ubicación…' : 'Generar reserva',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Base().COLOR_AZUL_CORP,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Base().COLOR_AZUL_CORP.withOpacity(0.6),
          disabledForegroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildErrorEnvio() {
    final fallo = _falloUbicacion;
    final irAAjustes =
        fallo == FalloUbicacion.servicioApagado ||
        fallo == FalloUbicacion.permisoNegadoParaSiempre;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMensaje(
          icono: Icons.location_off,
          color: const Color(0xFFC62828),
          titulo: 'No se generó la reserva',
          detalle: _errorEnvio!,
        ),
        if (irAAjustes)
          TextButton.icon(
            onPressed: () => UbicacionService.abrirAjustes(fallo!),
            icon: const Icon(Icons.settings),
            label: const Text('Abrir ajustes'),
          ),
      ],
    );
  }

  Widget _buildResultado(ResultadoReserva r) {
    if (r.pendiente) {
      return _buildMensaje(
        icono: Icons.hourglass_top,
        color: const Color(0xFFE65100),
        titulo: 'Pendiente de aprobación',
        detalle: r.mensaje,
      );
    }
    if (r.error) {
      return _buildMensaje(
        icono: Icons.error_outline,
        color: const Color(0xFFC62828),
        titulo: 'No se generó la reserva',
        detalle: r.mensaje,
      );
    }
    return _buildMensaje(
      icono: Icons.check_circle_outline,
      color: const Color(0xFF2E7D32),
      titulo: 'Reserva registrada',
      detalle: r.mensaje,
    );
  }

  Widget _buildPendientes() {
    final pendientes = _pendientes;

    Widget contenido;
    if (pendientes == null) {
      contenido = _textoSecundario(
        'No se pudieron consultar tus reservas. Desliza hacia abajo para '
        'reintentar.',
      );
    } else if (pendientes.isEmpty) {
      contenido = _textoSecundario('No tienes reservas pendientes hoy.');
    } else {
      contenido = Column(
        children: [
          for (final r in pendientes) ...[
            _buildPendiente(r),
            const SizedBox(height: 10),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mis reservas de hoy',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Base().COLOR_AZUL_CORP,
          ),
        ),
        const SizedBox(height: 12),
        contenido,
      ],
    );
  }

  Widget _buildPendiente(ReservaPendiente r) {
    final color =
        r.pendienteAprobacion
            ? const Color(0xFFE65100)
            : Base().COLOR_AZUL_CORP;
    final detalle = [
      if (r.centro.isNotEmpty) 'Comedor ${r.centro}',
      if (r.horaReserva.isNotEmpty) 'Reservada a las ${r.horaReserva}',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E9EF)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              r.pendienteAprobacion ? Icons.hourglass_top : Icons.restaurant,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.tipoReserva.isNotEmpty ? r.tipoReserva : 'Reserva',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (detalle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detalle,
                    style: TextStyle(fontSize: 13, color: Base().COLOR_GRIS),
                  ),
                ],
                if (r.estadoTexto.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    r.estadoTexto,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _textoSecundario(String texto) {
    return Text(
      texto,
      style: TextStyle(fontSize: 14, color: Base().COLOR_GRIS, height: 1.4),
    );
  }

  Widget _buildMensaje({
    required IconData icono,
    required Color color,
    required String titulo,
    required String detalle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icono, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1.3,
                  ),
                ),
                if (detalle.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    detalle,
                    style: TextStyle(
                      fontSize: 15,
                      color: Base().COLOR_GRIS,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReservasWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 30);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height - 40,
      size.width * 0.5,
      size.height - 30,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height - 20,
      size.width,
      size.height - 30,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
