class Recurso {
  final int id;
  final String titulo;
  final String? descripcion;
  final String? contenido;
  final String? categoria;
  final String? fechaPublicacion;

  Recurso({
    required this.id,
    required this.titulo,
    this.descripcion,
    this.contenido,
    this.categoria,
    this.fechaPublicacion,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'titulo': titulo,
      'descripcion': descripcion,
      'contenido': contenido,
      'categoria': categoria,
      'fechaPublicacion': fechaPublicacion,
    };
  }

  factory Recurso.fromJson(Map<String, dynamic> json) {
    return Recurso(
      id: json['id'] ?? 0,
      titulo: json['titulo'] ?? '',
      descripcion: json['descripcion'],
      contenido: json['contenido'],
      categoria: json['categoria'],
      fechaPublicacion: json['fechaPublicacion'],
    );
  }
}
