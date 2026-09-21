import 'package:intl/intl.dart';

/// Tramo del viaje al que pertenece un registro.
///
/// En la app Android esto salía de un selector llamado `spinnerLugar`, que
/// sugiere el catálogo de lugares pero no lo es: se alimentaba del array
/// estático `tipo_viaje` del XML, con los valores `--Seleccione--`, `IDA` y
/// `RETORNO`, y el texto se guardaba tal cual. `post_lugares` nunca se llamó y
/// hoy devuelve `[]` en producción. Es un enum, no una consulta.
enum TipoViaje {
  ida('IDA'),
  retorno('RETORNO');

  const TipoViaje(this.codigo);

  /// Texto exacto que espera el WS en el campo `tipoViaje`.
  final String codigo;

  static TipoViaje? desdeCodigo(String? valor) {
    if (valor == null) return null;
    final v = valor.trim().toUpperCase();
    for (final t in TipoViaje.values) {
      if (t.codigo == v) return t;
    }
    return null;
  }
}

/// Un evento registrado durante un viaje: se abre al iniciarlo y se cierra al
/// terminarlo, y se acumula en local hasta que el viaje se cierra y se envía
/// todo junto con `guardar_registro_ruta`.
///
/// Vive solo en el teléfono mientras el viaje está en curso. El `id` es local
/// y correlativo, no viene del servidor.
class RegistroViaje {
  /// Estado de un registro abierto — el evento está ocurriendo.
  ///
  /// Ojo con el modelo Java: su comentario dice `// 0, abierto : 1 cerrado`,
  /// pero `getRegistrosAbiertos()` filtra por `estado == 1` y
  /// `getRegistrosCerrados()` por `estado == 0`. **Manda el código: 1 está
  /// abierto.** El comentario es falso y ya costó una confusión.
  static const int estadoAbierto = 1;

  /// Estado de un registro cerrado, listo para enviarse.
  static const int estadoCerrado = 0;

  /// Formato con el que la app Android viene enviando las fechas al WS.
  ///
  /// Se conserva exacto: el backend lleva años recibiendo este formato y no es
  /// el mismo con el que responde el catálogo (que usa `/` en lugar de `-`).
  static final DateFormat formatoWs = DateFormat('dd-MM-yyyy HH:mm:ss');

  static String ahora() => formatoWs.format(DateTime.now());

  final int id;
  final int viajeId;
  final int eventoId;

  final TipoViaje tipoViaje;

  /// [estadoAbierto] o [estadoCerrado].
  final int estado;

  /// Cuándo se abrió el registro, en el formato de [formatoWs].
  final String fechaCreacion;

  /// Cuándo se cerró. Vacío mientras el registro sigue abierto.
  final String fechaFin;

  /// Posición al abrir el evento.
  final double latitud;
  final double longitud;

  /// Posición al cerrarlo. Se captura y se guarda en local, pero **el WS no
  /// tiene campos para recibirla** — ver [toRegistroRutaWS].
  final double latitudFinal;
  final double longitudFinal;

  /// Nombres base de las fotos de evidencia, sin extensión (`ruta-<millis>`).
  ///
  /// Es una lista y no un solo texto a propósito. La app Android permitía tomar
  /// hasta 3 fotos pero guardaba únicamente el nombre de la última en su campo
  /// `evidencia`: las otras dos quedaban escritas en el teléfono y nunca se
  /// subían ni se referenciaban. Guardándolas todas no se pierde ninguna, y
  /// [toRegistroRutaWS] sigue mandando una sola para no romper el contrato.
  final List<String> evidencias;

  /// Notas del conductor. Se capturan y se guardan en local, pero **el WS no
  /// tiene campo para recibirlas** — ver [toRegistroRutaWS].
  final String observaciones;

  const RegistroViaje({
    required this.id,
    required this.viajeId,
    required this.eventoId,
    required this.tipoViaje,
    required this.fechaCreacion,
    this.estado = estadoAbierto,
    this.fechaFin = '',
    this.latitud = 0,
    this.longitud = 0,
    this.latitudFinal = 0,
    this.longitudFinal = 0,
    this.evidencias = const [],
    this.observaciones = '',
  });

  bool get abierto => estado == estadoAbierto;
  bool get cerrado => estado == estadoCerrado;

  bool get tieneEvidencia => evidencias.isNotEmpty;

  /// Devuelve una copia cerrada, con la hora y la posición del cierre.
  RegistroViaje cerrar({
    required double latitudFinal,
    required double longitudFinal,
  }) =>
      copyWith(
        estado: estadoCerrado,
        fechaFin: ahora(),
        latitudFinal: latitudFinal,
        longitudFinal: longitudFinal,
      );

  RegistroViaje copyWith({
    int? estado,
    String? fechaFin,
    double? latitudFinal,
    double? longitudFinal,
    List<String>? evidencias,
    String? observaciones,
  }) =>
      RegistroViaje(
        id: id,
        viajeId: viajeId,
        eventoId: eventoId,
        tipoViaje: tipoViaje,
        fechaCreacion: fechaCreacion,
        estado: estado ?? this.estado,
        fechaFin: fechaFin ?? this.fechaFin,
        latitud: latitud,
        longitud: longitud,
        latitudFinal: latitudFinal ?? this.latitudFinal,
        longitudFinal: longitudFinal ?? this.longitudFinal,
        evidencias: evidencias ?? this.evidencias,
        observaciones: observaciones ?? this.observaciones,
      );

  /// Cuerpo de un elemento del array `data` de `guardar_registro_ruta`.
  ///
  /// [time] es un milisegundos-epoch que la app Android calcula **una vez por
  /// lote** y repite en todos los registros del envío, así que lo recibe de
  /// fuera en lugar de generarlo aquí.
  ///
  /// Tres campos que el modelo tiene y este payload no: `observaciones`,
  /// `latitudFinal` y `longitudFinal`. No es un olvido de la migración —
  /// `RegistroRutaWS` nunca los tuvo, así que la app viene capturándolos y
  /// descartándolos. Está preguntado a backend si deben viajar.
  Map<String, dynamic> toRegistroRutaWS({required int time}) => {
        'tipoViaje': tipoViaje.codigo,
        // Una sola, por contrato. Ver la nota de [evidencias].
        'evidencia': evidencias.isEmpty ? '' : evidencias.first,
        'latitud': latitud,
        'longitud': longitud,
        'eventoId': eventoId,
        'viajeId': viajeId,
        'time': time,
        'fechaCreacion': fechaCreacion,
        'fechaFin': fechaFin,
      };

  /// Para la persistencia local. Guarda todo, incluido lo que el WS no recibe.
  Map<String, dynamic> toJson() => {
        'id': id,
        'viajeId': viajeId,
        'eventoId': eventoId,
        'tipoViaje': tipoViaje.codigo,
        'estado': estado,
        'fechaCreacion': fechaCreacion,
        'fechaFin': fechaFin,
        'latitud': latitud,
        'longitud': longitud,
        'latitudFinal': latitudFinal,
        'longitudFinal': longitudFinal,
        'evidencias': evidencias,
        'observaciones': observaciones,
      };

  factory RegistroViaje.fromJson(Map<String, dynamic> json) => RegistroViaje(
        id: _aInt(json['id']),
        viajeId: _aInt(json['viajeId']),
        eventoId: _aInt(json['eventoId']),
        tipoViaje: TipoViaje.desdeCodigo(json['tipoViaje']?.toString()) ??
            TipoViaje.ida,
        estado: _aInt(json['estado']),
        fechaCreacion: _aTexto(json['fechaCreacion']),
        fechaFin: _aTexto(json['fechaFin']),
        latitud: _aDouble(json['latitud']),
        longitud: _aDouble(json['longitud']),
        latitudFinal: _aDouble(json['latitudFinal']),
        longitudFinal: _aDouble(json['longitudFinal']),
        evidencias: (json['evidencias'] is List)
            ? List<String>.from(
                (json['evidencias'] as List).map((e) => e.toString()))
            // Tolera el formato viejo de un solo nombre, por si alguna vez se
            // lee un registro guardado antes de pasar a lista.
            : (json['evidencia'] != null &&
                    json['evidencia'].toString().isNotEmpty)
                ? [json['evidencia'].toString()]
                : const [],
        observaciones: _aTexto(json['observaciones']),
      );

  @override
  String toString() =>
      'RegistroViaje($id, viaje $viajeId, evento $eventoId, '
      '${abierto ? "abierto" : "cerrado"})';
}

int _aInt(dynamic v) =>
    v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

double _aDouble(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

String _aTexto(dynamic v) => v?.toString() ?? '';
