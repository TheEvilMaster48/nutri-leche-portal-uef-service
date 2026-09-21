import 'package:intl/intl.dart';

import 'entrega.dart';

/// Qué se le está pidiendo al servidor: abrir un evento o cerrarlo.
enum AccionEvento {
  /// `POST /marcar` — crea la fila con el evento, la hora y la ubicación de
  /// inicio.
  abrir('marcar'),

  /// `POST /cerrar_evento` — el único sitio donde se guardan la hora y la
  /// ubicación de fin.
  cerrar('cerrar_evento'),

  /// `POST /marcar_entrega` — lo que pasó con un cliente: llegué, se la dejé o
  /// no se pudo.
  entrega('marcar_entrega'),

  /// `POST /salida` — la salida de planta, que abre el recorrido.
  ///
  /// Es el primer gesto del viaje y el requisito de todo lo demás: el servidor
  /// rechaza eventos y regreso mientras no conste.
  salida('salida'),

  /// `POST /retorno` — el regreso a planta, que cierra el recorrido.
  ///
  /// Es del viaje, no del catálogo: el regreso no es un motivo de la app. Va por
  /// la misma cola que lo demás porque pasa en el mismo sitio —la carretera— y
  /// sin cobertura tan a menudo como el resto.
  retorno('retorno');

  const AccionEvento(this.recurso);

  /// Recurso de `wms/api/v1` al que se manda.
  final String recurso;
}

/// Un evento que el chofer marcó, listo para enviarse al WS.
///
/// Existe como objeto —y no como una llamada directa— porque en ruta no hay
/// cobertura la mitad del tiempo. El chofer marca, la marca se guarda con **la
/// hora del teléfono en ese momento** y su posición, y se envía cuando haya
/// señal. Si en cambio se dejara que el servidor pusiera la hora, un evento de
/// las 10:00 quedaría registrado a la hora en que el teléfono recuperó
/// cobertura — y de esa hora salen todos los tiempos del reporte.
///
/// Abrir y cerrar son la misma clase porque comparten todo lo que importa acá:
/// van a la misma cola, se sellan igual y se reintentan igual. Lo único que
/// cambia es el recurso y dos campos del cuerpo.
class MarcaRuta {
  /// Formato de `inicio_en` y `fin_en`: `yyyy-MM-dd HH:mm:ss`.
  ///
  /// **No es el mismo** que usa `RegistroViaje` para el REST viejo
  /// (`dd-MM-yyyy HH:mm:ss`). Confundirlos manda una fecha que el servidor
  /// rechaza con «La hora de inicio no tiene el formato yyyy-MM-dd HH:mm:ss».
  static final DateFormat formatoHora = DateFormat('yyyy-MM-dd HH:mm:ss');

  static String ahora() => formatoHora.format(DateTime.now());

  /// Id local y correlativo. No viaja al servidor: sirve para ordenar la cola y
  /// para sacar la marca de ella cuando se confirma.
  final int id;

  final int viajeId;

  final AccionEvento accion;

  /// Id del catálogo (`/eventos`). Obligatorio al abrir.
  final int eventoId;

  /// Nombre del evento, solo para los avisos en pantalla mientras está en cola.
  /// No viaja al servidor.
  final String nombre;

  /// Qué se marca en la entrega. Solo en [AccionEvento.entrega].
  final EstadoRutaEntrega? hitoEntrega;

  /// Por qué no se pudo entregar. Obligatorio al marcar no entregado.
  final String motivo;

  /// Id de la marca que se cierra — el `eventoAbiertoId` del viaje.
  ///
  /// En [AccionEvento.entrega] lleva el id de **la entrega**: las dos son «sobre
  /// qué fila del servidor va esto», y separarlas obligaría a arrastrar dos
  /// campos que nunca conviven.
  ///
  /// Opcional en el contrato: sin él, el servidor cierra el único evento abierto
  /// del viaje, y con dos abiertos responde «Hay N eventos abiertos: indique
  /// cual se cierra». Se manda siempre que se tenga.
  final int? registroId;

  /// Hora del teléfono al marcar, en [formatoHora]. Es `inicio_en` al abrir y
  /// `fin_en` al cerrar.
  final String ocurridoEn;

  /// Dónde estaba el camión. Opcionales: sin GPS se marca igual — negarse a
  /// registrar un evento porque el teléfono no fijó satélites dejaría al chofer
  /// parado. Las dos o ninguna: una sola no se puede pintar en el mapa.
  final double? latitud;
  final double? longitud;

  /// Cuántas veces se intentó enviarla. Solo para mostrar el estado de la cola;
  /// el servidor es idempotente, así que reintentar no tiene costo.
  final int intentos;

  /// Lo último que dijo el servidor o la red. Se muestra si la cola se atasca.
  final String ultimoError;

  const MarcaRuta({
    required this.id,
    required this.viajeId,
    required this.ocurridoEn,
    this.accion = AccionEvento.abrir,
    this.eventoId = 0,
    this.nombre = '',
    this.registroId,
    this.hitoEntrega,
    this.motivo = '',
    this.latitud,
    this.longitud,
    this.intentos = 0,
    this.ultimoError = '',
  });

  /// Abre un evento del catálogo.
  const MarcaRuta.abrir({
    required this.id,
    required this.viajeId,
    required this.eventoId,
    required this.ocurridoEn,
    this.nombre = '',
    this.latitud,
    this.longitud,
    this.intentos = 0,
    this.ultimoError = '',
  })  : accion = AccionEvento.abrir,
        registroId = null,
        hitoEntrega = null,
        motivo = '';

  /// Lo que pasó con una entrega.
  const MarcaRuta.entrega({
    required this.id,
    required this.viajeId,
    required int this.registroId,
    required EstadoRutaEntrega this.hitoEntrega,
    required this.ocurridoEn,
    this.motivo = '',
    this.nombre = '',
    this.latitud,
    this.longitud,
    this.intentos = 0,
    this.ultimoError = '',
  })  : accion = AccionEvento.entrega,
        eventoId = 0;

  /// La salida de planta.
  const MarcaRuta.salida({
    required this.id,
    required this.viajeId,
    required this.ocurridoEn,
    this.latitud,
    this.longitud,
    this.intentos = 0,
    this.ultimoError = '',
  })  : accion = AccionEvento.salida,
        eventoId = 0,
        registroId = null,
        hitoEntrega = null,
        motivo = '',
        nombre = 'Salida de planta';

  /// El regreso a planta.
  const MarcaRuta.retorno({
    required this.id,
    required this.viajeId,
    required this.ocurridoEn,
    this.latitud,
    this.longitud,
    this.intentos = 0,
    this.ultimoError = '',
  })  : accion = AccionEvento.retorno,
        eventoId = 0,
        registroId = null,
        hitoEntrega = null,
        motivo = '',
        nombre = 'Regreso a planta';

  /// Cierra una marca abierta.
  const MarcaRuta.cerrar({
    required this.id,
    required this.viajeId,
    required this.ocurridoEn,
    this.registroId,
    this.nombre = '',
    this.latitud,
    this.longitud,
    this.intentos = 0,
    this.ultimoError = '',
  })  : accion = AccionEvento.cerrar,
        eventoId = 0,
        hitoEntrega = null,
        motivo = '';

  bool get esCierre => accion == AccionEvento.cerrar;

  bool get esRetorno => accion == AccionEvento.retorno;

  bool get esSalida => accion == AccionEvento.salida;

  bool get esEntrega => accion == AccionEvento.entrega;

  /// A qué recurso del WS se manda.
  String get recurso => accion.recurso;

  /// Cómo se le nombra al chofer en los avisos de la cola.
  String get etiquetaAccion {
    if (esEntrega) {
      final quien = nombre.trim().isEmpty ? 'La entrega' : nombre.trim();
      return '$quien: ${hitoEntrega?.etiqueta ?? ""}'.trim();
    }
    if (esSalida) return 'Salida de planta';
    if (esRetorno) return 'Regreso a planta';
    final quien = nombre.trim().isEmpty ? 'Evento' : nombre.trim();
    return esCierre ? 'Cierre de $quien' : quien;
  }

  /// Si le falta algo que el servidor va a rechazar de todos modos.
  ///
  /// Se valida antes de encolar: una marca inválida ocuparía la cola y se
  /// reintentaría para siempre sin poder llegar nunca.
  String? get problema {
    if (viajeId <= 0) return 'Falta el viaje.';

    if (accion == AccionEvento.abrir && eventoId <= 0) {
      return 'Elija el evento de la lista antes de marcar.';
    }

    if (esEntrega) {
      if (registroId == null || registroId! <= 0) {
        return 'No se pudo identificar la entrega.';
      }
      if (hitoEntrega == null) return 'Indique qué pasó con la entrega.';
      // Sin motivo el servidor la rechaza, y una marca inválida se queda
      // atascada al frente de la cola.
      if (hitoEntrega!.requiereMotivo && motivo.trim().isEmpty) {
        return 'Indique por qué no se pudo entregar.';
      }
    }

    // El registro es opcional en el contrato —sin él se cierra el único
    // abierto—, así que un cierre sin id es válido. Lo que no vale es un id
    // imposible: sería un error de la app, no una omisión.
    if (esCierre && registroId != null && registroId! <= 0) {
      return 'No se pudo identificar el evento que se quiere cerrar.';
    }

    if (ocurridoEn.trim().isEmpty) return 'Falta la hora del evento.';

    return null;
  }

  bool get valida => problema == null;

  MarcaRuta copyWith({int? intentos, String? ultimoError}) => MarcaRuta(
        id: id,
        viajeId: viajeId,
        accion: accion,
        eventoId: eventoId,
        nombre: nombre,
        registroId: registroId,
        hitoEntrega: hitoEntrega,
        motivo: motivo,
        ocurridoEn: ocurridoEn,
        latitud: latitud,
        longitud: longitud,
        intentos: intentos ?? this.intentos,
        ultimoError: ultimoError ?? this.ultimoError,
      );

  /// Cuerpo de la petición.
  ///
  /// Las coordenadas se omiten cuando no hay, en lugar de mandarse nulas: el
  /// contrato las marca opcionales y un nulo explícito invita a que el otro lado
  /// lo interprete distinto. Van las dos o ninguna. La hora va siempre.
  Map<String, dynamic> aPeticion(int usuarioId) {
    final hayUbicacion = latitud != null && longitud != null;

    if (esEntrega) {
      return {
        'usuario_id': usuarioId,
        'viaje_id': viajeId,
        'entrega_id': registroId,
        'hito': hitoEntrega!.codigo,
        'ocurrido_en': ocurridoEn,
        if (motivo.trim().isNotEmpty) 'motivo': motivo.trim(),
        if (hayUbicacion) 'latitud': latitud,
        if (hayUbicacion) 'longitud': longitud,
      };
    }

    if (esSalida) {
      return {
        'usuario_id': usuarioId,
        'viaje_id': viajeId,
        'inicio_en': ocurridoEn,
        if (hayUbicacion) 'latitud': latitud,
        if (hayUbicacion) 'longitud': longitud,
      };
    }

    if (esRetorno) {
      return {
        'usuario_id': usuarioId,
        'viaje_id': viajeId,
        'fin_en': ocurridoEn,
        if (hayUbicacion) 'latitud': latitud,
        if (hayUbicacion) 'longitud': longitud,
      };
    }

    if (esCierre) {
      return {
        'usuario_id': usuarioId,
        'viaje_id': viajeId,
        if (registroId != null) 'registro_id': registroId,
        'fin_en': ocurridoEn,
        if (hayUbicacion) 'latitud': latitud,
        if (hayUbicacion) 'longitud': longitud,
      };
    }

    return {
      'usuario_id': usuarioId,
      'viaje_id': viajeId,
      'evento_id': eventoId,
      'inicio_en': ocurridoEn,
      if (hayUbicacion) 'latitud': latitud,
      if (hayUbicacion) 'longitud': longitud,
    };
  }

  /// Para la cola en disco. Guarda también los contadores, que no van al WS.
  Map<String, dynamic> toJson() => {
        'id': id,
        'viajeId': viajeId,
        'accion': accion.name,
        'eventoId': eventoId,
        'nombre': nombre,
        'registroId': registroId,
        'hitoEntrega': hitoEntrega?.codigo,
        'motivo': motivo,
        'ocurridoEn': ocurridoEn,
        'latitud': latitud,
        'longitud': longitud,
        'intentos': intentos,
        'ultimoError': ultimoError,
      };

  factory MarcaRuta.fromJson(Map<String, dynamic> json) => MarcaRuta(
        id: _aInt(json['id']),
        viajeId: _aInt(json['viajeId']),
        accion: _accion(json['accion']),
        eventoId: _aInt(json['eventoId']),
        nombre: json['nombre']?.toString() ?? '',
        registroId:
            json['registroId'] == null ? null : _aInt(json['registroId']),
        hitoEntrega:
            EstadoRutaEntrega.desdeCodigo(json['hitoEntrega']?.toString()),
        motivo: json['motivo']?.toString() ?? '',
        ocurridoEn: json['ocurridoEn']?.toString() ?? '',
        latitud: _aDoubleNulo(json['latitud']),
        longitud: _aDoubleNulo(json['longitud']),
        intentos: _aInt(json['intentos']),
        ultimoError: json['ultimoError']?.toString() ?? '',
      );

  @override
  String toString() => switch (accion) {
        AccionEvento.entrega => 'MarcaRuta($id, viaje $viajeId, entrega '
            '$registroId → ${hitoEntrega?.codigo})',
        AccionEvento.salida => 'MarcaRuta($id, viaje $viajeId, salida de planta)',
        AccionEvento.retorno => 'MarcaRuta($id, viaje $viajeId, regreso a planta)',
        AccionEvento.cerrar =>
          'MarcaRuta($id, viaje $viajeId, cierre de la marca $registroId)',
        AccionEvento.abrir => 'MarcaRuta($id, viaje $viajeId, evento $eventoId)',
      };
}

AccionEvento _accion(dynamic v) {
  final texto = v?.toString().trim().toLowerCase();
  for (final a in AccionEvento.values) {
    if (a.name == texto) return a;
  }
  return AccionEvento.abrir;
}

int _aInt(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

double? _aDoubleNulo(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}
