/// Una reserva del día que todavía no se retira, de
/// `nfc/listar_reservas_pendientes`:
///
///   { error: false, msg, nombre, departamento, total,
///     reservas: [ { id, tipoReserva, centro, estado, estadoTexto,
///                   horaReserva } ] }
///
/// `estado` 5 = pendiente de aprobación por TTHH; cualquier otro que llegue
/// aquí es una reserva aprobada pendiente de retiro.
class ReservaPendiente {
  final int id;
  final String tipoReserva;

  /// Comedor donde se reservó: "CU" o "SA".
  final String centro;
  final int estado;
  final String estadoTexto;

  /// "HH:mm", o vacío si el backend no la tiene.
  final String horaReserva;

  static const int estadoPendienteAprobacion = 5;

  const ReservaPendiente({
    required this.id,
    required this.tipoReserva,
    required this.centro,
    required this.estado,
    required this.estadoTexto,
    required this.horaReserva,
  });

  bool get pendienteAprobacion => estado == estadoPendienteAprobacion;

  factory ReservaPendiente.fromJson(Map<String, dynamic> json) {
    return ReservaPendiente(
      id: _aInt(json['id']),
      tipoReserva: json['tipoReserva']?.toString() ?? '',
      centro: json['centro']?.toString() ?? '',
      estado: _aInt(json['estado']),
      estadoTexto: json['estadoTexto']?.toString() ?? '',
      horaReserva: json['horaReserva']?.toString() ?? '',
    );
  }

  /// La lista de la respuesta completa; vacía si no viene o no es lista.
  static List<ReservaPendiente> listaDesde(Map<String, dynamic> json) {
    final lista = json['reservas'];
    if (lista is! List) return const [];
    return lista
        .whereType<Map<String, dynamic>>()
        .map(ReservaPendiente.fromJson)
        .toList();
  }
}

int _aInt(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
