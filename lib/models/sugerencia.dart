class Sugerencia {
  final String categoria;
  final String titulo;
  final String descripcion;
  final String? imagenBase64;
  final DateTime fecha;


  Sugerencia({
    required this.categoria,
    required this.titulo,
    required this.descripcion,
    this.imagenBase64,
    required this.fecha,
  });

  Map<String, dynamic> toJson() => {
        'categoria': categoria,
        'titulo': titulo,
        'descripcion': descripcion,
        'imagenBase64': imagenBase64,
        'fecha': fecha.toIso8601String(),
      };

  factory Sugerencia.fromJson(Map<String, dynamic> json) => Sugerencia(
        categoria: json['categoria'] ?? 'Sin categoría',
        titulo: json['titulo'] ?? '',
        descripcion: json['descripcion'] ?? '',
        imagenBase64: json['imagenBase64'],
        fecha: DateTime.parse(json['fecha']),
      );
}
