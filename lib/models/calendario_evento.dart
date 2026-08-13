int _aInt(dynamic v) =>
    v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

class CalendarioEvento {
  /// Id del evento corporativo (`idEvento`). Es el mismo que usa `Evento`, así
  /// que las reacciones hechas desde el calendario y desde la lista de eventos
  /// caen sobre el mismo registro.
  final int id;
  final String titulo;
  final String descripcion;
  final String fecha; 
  final String hora; 
  final String? tipoEvento;
  final String? centro;
  final String? imagenBase64;

  CalendarioEvento({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.fecha,
    required this.hora,
    this.tipoEvento,
    this.centro,
    this.imagenBase64,
  });

  factory CalendarioEvento.fromJson(Map<String, dynamic> json) {
    return CalendarioEvento(
      // `ObtenerEventos` (el mismo WS que alimenta EventoService) manda el id
      // en `idEvento`; leer solo `id` dejaba todo el calendario en 0 y sin
      // forma de asociarle reacciones. Se aceptan ambos nombres.
      id: _aInt(json['idEvento'] ?? json['id']),
      titulo: json['titulo']?.toString() ?? '',
      descripcion: json['descripcion']?.toString() ?? '',
      fecha: json['fecha']?.toString() ?? '',
      hora: json['hora']?.toString() ?? '',
      tipoEvento: json['tipoevento']?.toString(),
      centro: json['centro']?.toString(),
      imagenBase64: json['imagenBase64']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'descripcion': descripcion,
        'fecha': fecha,
        'hora': hora,
        'tipoevento': tipoEvento,
        'centro': centro,
        'imagenBase64': imagenBase64,
      };
}
