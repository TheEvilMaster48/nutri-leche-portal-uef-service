class CalendarioEvento {
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
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
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
