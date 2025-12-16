class Sorteo {
  final int id;
  final String titulo;
  final String descripcion;
  final String fecha;
  final String hora;
  final String tipoevento;
  final String centro;
  final String? imagenBase64;

  int estado;

  Sorteo({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.fecha,
    required this.hora,
    required this.tipoevento,
    required this.centro,
    this.imagenBase64,
    this.estado = 0,
  });


  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'descripcion': descripcion,
        'fecha': fecha,
        'hora': hora,
        'tipoevento': tipoevento,
        'centro': centro,
        'imagenBase64': imagenBase64,
        'estado': estado,
      };

  factory Sorteo.fromJson(Map<String, dynamic> json) => Sorteo(
        id: json['id'] ?? 0,
        titulo: json['titulo'] ?? '',
        descripcion: json['descripcion'] ?? '',
        fecha: json['fecha'] ?? '',
        hora: json['hora'] ?? '',
        tipoevento: json['tipoevento'] ?? '',
        centro: json['centro'] ?? '',
        imagenBase64: json['imagenBase64'],
        estado: json['estado'] != null
            ? int.tryParse(json['estado'].toString()) ?? 0
            : 0,
      );
}
