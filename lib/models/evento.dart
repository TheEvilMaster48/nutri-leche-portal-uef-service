class Evento {
  final int idEvento;

  /// Id de la cabecera de notificación, si el WS lo manda.
  ///
  /// El push de eventos/cumpleaños/sorteos identifica el contenido con
  /// `idCabecera`, que no necesariamente es el mismo número que [idEvento].
  /// Queda en 0 si `ObtenerEventos` no lo devuelve.
  final int idCabecera;
  final String titulo;
  final String descripcion;
  final String tipo;
  final List<String> centros;
  final String fecha;
  final String horaEvento;
  final String creadoPor;
  final String? imagenPath;
  final String? archivoPath;

  int estado;

  String get id => idEvento.toString();

  Evento({
    required this.idEvento,
    this.idCabecera = 0,
    required this.titulo,
    required this.descripcion,
    required this.tipo,
    required this.centros,
    required this.fecha,
    required this.horaEvento,
    required this.creadoPor,
    this.imagenPath,
    this.archivoPath,
    this.estado = 0,
  });

  Map<String, dynamic> toJson() => {
        'idEvento': idEvento,
        'idCabecera': idCabecera,
        'titulo': titulo,
        'descripcion': descripcion,
        'tipo': tipo,
        'centros': centros,
        'fecha': fecha,
        'horaEvento': horaEvento,
        'creadoPor': creadoPor,
        'imagenPath': imagenPath,
        'archivoPath': archivoPath,
        'estado': estado,
      };

  factory Evento.fromJson(Map<String, dynamic> json) => Evento(
        idEvento: (json['idEvento'] ?? json['id'] ?? 0) is int
            ? (json['idEvento'] ?? json['id'] ?? 0)
            : int.tryParse(json['idEvento'].toString()) ?? 0,
        idCabecera: _aInt(json['idCabecera'] ?? json['id_cabecera']),
        titulo: json['titulo']?.toString() ?? '',
        descripcion: json['descripcion']?.toString() ?? '',
        tipo: json['tipo']?.toString() ?? '',
        centros: (json['centros'] is List)
            ? List<String>.from(json['centros'])
            : (json['centros'] != null
                ? json['centros'].toString().split(',')
                : []),
        fecha: json['fecha']?.toString() ?? '',
        horaEvento: (json['horaEvento'] ??
                json['hora'] ??
                json['hora_evento'] ??
                '')
            .toString(),
        creadoPor: json['creadoPor']?.toString() ?? '',
        imagenPath: (json['imagenPath'] ??
                json['imagen'] ??
                json['imagenBase64'] ??
                json['imagen_url'])
            ?.toString(),
        archivoPath: json['archivoPath']?.toString(),
        estado: json['estado'] != null
            ? int.tryParse(json['estado'].toString()) ?? 0
            : 0,
      );
}

int _aInt(dynamic v) =>
    v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
