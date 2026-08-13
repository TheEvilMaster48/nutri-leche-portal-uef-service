class Sorteo {
  final int id;

  /// Id de la cabecera de notificación, si el WS lo manda (ver [Evento]).
  final int idCabecera;
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
    this.idCabecera = 0,
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
        idCabecera: _aIntSorteo(json['idCabecera'] ?? json['id_cabecera']),
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

int _aIntSorteo(dynamic v) =>
    v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
