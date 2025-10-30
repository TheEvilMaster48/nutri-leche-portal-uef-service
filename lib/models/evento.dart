class Evento {
  final String id;
  final String planta;
  final String titulo;
  final String descripcion;
  final String fecha;
  final String creadoPor;
  final String horaEvento;
  final String? imagenPath;
  final String? archivoPath;

  Evento({
    required this.id,
    required this.planta,
    required this.titulo,
    required this.descripcion,
    required this.fecha,
    required this.creadoPor,
    required this.horaEvento,
    this.imagenPath,
    this.archivoPath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'planta': planta,
        'titulo': titulo,
        'descripcion': descripcion,
        'fecha': fecha,
        'creadoPor': creadoPor,
        'horaEvento': horaEvento,
        'imagenPath': imagenPath,
        'archivoPath': archivoPath,
      };

  factory Evento.fromJson(Map<String, dynamic> json) => Evento(
        id: json['id'],
        planta: json['planta'],
        titulo: json['titulo'],
        descripcion: json['descripcion'],
        fecha: json['fecha'],
        creadoPor: json['creadoPor'],
        horaEvento: json['horaEvento'],
        imagenPath: json['imagenPath'],
        archivoPath: json['archivoPath'],
      );
}
