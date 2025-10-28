class Reconocimiento {
  final int id;
  final String titulo;
  final String descripcion;
  final String autor;
  final String otorgadoA;
  final String departamento;
  final String tipo;
  final DateTime fecha;
  final List<String> archivos;

  Reconocimiento({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.autor,
    required this.otorgadoA,
    required this.departamento,
    required this.tipo,
    required this.fecha,
    this.archivos = const [],
  });

  factory Reconocimiento.fromJson(Map<String, dynamic> json) {
    final archivosJson = json['archivos'];
    final archivosSeguros = archivosJson is List
        ? archivosJson.map((a) => a.toString()).toList()
        : <String>[];

    return Reconocimiento(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      titulo: json['titulo'] ?? '',
      descripcion: json['descripcion'] ?? '',
      autor: json['autor'] ?? '',
      otorgadoA: json['otorgadoA'] ?? '',
      departamento: json['departamento'] ?? '',
      tipo: json['tipo'] ?? '',
      fecha: DateTime.tryParse(json['fecha'] ?? '') ?? DateTime.now(),
      archivos: archivosSeguros,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'descripcion': descripcion,
        'autor': autor,
        'otorgadoA': otorgadoA,
        'departamento': departamento,
        'tipo': tipo,
        'fecha': fecha.toIso8601String(),
        'archivos': archivos,
      };
}
