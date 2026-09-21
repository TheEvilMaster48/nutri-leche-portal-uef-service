/// Un paso del viaje por el flujo de bodega.
///
/// Es **informativo**: lo escribe el ERP, no el chofer. La app solo lo pinta
/// como línea de tiempo para que el chofer sepa en qué va su carga.
///
/// No confundir con `EventoRuta`, del REST viejo `rutas/api/v1`: ese era un
/// catálogo de tipos de evento que el chofer elegía. Aquí los eventos ya
/// ocurrieron y vienen dados.
class EventoBodega {
  final int id;
  final int viajeId;

  /// Etapa a la que entró el viaje, en código.
  final String estado;

  /// La misma etapa en palabras, redactada por el servidor.
  final String estadoEtiqueta;

  /// `dd/MM/yyyy HH:mm`, ya formateada para pintar.
  final String ocurridoEn;

  /// Quién lo registró.
  final String responsable;

  final String nota;

  const EventoBodega({
    required this.id,
    this.viajeId = 0,
    this.estado = '',
    this.estadoEtiqueta = '',
    this.ocurridoEn = '',
    this.responsable = '',
    this.nota = '',
  });

  /// Lo que se muestra como título del paso.
  ///
  /// Se prefiere la etiqueta del servidor; el código queda como respaldo para
  /// que una etapa nueva no aparezca como una línea en blanco.
  String get titulo =>
      estadoEtiqueta.trim().isNotEmpty ? estadoEtiqueta.trim() : estado.trim();

  factory EventoBodega.fromJson(Map<String, dynamic> json) => EventoBodega(
        id: _aInt(json['id']),
        viajeId: _aInt(json['viajeId']),
        estado: _aTexto(json['estado']).trim(),
        estadoEtiqueta: _aTexto(json['estadoEtiqueta']).trim(),
        ocurridoEn: _aTexto(json['ocurridoEn']),
        responsable: _aTexto(json['responsable']).trim(),
        nota: _aTexto(json['nota']).trim(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'viajeId': viajeId,
        'estado': estado,
        'estadoEtiqueta': estadoEtiqueta,
        'ocurridoEn': ocurridoEn,
        'responsable': responsable,
        'nota': nota,
      };

  @override
  String toString() => 'EventoBodega($id, $estado, $ocurridoEn)';
}

int _aInt(dynamic v) =>
    v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

String _aTexto(dynamic v) => v?.toString() ?? '';
