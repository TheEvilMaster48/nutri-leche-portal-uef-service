class Beneficio {
  final int id;
  final String nombre;
  final String descripcion;
  final String tipo;
  final String categoria;
  final String imagenUrl;
  final String fechaPublicacion;
  final bool activo;

  Beneficio({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.tipo,
    required this.categoria,
    required this.imagenUrl,
    required this.fechaPublicacion,
    required this.activo,
  });

  factory Beneficio.fromJson(Map<String, dynamic> json) {
    return Beneficio(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'] ?? '',
      tipo: json['tipo'] ?? '',
      categoria: json['categoria'] ?? '',
      imagenUrl: json['imagenUrl'] ?? '',
      fechaPublicacion: json['fechaPublicacion'] ?? '',
      activo: json['activo'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'descripcion': descripcion,
        'tipo': tipo,
        'categoria': categoria,
        'imagenUrl': imagenUrl,
        'fechaPublicacion': fechaPublicacion,
        'activo': activo,
      };
}
