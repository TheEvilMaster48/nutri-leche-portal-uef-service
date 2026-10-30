/// Respuesta de `nfc/get_tipo_reservaActual`: qué tipo de reserva de comedor
/// se puede generar ahora mismo.
///
/// Con horario abierto el WS manda `{ error: false, tipoReserva, horaFin }`.
/// En un hueco entre horarios manda `{ error: true, message, proximoTipo,
/// proximaHora, proximoManana }` (los `proximo*` solo si hay algún horario
/// configurado).
class TipoReservaActual {
  /// `true` si hay un horario abierto y se puede reservar.
  final bool disponible;

  /// Ej. "ALMUERZO". Solo con [disponible].
  final String? tipoReserva;

  /// Hora de cierre del horario actual, "HH:mm". Solo con [disponible].
  final String? horaFin;

  /// Texto del backend cuando no hay horario abierto.
  final String? mensaje;

  final String? proximoTipo;

  /// Hora de apertura del próximo horario, "HH:mm".
  final String? proximaHora;

  /// Si el próximo horario es mañana (hoy ya no queda ninguno).
  final bool proximoManana;

  const TipoReservaActual({
    required this.disponible,
    this.tipoReserva,
    this.horaFin,
    this.mensaje,
    this.proximoTipo,
    this.proximaHora,
    this.proximoManana = false,
  });

  factory TipoReservaActual.fromJson(Map<String, dynamic> json) {
    final error = json['error'] == true || json['error'].toString() == 'true';
    final tipo = _texto(json['tipoReserva']);

    return TipoReservaActual(
      disponible: !error && tipo != null,
      tipoReserva: tipo,
      horaFin: _texto(json['horaFin']),
      mensaje: _texto(json['message']),
      proximoTipo: _texto(json['proximoTipo']),
      proximaHora: _texto(json['proximaHora']),
      proximoManana:
          json['proximoManana'] == true ||
          json['proximoManana'].toString() == 'true',
    );
  }

  static String? _texto(dynamic v) {
    final t = v?.toString().trim() ?? '';
    return t.isEmpty || t == 'null' ? null : t;
  }
}
