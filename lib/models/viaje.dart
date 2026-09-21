import 'destinatario.dart';

/// Viaje asignado a un chofer.
///
/// Llega de dos endpoints con la misma forma salvo un campo:
///
/// * `post_viajes_by_id_usuario` → lista de viajes, sin destinatarios.
/// * `cambiar_status_viaje` (al iniciar) → un viaje **con** `dests`, la lista de
///   destinatarios. Es la única vía por la que llegan los destinatarios.
///
/// Los nombres del cable arrastran erratas y snake_case sueltos (`destinp`,
/// `fecha_iviaje`, `fecha_fviaje`). Se conservan al serializar y se exponen con
/// nombres legibles en Dart.
class Viaje {
  final int id;

  final String origen;

  /// Destino del viaje. En el cable la llave es `destinp` — errata del backend.
  final String destino;

  /// A dónde vuelve el chofer al terminar: casa o empresa.
  final String retorno;

  /// Fecha de inicio. En el cable, `fecha_iviaje`.
  final String fechaInicio;

  /// Fecha de fin. En el cable, `fecha_fviaje`.
  final String fechaFin;

  final String horaSalida;

  /// Número de entrega. Aquí llega como texto; en [Destinatario] el mismo
  /// concepto llega como entero. La inconsistencia es del backend.
  final String nentrega;

  final String placa;

  /// Estado del viaje.
  ///
  /// Ojo: el comentario del modelo Java dice `// 0, activ0 : 1 inactivo`, pero
  /// el código hace lo contrario — `consultarViajaActivo()` filtra por
  /// `estado == 1`, y al iniciar un viaje la app sobreescribe con 1 lo que
  /// responda el servidor. Vale el código, no el comentario: **1 = en curso**.
  ///
  /// Los estados que la app envía son `1` al iniciar y `3` al finalizar.
  final int estado;

  final String observaciones;
  final String fechaCreacion;
  final String usuarioCreacion;

  /// Puntos de entrega. Solo viene poblada cuando el viaje llega de
  /// `cambiar_status_viaje`; en el listado está vacía.
  final List<Destinatario> destinatarios;

  const Viaje({
    required this.id,
    this.origen = '',
    this.destino = '',
    this.retorno = '',
    this.fechaInicio = '',
    this.fechaFin = '',
    this.horaSalida = '',
    this.nentrega = '',
    this.placa = '',
    this.estado = 0,
    this.observaciones = '',
    this.fechaCreacion = '',
    this.usuarioCreacion = '',
    this.destinatarios = const [],
  });

  /// Ver la nota de [estado]: 1 es el viaje que el chofer tiene en curso.
  bool get enCurso => estado == 1;

  /// Estado con el que se marca localmente un viaje al iniciarlo.
  static const int estadoEnCurso = 1;

  /// Estado que se envía a `cambiar_status_viaje1` para cerrar el viaje.
  static const int estadoFinalizado = 3;

  String get ruta {
    final o = origen.trim();
    final d = destino.trim();
    if (o.isEmpty && d.isEmpty) return '';
    if (d.isEmpty) return o;
    if (o.isEmpty) return d;
    return '$o → $d';
  }

  Viaje copyWith({int? estado, List<Destinatario>? destinatarios}) => Viaje(
        id: id,
        origen: origen,
        destino: destino,
        retorno: retorno,
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
        horaSalida: horaSalida,
        nentrega: nentrega,
        placa: placa,
        estado: estado ?? this.estado,
        observaciones: observaciones,
        fechaCreacion: fechaCreacion,
        usuarioCreacion: usuarioCreacion,
        destinatarios: destinatarios ?? this.destinatarios,
      );

  factory Viaje.fromJson(Map<String, dynamic> json) => Viaje(
        id: _aInt(json['id']),
        origen: _aTexto(json['origen']).trim(),
        destino: _aTexto(json['destinp'] ?? json['destino']).trim(),
        retorno: _aTexto(json['retorno']).trim(),
        fechaInicio: _aTexto(json['fecha_iviaje'] ?? json['fechaInicio']),
        fechaFin: _aTexto(json['fecha_fviaje'] ?? json['fechaFin']),
        horaSalida: _aTexto(json['horaSalida']),
        nentrega: _aTexto(json['nentrega']),
        placa: _aTexto(json['placa']).trim(),
        estado: _aInt(json['estado']),
        observaciones: _aTexto(json['observaciones']),
        fechaCreacion: _aTexto(json['fechaCreacion']),
        usuarioCreacion: _aTexto(json['usuarioCreacion']),
        destinatarios: (json['dests'] is List)
            ? (json['dests'] as List)
                .whereType<Map>()
                .map((d) => Destinatario.fromJson(d.cast<String, dynamic>()))
                .toList()
            : const [],
      );

  /// Con los nombres del cable, erratas incluidas, para que `fromJson` sirva
  /// igual con la respuesta del WS y con el viaje guardado en local.
  Map<String, dynamic> toJson() => {
        'id': id,
        'origen': origen,
        'destinp': destino,
        'retorno': retorno,
        'fecha_iviaje': fechaInicio,
        'fecha_fviaje': fechaFin,
        'horaSalida': horaSalida,
        'nentrega': nentrega,
        'placa': placa,
        'estado': estado,
        'observaciones': observaciones,
        'fechaCreacion': fechaCreacion,
        'usuarioCreacion': usuarioCreacion,
        'dests': destinatarios.map((d) => d.toJson()).toList(),
      };

  @override
  String toString() => 'Viaje($id, $ruta, placa $placa, estado $estado)';
}

int _aInt(dynamic v) =>
    v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

String _aTexto(dynamic v) => v?.toString() ?? '';
