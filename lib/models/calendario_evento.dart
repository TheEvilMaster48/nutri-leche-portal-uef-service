class CalendarioEvento {
  final int id;
  final String titulo;
  final String descripcion;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String lugar;
  final String organizador;
  final bool asistenciaConfirmada;

  CalendarioEvento({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.fechaInicio,
    required this.fechaFin,
    required this.lugar,
    required this.organizador,
    required this.asistenciaConfirmada,
  });

  factory CalendarioEvento.fromJson(Map<String, dynamic> json) {
    return CalendarioEvento(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      titulo: json['titulo'] ?? '',
      descripcion: json['descripcion'] ?? '',
      fechaInicio: DateTime.tryParse(json['fechaInicio'] ?? '') ?? DateTime.now(),
      fechaFin: DateTime.tryParse(json['fechaFin'] ?? '') ?? DateTime.now(),
      lugar: json['lugar'] ?? '',
      organizador: json['organizador'] ?? '',
      asistenciaConfirmada: json['asistenciaConfirmada'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'descripcion': descripcion,
        'fechaInicio': fechaInicio.toIso8601String(),
        'fechaFin': fechaFin.toIso8601String(),
        'lugar': lugar,
        'organizador': organizador,
        'asistenciaConfirmada': asistenciaConfirmada,
      };
}
