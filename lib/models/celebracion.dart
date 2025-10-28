class Celebracion {
  final int id;
  final String nombreEmpleado;
  final String tipo; // Cumpleaños o Aniversario
  final DateTime fecha;
  final String imagen;

  Celebracion({
    required this.id,
    required this.nombreEmpleado,
    required this.tipo,
    required this.fecha,
    required this.imagen,
  });

  factory Celebracion.fromJson(Map<String, dynamic> json) {
    return Celebracion(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      nombreEmpleado: json['nombreEmpleado'] ?? '',
      tipo: json['tipo'] ?? '',
      fecha: DateTime.tryParse(json['fecha'] ?? '') ?? DateTime.now(),
      imagen: json['imagen'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombreEmpleado': nombreEmpleado,
        'tipo': tipo,
        'fecha': fecha.toIso8601String(),
        'imagen': imagen,
      };
}
