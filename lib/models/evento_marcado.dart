import 'package:intl/intl.dart';

/// Un evento que el chofer ya marcó en el viaje: un elemento de `eventosRuta`.
///
/// El chofer abre un evento del catálogo ([EventoRuta]) y después lo cierra. De
/// cada uno el servidor guarda cuatro cosas: cuándo empezó y dónde, cuándo
/// terminó y dónde. **El evento es del viaje, no de una entrega.**
///
/// No confundir con [EventoBodega], que es el avance del viaje por el flujo de
/// planta y lo escribe el ERP, no el chofer.
///
/// **Los minutos los calcula el servidor**, no se derivan acá: van a reportes, y
/// si cada cliente los calculara, al cambiar la regla habría dos versiones de la
/// verdad. Lo mismo con [excedido].
class EventoMarcado {
  /// Id de **esta marca**. Es el `registro_id` que se manda a `/cerrar_evento`.
  ///
  /// El id más fácil de confundir del contrato: mandar [eventoId] en su lugar
  /// devuelve «Evento no encontrado en este viaje».
  final int id;

  /// Id en el catálogo. Es el `evento_id` con el que se abrió.
  final int eventoId;

  /// Nombre del evento, copiado del catálogo al marcar.
  ///
  /// Viaja con la marca a propósito: un evento dado de baja deja de bajar en
  /// `/eventos`, pero las marcas que ya lo usaron conservan su nombre.
  final String nombre;

  /// `dd/MM/yyyy HH:mm`, ya formateada para pintar.
  final String inicioEn;

  /// Vacío mientras el evento sigue abierto.
  final String finEn;

  /// Dónde empezó y dónde terminó. Independientes: así se ve un camión que
  /// empezó a descargar en un sitio y terminó en otro. Todas opcionales —
  /// sin GPS o bajo techo se marca igual.
  final double? latitudInicio;
  final double? longitudInicio;
  final double? latitudFin;
  final double? longitudFin;

  /// `true` = falta cerrarlo.
  final bool abierto;

  /// Lo que duró, o lo que lleva si sigue abierto.
  final int minutos;

  /// Lo que el catálogo estima. 0 si no lo dice.
  final int minutosEstimados;

  /// `true` si ya pasó del estimado.
  final bool excedido;

  /// `true` = el catálogo pide foto para este evento.
  final bool exigeEvidencia;

  const EventoMarcado({
    required this.id,
    this.eventoId = 0,
    this.nombre = '',
    this.inicioEn = '',
    this.finEn = '',
    this.latitudInicio,
    this.longitudInicio,
    this.latitudFin,
    this.longitudFin,
    this.abierto = false,
    this.minutos = 0,
    this.minutosEstimados = 0,
    this.excedido = false,
    this.exigeEvidencia = false,
  });

  /// Lo que se muestra como nombre, con el id de respaldo para que un evento
  /// sin nombre no aparezca como un hueco.
  String get titulo => nombre.trim().isNotEmpty ? nombre.trim() : 'Evento $id';

  /// [inicioEn] como fecha, para el contador en pantalla.
  ///
  /// `null` si el formato no es el esperado: se prefiere quedarse sin contador
  /// a reventar la tarjeta por un formato inesperado.
  DateTime? get inicioInstante {
    final texto = inicioEn.trim();
    if (texto.isEmpty) return null;
    for (final formato in const ['dd/MM/yyyy HH:mm', 'dd/MM/yyyy HH:mm:ss']) {
      try {
        return DateFormat(formato).parseStrict(texto);
      } catch (_) {
        // Se prueba el siguiente.
      }
    }
    return null;
  }

  /// Si tiene posición de inicio para pintar en un mapa. Las dos o ninguna: una
  /// sola coordenada no se puede ubicar.
  bool get tieneUbicacionInicio =>
      latitudInicio != null && longitudInicio != null;

  bool get tieneUbicacionFin => latitudFin != null && longitudFin != null;

  factory EventoMarcado.fromJson(Map<String, dynamic> json) {
    final finEn = _aTexto(json['finEn']).trim();

    return EventoMarcado(
      id: _aInt(json['id']),
      eventoId: _aInt(json['eventoId']),
      nombre: _aTexto(json['nombre']).trim(),
      inicioEn: _aTexto(json['inicioEn']).trim(),
      finEn: finEn,
      latitudInicio: _aDecimal(json['latitudInicio']),
      longitudInicio: _aDecimal(json['longitudInicio']),
      latitudFin: _aDecimal(json['latitudFin']),
      longitudFin: _aDecimal(json['longitudFin']),
      // Manda el campo del servidor; sin él se deduce de que no haya fin, que
      // es la misma regla que aplica el servidor.
      abierto: _aBool(json['abierto'], siFalta: finEn.isEmpty),
      minutos: _aInt(json['minutos']),
      minutosEstimados: _aInt(json['minutosEstimados']),
      excedido: _aBool(json['excedido'], siFalta: false),
      exigeEvidencia: _aBool(json['exigeEvidencia'], siFalta: false),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'eventoId': eventoId,
        'nombre': nombre,
        'inicioEn': inicioEn,
        'finEn': finEn,
        'latitudInicio': latitudInicio,
        'longitudInicio': longitudInicio,
        'latitudFin': latitudFin,
        'longitudFin': longitudFin,
        'abierto': abierto,
        'minutos': minutos,
        'minutosEstimados': minutosEstimados,
        'excedido': excedido,
        'exigeEvidencia': exigeEvidencia,
      };

  @override
  String toString() =>
      'EventoMarcado($id, evento $eventoId $nombre, '
      '${abierto ? "abierto" : "cerrado"} ${minutos}min)';
}

int _aInt(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

String _aTexto(dynamic v) => v?.toString() ?? '';

double? _aDecimal(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

/// Laxo, como el resto de los booleanos del WS: llegan como `true`, `1` o
/// `"true"` según el campo.
bool _aBool(dynamic v, {required bool siFalta}) {
  if (v == null) return siFalta;
  if (v is bool) return v;
  final texto = v.toString().trim().toLowerCase();
  if (texto.isEmpty) return siFalta;
  return texto == 'true' || texto == '1';
}
