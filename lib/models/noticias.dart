class Noticia {
  final String id;
  final String titulo;
  final String descripcion;
  final String archivo;

  Noticia({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.archivo,
  });

  factory Noticia.fromJson(Map<String, dynamic> json) {
    return Noticia(
      id: json['id']?.toString() ?? '',
      titulo: json['titulo'] ?? '',
      descripcion: json['descripcion'] ?? '',
      archivo: json['archivo'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'titulo': titulo,
      'descripcion': descripcion,
      'archivo': archivo,
    };
  }
}
