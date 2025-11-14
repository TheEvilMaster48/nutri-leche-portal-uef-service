class Cumpleanios {
  final int idCumpleanios;
  final String titulo;
  final String descripcion;
  final String tipo;
  final List<String> centros;
  final String fecha;
  final String hora;
  final String creadoPor;
  final String? imagenPath;
  int estado; 

  Cumpleanios({
    required this.idCumpleanios,
    required this.titulo,
    required this.descripcion,
    required this.tipo,
    required this.centros,
    required this.fecha,
    required this.hora,
    required this.creadoPor,
    this.imagenPath,
    this.estado = 0,
  });

  factory Cumpleanios.fromJson(Map<String, dynamic> json) {
    return Cumpleanios(
      idCumpleanios: (json['idCumpleanios'] ?? json['id'] ?? 0) is int
          ? (json['idCumpleanios'] ?? json['id'] ?? 0)
          : int.tryParse(json['idCumpleanios'].toString()) ?? 0,
      titulo: json['titulo']?.toString() ?? '',
      descripcion: json['descripcion']?.toString() ?? '',
      tipo: json['tipo']?.toString() ?? '',
      centros: (json['centros'] is List)
          ? List<String>.from(json['centros'])
          : (json['centros'] != null
              ? json['centros'].toString().split(',')
              : []),
      fecha: json['fecha']?.toString() ?? '',
      hora: json['hora']?.toString() ?? '',
      creadoPor: json['creadoPor']?.toString() ?? '',
      imagenPath: (json['imagenPath'] ??
              json['imagen'] ??
              json['imagenBase64'] ??
              json['imagen_url'])
          ?.toString(),
      estado: json['estado'] != null
          ? int.tryParse(json['estado'].toString()) ?? 0
          : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idCumpleanios': idCumpleanios,
      'titulo': titulo,
      'descripcion': descripcion,
      'tipo': tipo,
      'centros': centros,
      'fecha': fecha,
      'hora': hora,
      'creadoPor': creadoPor,
      'imagenPath': imagenPath,
      'estado': estado,
    };
  }
}
