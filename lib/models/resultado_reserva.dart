/// Respuesta de `nfc/registrar_reservacu` y `nfc/registrar_reservasa`.
///
///   { error: false, msg: "Reserva de ALMUERZO realizada correctamente",
///     nombre, img, aviso? }
///   { error: false, pendiente: true, msg: "… pendiente de aprobacion por TTHH" }
///   { error: true,  msg: "Reservado anteriormente a las …" | "Fuera de horario"
///                        | "Tarjeta bloqueada." | "Codigo QR no valido" … }
///
/// Ojo: `pendiente` puede venir con `error: false` (se grabó, pero TTHH tiene
/// que aprobarla) o con `error: true` (ya existía una pendiente).
class ResultadoReserva {
  final bool error;
  final bool pendiente;
  final String mensaje;
  final String nombre;

  const ResultadoReserva({
    required this.error,
    required this.mensaje,
    this.pendiente = false,
    this.nombre = '',
  });

  factory ResultadoReserva.fromJson(Map<String, dynamic> json) {
    final msg = json['msg']?.toString().trim() ?? '';
    return ResultadoReserva(
      error: json['error'] == true || json['error'].toString() == 'true',
      pendiente:
          json['pendiente'] == true || json['pendiente'].toString() == 'true',
      mensaje: msg.isEmpty ? 'Respuesta sin mensaje del servidor.' : msg,
      nombre: json['nombre']?.toString() ?? '',
    );
  }
}
