import 'dart:async';

import 'package:flutter/material.dart';

/// Estado de un evento respecto de su tiempo estimado.
enum EstadoContador {
  /// Queda bastante tiempo.
  enTiempo,

  /// Queda poco: entra dentro de [ContadorEvento.umbralPorVencer].
  porVencer,

  /// Ya se pasó del tiempo estimado.
  vencido,
}

/// Cuenta atrás del tiempo estimado de un evento abierto.
///
/// La lógica vive en [Cronometro] y es pura, para poder probarla sin montar
/// widgets ni esperar en tiempo real.
///
/// El aviso al vencer **no** lo da este widget: lo programa
/// `RecordatorioEventoService` como notificación del sistema, porque el chofer
/// deja el teléfono guardado y un contador en pantalla no le sirve de nada
/// cuando la app no está delante.
class ContadorEvento extends StatefulWidget {
  const ContadorEvento({
    super.key,
    required this.inicio,
    required this.minutosEstimados,
    this.nombreEvento,
  });

  /// Cuándo se abrió el evento.
  final DateTime inicio;

  /// El `tiempoestimado` del catálogo, en minutos.
  final int minutosEstimados;

  /// Se muestra arriba del contador si viene.
  final String? nombreEvento;

  /// A partir de cuánto restante se avisa que está por vencer.
  static const Duration umbralPorVencer = Duration(minutes: 5);

  @override
  State<ContadorEvento> createState() => _ContadorEventoState();
}

class _ContadorEventoState extends State<ContadorEvento> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Un tick por segundo. No hay animaciones ni trabajo pesado detrás, y el
    // timer se cancela al salir de la pantalla.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cronometro = Cronometro(
      inicio: widget.inicio,
      minutosEstimados: widget.minutosEstimados,
    );

    final (fondo, borde, tinta, icono) = switch (cronometro.estado) {
      EstadoContador.enTiempo => (
          const Color(0xFFEFF4E4),
          const Color(0xFFCBDDA6),
          const Color(0xFF4A6D08),
          Icons.schedule,
        ),
      EstadoContador.porVencer => (
          const Color(0xFFFDF6E3),
          const Color(0xFFE8D9A8),
          const Color(0xFF8A6300),
          Icons.timelapse,
        ),
      EstadoContador.vencido => (
          const Color(0xFFFBF0EA),
          const Color(0xFFE8C3AF),
          const Color(0xFFA8460F),
          Icons.warning_amber_rounded,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borde),
      ),
      child: Row(
        children: [
          Icon(icono, size: 20, color: tinta),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.nombreEvento != null)
                  Text(
                    widget.nombreEvento!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tinta,
                    ),
                  ),
                Text(
                  cronometro.etiqueta,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: tinta,
                    // Los dígitos no deben bailar cada segundo.
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  cronometro.detalle,
                  style: TextStyle(fontSize: 11.5, color: tinta.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// El cálculo del contador, sin widgets.
///
/// Separado a propósito: es donde están las decisiones (qué texto, qué estado,
/// qué pasa si el tiempo estimado es 0) y así se prueba directo.
class Cronometro {
  Cronometro({
    required this.inicio,
    required this.minutosEstimados,
    DateTime? ahora,
  }) : ahora = ahora ?? DateTime.now();

  final DateTime inicio;
  final int minutosEstimados;
  final DateTime ahora;

  /// Cuándo debería haber terminado el evento.
  DateTime get vencimiento => inicio.add(Duration(minutes: minutosEstimados));

  Duration get transcurrido {
    final d = ahora.difference(inicio);
    // Un reloj del sistema movido hacia atrás daría negativo y textos absurdos.
    return d.isNegative ? Duration.zero : d;
  }

  /// Lo que falta. Negativo si ya se pasó.
  Duration get restante => vencimiento.difference(ahora);

  /// Si el evento no tiene tiempo estimado no hay nada que vencer.
  ///
  /// Pasa de verdad: el WS admite `tiempoestimado: 0` y el catálogo podría
  /// traerlo. En ese caso el contador solo cuenta hacia arriba.
  bool get sinLimite => minutosEstimados <= 0;

  EstadoContador get estado {
    if (sinLimite) return EstadoContador.enTiempo;
    if (restante.isNegative) return EstadoContador.vencido;
    if (restante <= ContadorEvento.umbralPorVencer) {
      return EstadoContador.porVencer;
    }
    return EstadoContador.enTiempo;
  }

  /// La línea principal.
  String get etiqueta {
    if (sinLimite) return 'Abierto hace ${_texto(transcurrido)}';
    if (restante.isNegative) {
      return 'Pasado por ${_texto(restante.abs())}';
    }
    return 'Quedan ${_texto(restante)}';
  }

  /// La línea de apoyo, que da el contexto que la principal omite.
  String get detalle {
    if (sinLimite) return 'Este evento no tiene tiempo estimado.';
    return 'Estimado $minutosEstimados min · abierto hace '
        '${_texto(transcurrido)}';
  }

  /// Duración en palabras cortas: `45 s`, `12 min`, `2 h 05 min`.
  ///
  /// Debajo del minuto se muestran segundos porque en el último tramo el chofer
  /// está mirando: un «0 min» quieto parecería que el contador se congeló.
  static String _texto(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds} s';
    if (d.inMinutes < 60) return '${d.inMinutes} min';

    final horas = d.inHours;
    final minutos = d.inMinutes % 60;
    return '$horas h ${minutos.toString().padLeft(2, '0')} min';
  }
}
