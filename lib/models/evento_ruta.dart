/// Evento del catálogo del módulo Rutas: DESCANSO, ALIMENTACION, CARGA DE
/// PRODUCTO, COMBUSTIBLE 1…
///
/// Se llama `EventoRuta` y no `Evento` para no chocar con el `Evento` de
/// `models/evento.dart`, que es el evento corporativo del portal y no tiene
/// nada que ver con este.
///
/// El catálogo se descarga de `post_eventos`, que devuelve un array JSON
/// desnudo. Forma verificada contra producción (12 registros):
///
/// ```json
/// {"id":121,"fechaCreacion":"11/03/2025 15:55:16","usuarioCreacion":"root",
///  "observaciones":"Descanso corto durante la ruta","nombre":"DESCANSO",
///  "tiempoestimado":20,"evidencia":0,"notas":"nota3"}
/// ```
class EventoRuta {
  final int id;

  /// Nombre que ve el conductor en el selector.
  ///
  /// Llega con espacios sobrantes en algunos registros de producción, así que
  /// se recorta al parsear: el WS tiene tanto `"ALIMENTACION"` como
  /// `"ALIMENTACION "` como dos registros distintos, y sin recortar el selector
  /// mostraría dos opciones que parecen iguales. El [id] sigue siendo la
  /// identidad; el nombre es solo presentación.
  final String nombre;

  /// Minutos que el evento debería durar.
  ///
  /// En el cable el campo es `tiempoestimado`, todo en minúsculas. Al registrar
  /// un evento se arranca una cuenta atrás con este valor y se avisa al vencer.
  final int tiempoEstimado;

  /// 1 cuando el WS marca la evidencia fotográfica como requerida.
  ///
  /// Hoy los 12 eventos del catálogo de producción vienen en 0, así que esta
  /// rama no se ejerce con datos reales. La foto sigue siendo opcional para
  /// cualquier evento.
  final int evidencia;

  final String notas;

  /// Puede no venir: el WS omite la llave por completo en algunos registros
  /// (ids 161 y 162 en producción), no la manda nula.
  final String observaciones;

  final String fechaCreacion;
  final String usuarioCreacion;

  const EventoRuta({
    required this.id,
    required this.nombre,
    required this.tiempoEstimado,
    this.evidencia = 0,
    this.notas = '',
    this.observaciones = '',
    this.fechaCreacion = '',
    this.usuarioCreacion = '',
  });

  bool get exigeEvidencia => evidencia == 1;

  /// Detalle que permite distinguir dos eventos con el mismo [nombre].
  ///
  /// El catálogo de producción tiene dos registros llamados «ALIMENTACION»
  /// (ids 141 y 142) que se diferencian solo aquí: uno es «Desayuno» y el otro
  /// «Almuerzo». Mostrando únicamente el nombre, el selector le presenta al
  /// chofer dos opciones idénticas y elegir una es un volado.
  ///
  /// Queda vacío cuando no aporta nada — varios eventos repiten el nombre en
  /// [notas], como «CARGA DE PRODUCTO».
  String get detalle {
    for (final candidato in [notas, observaciones]) {
      final texto = candidato.trim();
      if (texto.isEmpty) continue;
      if (texto.toLowerCase() == nombre.toLowerCase()) continue;
      return texto;
    }
    return '';
  }

  Duration get duracionEstimada => Duration(minutes: tiempoEstimado);

  factory EventoRuta.fromJson(Map<String, dynamic> json) => EventoRuta(
        id: _aInt(json['id']),
        nombre: _aTexto(json['nombre']).trim(),
        tiempoEstimado: _aInt(json['tiempoestimado'] ?? json['tiempoEstimado']),
        evidencia: _aInt(json['evidencia']),
        notas: _aTexto(json['notas']),
        observaciones: _aTexto(json['observaciones']),
        fechaCreacion: _aTexto(json['fechaCreacion']),
        usuarioCreacion: _aTexto(json['usuarioCreacion']),
      );

  /// Se guarda tal cual para la caché local del catálogo, con los nombres del
  /// cable, de modo que `fromJson` sirva igual para el WS y para la caché.
  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'tiempoestimado': tiempoEstimado,
        'evidencia': evidencia,
        'notas': notas,
        'observaciones': observaciones,
        'fechaCreacion': fechaCreacion,
        'usuarioCreacion': usuarioCreacion,
      };

  @override
  String toString() => 'EventoRuta($id, $nombre, ${tiempoEstimado}min)';
}

int _aInt(dynamic v) =>
    v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

String _aTexto(dynamic v) => v?.toString() ?? '';

