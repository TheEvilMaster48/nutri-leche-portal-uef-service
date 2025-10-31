class Notificacion {
  final String id;
  final String titulo;
  final String descripcion;
  final String tipo;
  final String fecha;

  Notificacion({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.tipo,
    required this.fecha,
  });

  factory Notificacion.fromJson(Map<String, dynamic> json, String id) {
    return Notificacion(
      id: id,
      titulo: json['titulo'] ?? '',
      descripcion: json['descripcion'] ?? '',
      tipo: json['tipo'] ?? '',
      fecha: json['fecha'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'titulo': titulo,
      'descripcion': descripcion,
      'tipo': tipo,
      'fecha': fecha,
    };
  }
}
