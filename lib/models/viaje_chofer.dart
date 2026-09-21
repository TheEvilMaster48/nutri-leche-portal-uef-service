import 'entrega.dart';
import 'evento_marcado.dart';
import 'evento_bodega.dart';

/// Qué tan apurado va el viaje. La manda el ERP.
enum Urgencia {
  baja('BAJA'),
  media('MEDIA'),
  alta('ALTA');

  const Urgencia(this.codigo);

  final String codigo;

  static Urgencia desdeCodigo(String? valor) {
    final v = valor?.trim().toUpperCase();
    for (final u in Urgencia.values) {
      if (u.codigo == v) return u;
    }
    return Urgencia.baja;
  }
}

/// Un viaje asignado al chofer, con sus entregas y su línea de tiempo.
///
/// Se llama `ViajeChofer` y no `Viaje` para no chocar con el `Viaje` de
/// `models/viaje.dart`, que es el del REST viejo `rutas/api/v1` y tiene otro
/// modelo por completo.
///
/// **Las fechas se guardan como texto a propósito.** El servidor ya las manda
/// formateadas para pintar (`fecha` en `dd/MM/yyyy`, `horaLlegadaPlanta` en
/// `HH:mm`, `llegadaEn` y `cerradaEn` en `dd/MM/yyyy HH:mm`), así que
/// convertirlas a `DateTime` solo agregaría una oportunidad de romperlas por
/// locale. La única que se compara es [actualizadoEn], en
/// `yyyy-MM-dd HH:mm:ss`, y para eso el orden lexicográfico ya sirve.
class ViajeChofer {
  final int id;

  /// Número dentro del día: «el viaje 3 de hoy».
  final int numero;

  /// `dd/MM/yyyy`, lista para pintar.
  final String fecha;

  /// Etapa del flujo de bodega, en código.
  final String estado;

  /// La misma etapa en palabras, redactada por el servidor.
  final String estadoEtiqueta;

  final Urgencia urgencia;

  final String cliente;
  final String destino;

  final String placa;
  final String transportista;
  final String vehiculo;

  /// `HH:mm`.
  final String horaLlegadaPlanta;

  /// `HH:mm`.
  final String horaEntregaCliente;

  final String observaciones;

  /// Qué lleva a bordo. **Sin estado de ruta**: el chofer no marca entrega por
  /// entrega, solo dice a quién va el producto.
  final List<Entrega> entregas;

  final int totalEntregas;

  /// Línea de tiempo de bodega: preparado, verificado, despachado. La escribe el
  /// ERP. No confundir con [eventosRuta], que es lo que marca el chofer.
  final List<EventoBodega> eventos;

  /// Lo que el chofer ya marcó en este viaje, del más antiguo al más reciente.
  final List<EventoMarcado> eventosRuta;

  final int totalEventosRuta;

  /// Id de la marca abierta, o `null` si no hay ninguna.
  ///
  /// Es el `registro_id` que se manda a `/cerrar_evento`. Cuando no es `null`,
  /// la pantalla ofrece cerrar en vez de abrir otro.
  final int? eventoAbiertoId;

  /// Nombre del evento abierto, para pintar el botón sin ir a buscarlo a la
  /// lista. Vacío si no hay ninguno abierto.
  final String eventoAbierto;

  /// `dd/MM/yyyy HH:mm`. Vacío mientras el camión siga en el patio.
  ///
  /// Lo pone `POST /salida`. Es el primer gesto del viaje y el **requisito** de
  /// todo lo demás: sin él, el servidor rechaza eventos y regreso con «Primero
  /// marque la salida de planta».
  ///
  /// No es lo mismo que el viaje esté DESPACHADO: eso lo pone el despachador al
  /// liberar el andén, y el camión puede quedarse un rato más en el patio.
  final String salidaEn;

  /// `dd/MM/yyyy HH:mm`. Vacío mientras el camión no haya vuelto a planta.
  ///
  /// Lo pone `POST /retorno`, que es del **viaje** y no del catálogo de eventos:
  /// el regreso no es un motivo de la app —no compite con «Almuerzo» ni con
  /// «Falla mecánica»—, es el fin del recorrido.
  ///
  /// No es lo mismo que el viaje esté FIRMADO: eso lo pone el supervisor y el
  /// camión puede volver antes o después.
  final String retornoEn;

  /// `yyyy-MM-dd HH:mm:ss`. Es la única fecha que la app devuelve al servidor,
  /// en `/sincronizar`.
  final String actualizadoEn;

  const ViajeChofer({
    required this.id,
    this.numero = 0,
    this.fecha = '',
    this.estado = '',
    this.estadoEtiqueta = '',
    this.urgencia = Urgencia.baja,
    this.cliente = '',
    this.destino = '',
    this.placa = '',
    this.transportista = '',
    this.vehiculo = '',
    this.horaLlegadaPlanta = '',
    this.horaEntregaCliente = '',
    this.observaciones = '',
    this.entregas = const [],
    this.totalEntregas = 0,
    this.eventos = const [],
    this.eventosRuta = const [],
    this.totalEventosRuta = 0,
    this.eventoAbiertoId,
    this.eventoAbierto = '',
    this.salidaEn = '',
    this.retornoEn = '',
    this.actualizadoEn = '',
  });

  /// Si hay un evento sin cerrar.
  ///
  /// Manda [eventoAbiertoId], que es lo que el servidor resuelve; si no viniera,
  /// se cae a buscar uno abierto en [eventosRuta] para que la pantalla funcione
  /// igual con las dos formas.
  bool get tieneEventoAbierto => eventoAbiertoId != null || marcaAbierta != null;

  /// La marca abierta dentro de [eventosRuta], o `null`.
  ///
  /// Se prefiere la que coincide con [eventoAbiertoId] —el servidor ya dijo
  /// cuál es— y solo si no está se toma la primera abierta de la lista.
  EventoMarcado? get marcaAbierta {
    for (final e in eventosRuta) {
      if (eventoAbiertoId != null && e.id == eventoAbiertoId) return e;
    }
    for (final e in eventosRuta) {
      if (e.abierto) return e;
    }
    return null;
  }

  /// Nombre del evento abierto, con la marca como respaldo.
  String get nombreEventoAbierto {
    if (eventoAbierto.trim().isNotEmpty) return eventoAbierto.trim();
    return marcaAbierta?.titulo ?? '';
  }

  /// La secuencia de etapas del ERP, en orden — `EstadoViaje` del backend.
  ///
  /// Llega en `estado` con el nombre del enum en mayúsculas. Se guarda acá para
  /// poder responder «¿ya pasó por tal etapa?», que es distinto de «¿está en tal
  /// etapa?»: cuando el viaje va por DESPACHADO, la entrega se generó hace rato
  /// y el estado actual ya no lo dice.
  ///
  /// `CANCELADO` queda fuera a propósito: no es un punto de la secuencia.
  static const List<String> secuenciaEtapas = [
    'PENDIENTE',
    'GENERADA',
    'PREPARANDO',
    'VERIFICANDO',
    'PREP_FIN',
    'ASIGNACION_CHOFER',
    'EN_DESPACHO',
    'DESPACHADO',
    // El único que llena el chofer: lo pone `POST /retorno` desde el teléfono.
    'RETORNADO',
    'FIRMADO',
  ];

  /// Código de la etapa en la que el ERP da por generada la entrega al cliente.
  static const String etapaEntregaGenerada = 'GENERADA';

  /// Si la entrega al cliente ya se generó en el ERP. `null` si no se sabe.
  ///
  /// Se responde con dos fuentes, en este orden:
  ///
  ///  1. **La línea de tiempo**, que es un hecho registrado con su hora: si hay
  ///     un paso `GENERADA`, la entrega se generó y punto.
  ///  2. **La etapa actual**, por posición en [secuenciaEtapas]: un viaje en
  ///     DESPACHADO ya pasó por GENERADA aunque la línea de tiempo no haya
  ///     bajado con el viaje.
  ///
  /// Devuelve `null` —y no `false`— cuando la etapa no está en la secuencia
  /// (CANCELADO, o una nueva que agregue el ERP) y tampoco hay línea de tiempo:
  /// decir «sin generar» sin saberlo sería peor que no decir nada.
  bool? get entregaGenerada {
    if (pasoEntregaGenerada != null) return true;

    final actual = secuenciaEtapas.indexOf(estado.trim().toUpperCase());
    if (actual < 0) return null;

    return actual >= secuenciaEtapas.indexOf(etapaEntregaGenerada);
  }

  /// El paso de la línea de tiempo en que se generó la entrega, si consta.
  EventoBodega? get pasoEntregaGenerada {
    for (final e in eventos) {
      if (e.estado.trim().toUpperCase() == etapaEntregaGenerada) return e;
    }
    return null;
  }

  /// Cuándo se generó la entrega, en `dd/MM/yyyy HH:mm`. Vacío si no consta la
  /// hora — se sabe que pasó, pero no cuándo.
  String get entregaGeneradaEn => pasoEntregaGenerada?.ocurridoEn.trim() ?? '';

  /// Si el chofer ya marcó la salida de planta.
  bool get salioDePlanta => salidaEn.trim().isNotEmpty;

  /// Si el camión ya volvió a planta, o sea si el chofer cerró su recorrido.
  ///
  /// Manda la hora, que es el dato; el estado es el respaldo para el caso en que
  /// el servidor mande la etapa sin la hora. Al revés también pasa: si el viaje
  /// ya estaba FIRMADO cuando el chofer marcó, el estado no se movió pero el
  /// regreso sí quedó registrado.
  bool get volvioAPlanta =>
      retornoEn.trim().isNotEmpty ||
      estado.trim().toUpperCase() == 'RETORNADO';

  /// Si el viaje admite marcar eventos.
  ///
  /// El servidor rechaza con «El viaje aun no esta despachado: esta en …»
  /// mientras el camión sigue en el andén. Se comprueba acá para no gastar la
  /// llamada, pero **el servidor sigue siendo la autoridad**: si mandara una
  /// etapa nueva que sí permite marcar, se deja pasar y que él decida.
  bool get despachado {
    final e = estado.trim().toUpperCase();
    if (e.isEmpty) return true;
    // La misma lista que `EstadoViaje.EN_RUTA` del servidor. RETORNADO entra: el
    // chofer puede marcar algo que pasó al llegar, y el servidor se lo acepta.
    return e == 'DESPACHADO' || e == 'RETORNADO' || e == 'FIRMADO';
  }

  /// Por qué no se puede marcar un evento ahora, o `null` si sí se puede.
  ///
  /// Se adelanta a la validación del servidor para no gastar una llamada y
  /// volver con el mismo mensaje.
  ///
  /// [salidaEnCola] y [retornoEnCola] son lo que la app guardó sin señal y el
  /// servidor todavía no sabe. Cuentan igual: el chofer salió de verdad, y
  /// hacerle esperar cobertura para poder marcar lo dejaría sin registrar lo que
  /// pasa en la vía, que es justo donde no hay red.
  String? problemaParaMarcar({
    bool salidaEnCola = false,
    bool retornoEnCola = false,
  }) {
    if (!despachado) {
      return 'El viaje todavía no está despachado: está en $etapa.';
    }

    // El regreso cierra el recorrido: lo que se marque después ensucia los
    // tiempos de una ruta que ya está contada. Cerrar lo que quedó abierto sí se
    // puede — eso no es agregar.
    if (volvioAPlanta || retornoEnCola) {
      final cuando = retornoEn.trim();
      return cuando.isEmpty
          ? 'Este viaje ya terminó: marcaste el regreso a planta.'
          : 'Este viaje ya terminó: regresaste a planta $cuando.';
    }

    // La salida es el primer gesto del viaje. Un evento con el camión en el
    // patio descuadra los tiempos de despacho, y un regreso sin salida da una
    // ruta de duración negativa.
    if (!salioDePlanta && !salidaEnCola) {
      return 'Primero marca la salida de planta.';
    }

    return null;
  }

  /// Por qué no se puede cerrar el viaje todavía, o `null` si sí se puede.
  ///
  /// Lo mismo que [problemaParaMarcar] más los clientes: no se vuelve a planta
  /// con entregas sin confirmar. Un viaje cerrado con un cliente en pendiente
  /// deja sin saber si se le fue a ver siquiera, y eso ya no se reconstruye.
  ///
  /// El botón igual se dibuja, apagado y con este texto debajo: esconderlo
  /// dejaría al chofer sin saber qué le falta para terminar.
  String? problemaParaFinalizar({
    bool salidaEnCola = false,
    bool retornoEnCola = false,
  }) {
    final base = problemaParaMarcar(
      salidaEnCola: salidaEnCola,
      retornoEnCola: retornoEnCola,
    );
    if (base != null) return base;

    final faltan = entregasAbiertas.length;
    if (faltan == 0) return null;

    return faltan == 1
        ? 'Falta confirmar 1 cliente antes de marcar el regreso a planta.'
        : 'Faltan confirmar $faltan clientes antes de marcar el regreso a '
            'planta.';
  }

  /// Las entregas que todavía se pueden atender, en el orden del servidor.
  List<Entrega> get entregasAbiertas =>
      entregas.where((e) => !e.cerrada).toList();

  int get entregasCerradas => entregas.where((e) => e.cerrada).length;

  /// Si todos los clientes están confirmados: entregados o no entregados con su
  /// motivo.
  ///
  /// Un viaje **sin entregas cargadas** cuenta como completo: significa que el
  /// ERP no se las mandó, no que el chofer no hizo su trabajo, y bloquearlo lo
  /// dejaría sin manera de terminar el viaje.
  bool get entregasCompletas => entregasAbiertas.isEmpty;

  /// Las marcas ya cerradas, para el historial de la tarjeta.
  List<EventoMarcado> get eventosCerrados =>
      eventosRuta.where((e) => !e.abierto).toList();

  /// Etapa en palabras, con el código como respaldo para que una etapa nueva no
  /// aparezca como un hueco.
  String get etapa =>
      estadoEtiqueta.trim().isNotEmpty ? estadoEtiqueta.trim() : estado.trim();

  /// La etapa que se le muestra al chofer. Vacía cuando no le dice nada.
  ///
  /// **FIRMADO se omite.** Es el papel que cierra el supervisor: puede firmarse
  /// antes o después de que el camión vuelva, no cambia nada de lo que el chofer
  /// puede hacer, y en su pantalla solo compite con lo que sí importa.
  String get etapaVisible =>
      estado.trim().toUpperCase() == 'FIRMADO' ? '' : etapa;

  /// Cliente y destino en una línea, omitiendo lo vacío y sin repetirse cuando
  /// el ERP manda el mismo texto en los dos campos.
  String get resumenDestino {
    final c = cliente.trim();
    final d = destino.trim();
    if (c.isEmpty) return d;
    if (d.isEmpty || d.toLowerCase() == c.toLowerCase()) return c;
    return '$c · $d';
  }

  factory ViajeChofer.fromJson(Map<String, dynamic> json) => ViajeChofer(
        id: _aInt(json['id']),
        numero: _aInt(json['numero']),
        fecha: _aTexto(json['fecha']).trim(),
        estado: _aTexto(json['estado']).trim(),
        estadoEtiqueta: _aTexto(json['estadoEtiqueta']).trim(),
        urgencia: Urgencia.desdeCodigo(json['urgencia']?.toString()),
        cliente: _aTexto(json['cliente']).trim(),
        destino: _aTexto(json['destino']).trim(),
        placa: _aTexto(json['placa']).trim(),
        transportista: _aTexto(json['transportista']).trim(),
        vehiculo: _aTexto(json['vehiculo']).trim(),
        horaLlegadaPlanta: _aTexto(json['horaLlegadaPlanta']).trim(),
        horaEntregaCliente: _aTexto(json['horaEntregaCliente']).trim(),
        observaciones: _aTexto(json['observaciones']).trim(),
        entregas: _lista(json['entregas'], Entrega.fromJson),
        totalEntregas: _aInt(json['totalEntregas']),
        eventos: _lista(json['eventos'], EventoBodega.fromJson),
        eventosRuta: _lista(json['eventosRuta'], EventoMarcado.fromJson),
        totalEventosRuta: _aInt(json['totalEventosRuta']),
        eventoAbiertoId: _aIntNulo(json['eventoAbiertoId']),
        eventoAbierto: _aTexto(json['eventoAbierto']).trim(),
        salidaEn: _aTexto(json['salidaEn']).trim(),
        retornoEn: _aTexto(json['retornoEn']).trim(),
        actualizadoEn: _aTexto(json['actualizadoEn']).trim(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'numero': numero,
        'fecha': fecha,
        'estado': estado,
        'estadoEtiqueta': estadoEtiqueta,
        'urgencia': urgencia.codigo,
        'cliente': cliente,
        'destino': destino,
        'placa': placa,
        'transportista': transportista,
        'vehiculo': vehiculo,
        'horaLlegadaPlanta': horaLlegadaPlanta,
        'horaEntregaCliente': horaEntregaCliente,
        'observaciones': observaciones,
        'entregas': entregas.map((e) => e.toJson()).toList(),
        'totalEntregas': totalEntregas,
        'eventos': eventos.map((e) => e.toJson()).toList(),
        'eventosRuta': eventosRuta.map((e) => e.toJson()).toList(),
        'totalEventosRuta': totalEventosRuta,
        'eventoAbiertoId': eventoAbiertoId,
        'eventoAbierto': eventoAbierto,
        'salidaEn': salidaEn,
        'retornoEn': retornoEn,
        'actualizadoEn': actualizadoEn,
      };

  @override
  String toString() =>
      'ViajeChofer($id, nº$numero $fecha, $estado, '
      '$totalEntregas entregas, ${eventosRuta.length} eventos'
      '${tieneEventoAbierto ? ", uno abierto" : ""})';
}

/// `null` y las llaves ausentes dan lista vacía, no excepción: el WS omite
/// campos y una lista nula reventaría al pintar.
List<T> _lista<T>(dynamic crudo, T Function(Map<String, dynamic>) desde) {
  if (crudo is! List) return const [];
  return crudo
      .whereType<Map>()
      .map((e) => desde(e.cast<String, dynamic>()))
      .toList();
}

int _aInt(dynamic v) =>
    v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

String _aTexto(dynamic v) => v?.toString() ?? '';

/// `null` cuando la llave no viene o no es un número, para poder distinguir
/// «no hay evento abierto» de «el evento abierto es el 0».
int? _aIntNulo(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  final texto = v.toString().trim();
  if (texto.isEmpty || texto.toLowerCase() == 'null') return null;
  return int.tryParse(texto);
}
