import 'dart:convert';

class Sugerencia {
  final String id;
  final String categoria;
  final String titulo;
  final String descripcion;
  final String? imagenPath;   
  final DateTime fecha;

  // Nuevos campos híbridos
  final String? base64;     
  final String? rutaLocal;  

  Sugerencia({
    required this.id,
    required this.categoria,
    required this.titulo,
    required this.descripcion,
    this.imagenPath,
    required this.fecha,
    this.base64,
    this.rutaLocal,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoria': categoria,
        'titulo': titulo,
        'descripcion': descripcion,
        'imagenPath': imagenPath,
        'fecha': fecha.toIso8601String(),
        'base64': base64,
        'rutaLocal': rutaLocal,
      };

  factory Sugerencia.fromJson(Map<String, dynamic> json) => Sugerencia(
        id: json['id'],
        categoria: json['categoria'] ?? 'Sin categoría',
        titulo: json['titulo'] ?? '',
        descripcion: json['descripcion'] ?? '',
        imagenPath: json['imagenPath'],
        fecha: DateTime.parse(json['fecha']),
        base64: json['base64'],
        rutaLocal: json['rutaLocal'],
      );
}
