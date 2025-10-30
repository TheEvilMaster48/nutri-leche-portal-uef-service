
class Notificacion {
  final int id;
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

  factory Notificacion.fromJson(Map<String, dynamic> json) {
    return Notificacion(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      titulo: json['titulo'] ?? '',
      descripcion: json['descripcion'] ?? '',
      tipo: json['tipo'] ?? '',
      fecha: json['fecha'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'titulo': titulo,
      'descripcion': descripcion,
      'tipo': tipo,
      'fecha': fecha,
    };
  }
}
