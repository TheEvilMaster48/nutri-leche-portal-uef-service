import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/entrega.dart';
import '../models/evento_bodega.dart';
import '../models/marca_ruta.dart';
import '../models/pagina_sincronizacion.dart';
import '../models/viaje_chofer.dart';
import 'marca_store.dart';
import 'ubicacion_service.dart';
import 'wms_api.dart';

/// Los viajes del chofer: los vigentes, el histórico y el detalle de uno.
///
/// Habla con el REST `wms/api/v1`. No hay login propio: se le manda el
/// `usuario_id`, que es el `Usuario.id` del portal — el servidor resuelve la
/// ficha del chofer por `wms_chofer.usuario_id`.
///
/// Los viajes vigentes se cachean en disco por usuario. Un chofer que abre la
/// app en el patio, sin señal, tiene que poder ver a dónde le toca ir: es lo
/// primero que necesita y lo último que debería depender de la cobertura.
class ViajeChoferService extends ChangeNotifier {
  static String _claveCache(int idUsuario) => 'wms_viajes_$idUsuario';
  static String _claveCacheFecha(int idUsuario) =>
      'wms_viajes_fecha_$idUsuario';
  static String _claveMarca(int idUsuario) => 'wms_sync_marca_$idUsuario';

  /// Tope de páginas por sincronización.
  ///
  /// El servidor pagina de 200 en 200, así que esto son 2.000 viajes cambiados
  /// para un solo chofer: si se llegara acá, algo anda mal del otro lado. Está
  /// para que un `hayMas` que nunca baje no deje la app girando sin fin.
  static const int _maxPaginas = 10;

  final List<ViajeChofer> _viajes = [];

  /// Los viajes vigentes: hoy y los dos días anteriores, como los devuelve
  /// `/mis_viajes`. Ese margen es del servidor y es deliberado — un viaje
  /// asignado ayer que salió de madrugada sigue siendo el viaje del chofer.
  List<ViajeChofer> get viajes => List.unmodifiable(_viajes);

  bool _cargando = false;
  bool get cargando => _cargando;

  String? _error;
  String? get error => _error;

  DateTime? _sincronizado;
  DateTime? get sincronizado => _sincronizado;

  bool get vacio => _viajes.isEmpty;

  /// Los viajes que la pantalla muestra: los que el chofer todavía tiene entre
  /// manos.
  ///
  /// **El viaje finalizado desaparece.** Una vez marcado el regreso a planta no
  /// hay nada que hacerle —el servidor no acepta más eventos— y dejarlo en la
  /// lista solo empuja hacia abajo lo que sí falta.
  ///
  /// Con **una excepción: si le quedó un evento abierto, se queda visible.** Es
  /// lo único que todavía se puede hacer, y esconderlo dejaría ese evento
  /// contando minutos para siempre sin manera de cerrarlo.
  ///
  /// El regreso encolado cuenta como finalizado: si no, el viaje reaparecería
  /// hasta que hubiera señal.
  List<ViajeChofer> get visibles =>
      _viajes.where((v) => !_finalizado(v) || v.tieneEventoAbierto).toList();

  /// Si el chofer ya cerró su recorrido, esté o no confirmado por el servidor.
  bool _finalizado(ViajeChofer v) => v.volvioAPlanta || retornoPendiente(v.id);

  /// Si no queda nada que mostrar pero sí hubo viajes: se terminó el día.
  bool get todoFinalizado => _viajes.isNotEmpty && visibles.isEmpty;

  final List<MarcaRuta> _pendientesEnvio = [];

  /// Marcas de evento que todavía no llegaron al servidor.
  List<MarcaRuta> get pendientesEnvio => List.unmodifiable(_pendientesEnvio);

  int get cuantasPendientesEnvio => _pendientesEnvio.length;

  /// Los que tienen un evento sin cerrar. Es lo que el chofer tiene que
  /// atender ahora: mientras no llegue el cierre, el ERP lo muestra «en eso» y
  /// va contando los minutos.
  ///
  /// Ya no se cuentan entregas por cerrar: con el contrato de eventos por viaje,
  /// la entrega solo dice a quién va el producto y el chofer no la marca.
  List<ViajeChofer> get conEventoAbierto =>
      _viajes.where((v) => v.tieneEventoAbierto).toList();

  /// Los que el chofer ya cerró. No se muestran, pero siguen en la caché: el
  /// delta de `/sincronizar` los actualiza y el histórico los necesita.
  List<ViajeChofer> get finalizados => _viajes.where(_finalizado).toList();

  ViajeChofer? porId(int id) {
    for (final v in _viajes) {
      if (v.id == id) return v;
    }
    return null;
  }

  /// Muestra la caché, drena lo que quedó pendiente y refresca.
  ///
  /// El drenaje va **antes** de recargar: si quedaron marcas de la ruta de ayer
  /// sin enviar, mandarlas primero hace que los viajes lleguen ya con esos
  /// eventos aplicados, en vez de pintar un estado viejo y corregirlo un segundo
  /// después.
  Future<void> iniciar(int idUsuario) async {
    await cargarCache(idUsuario);
    await cargarPendientesEnvio(idUsuario);
    if (_pendientesEnvio.isNotEmpty) await drenar(idUsuario);
    await cargarViajes(idUsuario);
  }

  /// `POST /mis_viajes` — la pantalla principal.
  ///
  /// Si falla, **no vacía** lo que ya había: unos viajes de hace una hora sirven
  /// para trabajar, una lista vacía no. El error se expone aparte para que la
  /// pantalla pueda avisar que lo mostrado puede estar viejo.
  Future<bool> cargarViajes(int idUsuario) async {
    if (idUsuario <= 0) {
      _error = 'No hay una sesión válida.';
      notifyListeners();
      return false;
    }

    _cargando = true;
    _error = null;
    notifyListeners();

    final respuesta = await WmsApi.post('mis_viajes', {
      'usuario_id': idUsuario,
    });

    _cargando = false;

    if (!respuesta.ok) {
      _error = respuesta.error;
      debugPrint('VIAJES: no se pudieron cargar → ${respuesta.error}');
      notifyListeners();
      return false;
    }

    // Qué campos manda de verdad el servidor. Mientras el contrato de los
    // incidentes y del retorno no esté publicado, esto es lo único que dice si
    // llegan `salidaEn`, `retornoEn`, `accionesDisponibles` o los incidentes —y
    // de eso depende qué botones se ofrecen.
    if (respuesta.lista.isNotEmpty) {
      debugPrint(
        'VIAJES: llaves del WS = ${respuesta.lista.first.keys.toList()}',
      );
      debugPrint(
        'VIAJES: salidaEn=${respuesta.lista.first['salidaEn']} '
        'retornoEn=${respuesta.lista.first['retornoEn']} '
        'siguienteAccion=${respuesta.lista.first['siguienteAccion']} '
        'accionesDisponibles=${respuesta.lista.first['accionesDisponibles']}',
      );
    }

    // Una lista vacía sí se respeta: acá significa de verdad que el chofer no
    // tiene viajes vigentes, y dejarle los de ayer en pantalla sería peor.
    _viajes
      ..clear()
      ..addAll(respuesta.lista.map(ViajeChofer.fromJson));
    _ordenar();
    _sincronizado = DateTime.now();

    debugPrint('VIAJES: ${_viajes.length} vigentes para usuario $idUsuario');
    notifyListeners();

    await _guardarCache(idUsuario);
    return true;
  }

  /// `POST /viaje_detalle` — un viaje con sus entregas y eventos.
  ///
  /// Devuelve un objeto, no una lista. Si el viaje no es de ese chofer el
  /// servidor responde lo mismo que si no existiera, a propósito.
  ///
  /// El resultado se mezcla en la lista para que la pantalla anterior quede al
  /// día sin otra llamada.
  Future<ViajeChofer?> cargarDetalle(int idUsuario, int viajeId) async {
    final respuesta = await WmsApi.post('viaje_detalle', {
      'usuario_id': idUsuario,
      'viaje_id': viajeId,
    });

    if (!respuesta.ok) {
      _error = respuesta.error;
      notifyListeners();
      return null;
    }

    final mapa = respuesta.mapa;
    if (mapa == null) {
      _error = 'El servidor no devolvió el viaje.';
      notifyListeners();
      return null;
    }

    final viaje = ViajeChofer.fromJson(mapa);
    reemplazar(viaje);
    return viaje;
  }

  /// `POST /viaje_eventos` — solo la línea de tiempo de bodega.
  ///
  /// Existe para refrescar mientras el chofer tiene el viaje abierto: es la
  /// parte que cambia mientras bodega avanza, y no hace falta volver a bajar el
  /// viaje entero para verla.
  Future<List<EventoBodega>?> cargarEventos(int idUsuario, int viajeId) async {
    final respuesta = await WmsApi.post('viaje_eventos', {
      'usuario_id': idUsuario,
      'viaje_id': viajeId,
    });

    if (!respuesta.ok) {
      _error = respuesta.error;
      notifyListeners();
      return null;
    }

    return respuesta.lista.map(EventoBodega.fromJson).toList();
  }

  /// `POST /mis_viajes_historico`. No toca [viajes]: es otra pantalla.
  Future<List<ViajeChofer>?> cargarHistorico(
    int idUsuario, {
    int limite = 50,
  }) async {
    final respuesta = await WmsApi.post('mis_viajes_historico', {
      'usuario_id': idUsuario,
      'limite': limite,
    });

    if (!respuesta.ok) {
      _error = respuesta.error;
      notifyListeners();
      return null;
    }

    return respuesta.lista.map(ViajeChofer.fromJson).toList();
  }

  // ---------------------------------------------------------------------------
  // Sincronización incremental
  // ---------------------------------------------------------------------------

  /// `POST /sincronizar` — baja solo lo que cambió desde la última marca.
  ///
  /// Sirve para refrescar barato: en lugar de volver a bajar todos los viajes,
  /// pide el delta. Sigue las tres reglas del protocolo:
  ///
  /// * La primera vez se llama **sin** `desde` y baja todo.
  /// * Si `hayMas` viene en true, se vuelve a llamar con la marca nueva. Darlo
  ///   por terminado ahí deja viajes sin bajar.
  /// * La marca que devuelve se guarda tal cual. Cuando no hay cambios vuelve la
  ///   misma que se mandó, y eso está bien: adelantarla por cuenta propia haría
  ///   que la app se saltara para siempre lo que se modifique en esa rendija.
  ///
  /// **No define qué se muestra.** `/sincronizar` no tiene tope de fecha, así que
  /// puede traer viajes más viejos que la ventana de `/mis_viajes` — y no manda
  /// avisos de borrado. Por eso acá solo se **actualizan** los viajes que ya
  /// están en la lista, y si aparecen cambios de viajes desconocidos se avisa
  /// con [ResultadoSincronizacion.hayDesconocidos] para que quien llame decida
  /// hacer una recarga completa: es la señal de una asignación nueva.
  Future<ResultadoSincronizacion> sincronizar(
    int idUsuario, {
    int limite = 200,
  }) async {
    if (idUsuario <= 0) {
      return const ResultadoSincronizacion(
        actualizados: 0,
        error: 'No hay una sesión válida.',
      );
    }

    var marca = await _leerMarca(idUsuario);
    var actualizados = 0;
    var desconocidos = 0;
    var paginas = 0;

    while (paginas < _maxPaginas) {
      paginas++;

      final respuesta = await WmsApi.post('sincronizar', {
        'usuario_id': idUsuario,
        // La primera vez no se manda `desde`: así el servidor baja todo.
        if (marca != null && marca.isNotEmpty) 'desde': marca,
        'limite': limite,
      });

      if (!respuesta.ok) {
        _error = respuesta.error;
        notifyListeners();
        return ResultadoSincronizacion(
          actualizados: actualizados,
          desconocidos: desconocidos,
          error: respuesta.error,
        );
      }

      final mapa = respuesta.mapa;
      if (mapa == null) {
        return ResultadoSincronizacion(
          actualizados: actualizados,
          desconocidos: desconocidos,
          error: 'El servidor no devolvió los cambios.',
        );
      }

      final pagina = PaginaSincronizacion.fromJson(mapa);
      debugPrint('SYNC: $pagina');

      for (final viaje in pagina.viajes) {
        final indice = _viajes.indexWhere((v) => v.id == viaje.id);
        if (indice == -1) {
          // Un viaje que no estaba: puede ser una asignación nueva o uno
          // anterior a la ventana de /mis_viajes. No se decide acá.
          desconocidos++;
          continue;
        }
        _viajes[indice] = viaje;
        actualizados++;
      }

      if (pagina.viajes.isNotEmpty) {
        _ordenar();
        notifyListeners();
        await _guardarCache(idUsuario);
      }

      final marcaAnterior = marca;
      if (pagina.marca.isNotEmpty) {
        marca = pagina.marca;
        await _guardarMarca(idUsuario, pagina.marca);
      }

      if (!pagina.hayMas) break;

      // Salvaguarda: si el servidor insiste en que hay más pero no avanza la
      // marca, seguir sería pedir la misma página para siempre.
      if (pagina.marca.isEmpty || pagina.marca == marcaAnterior) {
        debugPrint('SYNC: hayMas sin avanzar la marca; se corta');
        break;
      }
    }

    _sincronizado = DateTime.now();
    notifyListeners();

    return ResultadoSincronizacion(
      actualizados: actualizados,
      desconocidos: desconocidos,
      paginas: paginas,
    );
  }

  /// Refresco barato: drena la cola, pide el delta y solo si aparecen cambios
  /// de viajes desconocidos hace la recarga completa.
  ///
  /// Es lo que conviene al volver la app a primer plano, donde bajar todo cada
  /// vez es gasto de datos del chofer.
  Future<void> refrescarLigero(int idUsuario) async {
    if (_pendientesEnvio.isNotEmpty) await drenar(idUsuario);

    final resultado = await sincronizar(idUsuario);

    // Una asignación nueva no se puede resolver con el delta: /sincronizar no
    // dice cuáles son los vigentes, solo qué cambió.
    if (resultado.hayDesconocidos || resultado.error != null) {
      await cargarViajes(idUsuario);
    }
  }

  Future<String?> _leerMarca(int idUsuario) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_claveMarca(idUsuario));
    } catch (e) {
      debugPrint('⚠️ No se pudo leer la marca de sincronización: $e');
      return null;
    }
  }

  Future<void> _guardarMarca(int idUsuario, String marca) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_claveMarca(idUsuario), marca);
    } catch (e) {
      debugPrint('⚠️ No se pudo guardar la marca de sincronización: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Marcado de eventos
  // ---------------------------------------------------------------------------

  /// Abre un evento del catálogo: lo intenta enviar y, si no hay señal, lo deja
  /// en cola.
  ///
  /// [conUbicacion] pide la posición antes de marcar. Es opcional en el
  /// contrato y acá también: si el GPS no fija, la marca se hace igual sin
  /// coordenadas. Bloquear un evento porque el teléfono no encontró satélites
  /// dejaría al chofer sin poder registrar lo que está pasando.
  ///
  /// [nombre] no viaja al servidor: es solo para el aviso en pantalla mientras
  /// la marca espera en la cola.
  Future<ResultadoMarca> marcarEvento(
    int idUsuario, {
    required int viajeId,
    required int eventoId,
    String nombre = '',
    bool conUbicacion = true,
  }) async {
    if (idUsuario <= 0) {
      return const ResultadoMarca.rechazada('No hay una sesión válida.');
    }

    final ubicacion = await _ubicacionSiSePuede(conUbicacion);

    final marca = MarcaRuta.abrir(
      id: await MarcaStore.siguienteId(idUsuario),
      viajeId: viajeId,
      eventoId: eventoId,
      nombre: nombre,
      // La hora es de ahora, no de cuando se logre enviar. Es el punto de todo
      // el mecanismo de cola, y el único dato que el servidor no puede
      // reconstruir.
      ocurridoEn: MarcaRuta.ahora(),
      latitud: ubicacion?.latitude,
      longitud: ubicacion?.longitude,
    );

    return _encolarOEnviar(idUsuario, marca);
  }

  /// Cierra un evento abierto: `POST /cerrar_evento`.
  ///
  /// Es el único sitio donde se guardan la hora y la ubicación de fin. Mientras
  /// no llegue, el ERP muestra ese camión como «sigue en eso» y va contando los
  /// minutos.
  ///
  /// [registroId] es el `eventoAbiertoId` del viaje —el id de **la marca**, no
  /// el del catálogo—. Puede ir en `null`: entonces el servidor cierra el único
  /// evento abierto del viaje, que es la salida para un teléfono que perdió el
  /// id al reinstalarse. Con dos abiertos responde pidiendo que se indique cuál.
  ///
  /// Sigue exactamente el mismo camino que [marcarEvento]: se toma la ubicación,
  /// se sella con la hora del teléfono y, si no hay señal, se guarda en la cola.
  /// Cerrar pasa en la vía tanto como abrir, así que no puede depender de tener
  /// cobertura en ese momento.
  Future<ResultadoMarca> cerrarEvento(
    int idUsuario, {
    required int viajeId,
    int? registroId,
    String nombre = '',
    bool conUbicacion = true,
  }) async {
    if (idUsuario <= 0) {
      return const ResultadoMarca.rechazada('No hay una sesión válida.');
    }

    final ubicacion = await _ubicacionSiSePuede(conUbicacion);

    final cierre = MarcaRuta.cerrar(
      id: await MarcaStore.siguienteId(idUsuario),
      viajeId: viajeId,
      registroId: registroId,
      nombre: nombre,
      ocurridoEn: MarcaRuta.ahora(),
      latitud: ubicacion?.latitude,
      longitud: ubicacion?.longitude,
    );

    return _encolarOEnviar(idUsuario, cierre);
  }

  /// Si hay una salida de planta esperando señal para este viaje.
  ///
  /// Vale lo mismo que la del servidor para decidir qué ofrecer: el chofer salió
  /// de verdad, y hacerle esperar cobertura para poder marcar un evento sería
  /// dejarlo sin registrar lo que pasa en la vía, que es justo donde no hay red.
  bool salidaPendiente(int viajeId) =>
      _pendientesEnvio.any((m) => m.esSalida && m.viajeId == viajeId);

  /// Si hay un regreso a planta esperando señal para este viaje.
  ///
  /// El viaje que llega del servidor no lo sabe todavía —su `retornoEn` viaja en
  /// la respuesta que aún no se pudo pedir—, así que sin esto la pantalla
  /// seguiría ofreciendo marcar eventos que el servidor va a rechazar cuando la
  /// cola drene. En ruta eso es media hora después y con el trabajo ya hecho.
  bool retornoPendiente(int viajeId) =>
      _pendientesEnvio.any((m) => m.esRetorno && m.viajeId == viajeId);

  /// Marca lo que pasó con una entrega: `POST /marcar_entrega`.
  ///
  /// Es lo único que se marca por cliente. [motivo] es obligatorio cuando el
  /// hito es no entregado — el servidor lo exige y una marca sin él se quedaría
  /// atascada al frente de la cola.
  ///
  /// Mismo camino que el resto: hora del teléfono, ubicación y cola sin señal.
  /// La puerta del cliente es justo donde peor anda la cobertura.
  Future<ResultadoMarca> marcarEntrega(
    int idUsuario, {
    required int viajeId,
    required int entregaId,
    required EstadoRutaEntrega hito,
    String motivo = '',
    String cliente = '',
    bool conUbicacion = true,
  }) async {
    if (idUsuario <= 0) {
      return const ResultadoMarca.rechazada('No hay una sesión válida.');
    }

    final ubicacion = await _ubicacionSiSePuede(conUbicacion);

    return _encolarOEnviar(
      idUsuario,
      MarcaRuta.entrega(
        id: await MarcaStore.siguienteId(idUsuario),
        viajeId: viajeId,
        registroId: entregaId,
        hitoEntrega: hito,
        motivo: motivo,
        nombre: cliente,
        ocurridoEn: MarcaRuta.ahora(),
        latitud: ubicacion?.latitude,
        longitud: ubicacion?.longitude,
      ),
    );
  }

  /// Marca la salida de planta: `POST /salida`.
  ///
  /// Es el primer gesto del viaje y el requisito de todo lo demás: sin ella el
  /// servidor responde «Primero marque la salida de planta».
  ///
  /// Mismo camino que el resto: hora del teléfono, ubicación y cola sin señal.
  Future<ResultadoMarca> marcarSalida(
    int idUsuario, {
    required int viajeId,
    bool conUbicacion = true,
  }) async {
    if (idUsuario <= 0) {
      return const ResultadoMarca.rechazada('No hay una sesión válida.');
    }

    final ubicacion = await _ubicacionSiSePuede(conUbicacion);

    return _encolarOEnviar(
      idUsuario,
      MarcaRuta.salida(
        id: await MarcaStore.siguienteId(idUsuario),
        viajeId: viajeId,
        ocurridoEn: MarcaRuta.ahora(),
        latitud: ubicacion?.latitude,
        longitud: ubicacion?.longitude,
      ),
    );
  }

  /// Marca el regreso a planta: `POST /retorno`.
  ///
  /// Cierra el recorrido del chofer. No es un evento del catálogo —el regreso no
  /// compite con «Almuerzo»— y tampoco cambia el estado del viaje: el FIRMADO lo
  /// pone el supervisor y el camión puede volver antes o después.
  ///
  /// Mismo camino que [marcarEvento]: hora del teléfono, ubicación y cola sin
  /// señal. La vuelta a planta es justo donde peor anda la cobertura.
  Future<ResultadoMarca> marcarRetorno(
    int idUsuario, {
    required int viajeId,
    bool conUbicacion = true,
  }) async {
    if (idUsuario <= 0) {
      return const ResultadoMarca.rechazada('No hay una sesión válida.');
    }

    final ubicacion = await _ubicacionSiSePuede(conUbicacion);

    return _encolarOEnviar(
      idUsuario,
      MarcaRuta.retorno(
        id: await MarcaStore.siguienteId(idUsuario),
        viajeId: viajeId,
        ocurridoEn: MarcaRuta.ahora(),
        latitud: ubicacion?.latitude,
        longitud: ubicacion?.longitude,
      ),
    );
  }

  /// Valida, y manda o encola. Es igual para abrir y para cerrar.
  Future<ResultadoMarca> _encolarOEnviar(int idUsuario, MarcaRuta marca) async {
    // Se valida antes de encolar: una marca a la que el servidor le va a
    // encontrar un dato faltante quedaría atascada al frente de la cola.
    final problema = marca.problema;
    if (problema != null) {
      return ResultadoMarca.rechazada(problema);
    }

    // Si ya hay cola, esta va detrás sin intentar adelantarse: un cierre no
    // puede llegar antes que la apertura del evento que cierra.
    if (_pendientesEnvio.isNotEmpty) {
      await _encolar(idUsuario, marca);
      return ResultadoMarca.encolada(
        '${marca.etiquetaAccion} guardado. Se enviará cuando haya señal.',
        pendientes: _pendientesEnvio.length,
      );
    }

    return _enviar(idUsuario, marca, encolarSiFalla: true);
  }

  /// La posición de ahora, o `null` si no se pudo obtener.
  ///
  /// Nunca bloquea: negarse a registrar algo porque el teléfono no fijó
  /// satélites dejaría al chofer parado en la puerta del cliente.
  Future<Position?> _ubicacionSiSePuede(bool conUbicacion) async {
    if (!conUbicacion) return null;

    final ubicacion = await UbicacionService.obtener();
    if (ubicacion.ok) return ubicacion.posicion;

    debugPrint(
      'MARCAS: sin ubicación (${ubicacion.mensaje}); se registra igual',
    );
    return null;
  }

  /// Envía una marca. Con [encolarSiFalla], un fallo de red la deja en cola.
  Future<ResultadoMarca> _enviar(
    int idUsuario,
    MarcaRuta marca, {
    required bool encolarSiFalla,
  }) async {
    final respuesta = await WmsApi.post(
      marca.recurso,
      marca.aPeticion(idUsuario),
    );

    if (respuesta.ok) {
      // Devuelve el viaje entero ya recalculado, justamente para repintar sin
      // una segunda llamada.
      final mapa = respuesta.mapa;
      if (mapa != null) reemplazar(ViajeChofer.fromJson(mapa));

      return ResultadoMarca.enviada(
        respuesta.mensaje.isEmpty
            ? '${marca.etiquetaAccion} registrado.'
            : respuesta.mensaje,
      );
    }

    if (respuesta.reintentable) {
      if (encolarSiFalla) {
        await _encolar(idUsuario, marca);
        return ResultadoMarca.encolada(
          '${marca.etiquetaAccion} guardado. Se enviará cuando haya señal.',
          pendientes: _pendientesEnvio.length,
        );
      }
      // Ya está en la cola (viene del drenaje): se avisa que no hubo red, y
      // sobre todo NO se confunde con un rechazo, que la descartaría.
      return ResultadoMarca.sinRed(respuesta.mensaje);
    }

    // Rechazo por regla: el servidor entendió y dijo que no. Reintentarlo daría
    // la misma respuesta, así que no se encola y el mensaje va tal cual — está
    // redactado para el chofer.
    return ResultadoMarca.rechazada(respuesta.mensaje);
  }

  /// Manda la cola al servidor, en orden y parando en el primer problema.
  ///
  /// Para en el primer fallo de red a propósito: seguir con las de atrás las
  /// haría rechazar por una regla de orden que sí se cumplía, solo porque la
  /// anterior no llegó.
  ///
  /// Reintentar es seguro — el servidor es idempotente y una marca ya
  /// registrada vuelve como correcta con la que ya existe — así que no hace
  /// falta llevar cuenta de qué llegó y qué no.
  Future<ResultadoDrenaje> drenar(int idUsuario) async {
    if (idUsuario <= 0 || _pendientesEnvio.isEmpty) {
      return const ResultadoDrenaje(enviadas: 0, descartadas: 0);
    }

    var enviadas = 0;
    var descartadas = 0;
    String? mensaje;

    // Copia: la lista viva se modifica dentro del bucle.
    for (final marca in [..._pendientesEnvio]) {
      final resultado = await _enviar(idUsuario, marca, encolarSiFalla: false);

      if (resultado.estado == EstadoMarca.enviada) {
        await _quitarDeCola(idUsuario, marca.id);
        enviadas++;
        continue;
      }

      if (resultado.estado == EstadoMarca.rechazada) {
        // No sirve guardarla: el servidor va a decir lo mismo siempre. Se saca
        // de la cola para no bloquear el resto, pero se corta el drenaje y se
        // devuelve el mensaje: el chofer tiene que enterarse, no descubrirlo
        // por una entrega que quedó sin marcar.
        await _quitarDeCola(idUsuario, marca.id);
        descartadas++;
        mensaje = resultado.mensaje;
        break;
      }

      // Sin red: la marca **se queda**. Se le anota el intento y se corta, para
      // no rechazar las de atrás por un orden que sí se cumplía.
      await _anotarIntento(idUsuario, marca, resultado.mensaje);
      mensaje = resultado.mensaje;
      break;
    }

    debugPrint(
      'MARCAS: drenaje → $enviadas enviadas, $descartadas descartadas, '
      '${_pendientesEnvio.length} en cola',
    );

    return ResultadoDrenaje(
      enviadas: enviadas,
      descartadas: descartadas,
      mensaje: mensaje,
      quedan: _pendientesEnvio.length,
    );
  }

  Future<void> cargarPendientesEnvio(int idUsuario) async {
    _pendientesEnvio
      ..clear()
      ..addAll(await MarcaStore.leer(idUsuario));
    if (_pendientesEnvio.isNotEmpty) {
      debugPrint('MARCAS: ${_pendientesEnvio.length} pendientes de envío');
    }
    notifyListeners();
  }

  Future<void> _encolar(int idUsuario, MarcaRuta marca) async {
    _pendientesEnvio
      ..clear()
      ..addAll(await MarcaStore.encolar(idUsuario, marca));
    notifyListeners();
  }

  Future<void> _quitarDeCola(int idUsuario, int idMarca) async {
    _pendientesEnvio
      ..clear()
      ..addAll(await MarcaStore.quitar(idUsuario, idMarca));
    notifyListeners();
  }

  Future<void> _anotarIntento(
    int idUsuario,
    MarcaRuta marca,
    String error,
  ) async {
    _pendientesEnvio
      ..clear()
      ..addAll(
        await MarcaStore.actualizar(
          idUsuario,
          marca.copyWith(intentos: marca.intentos + 1, ultimoError: error),
        ),
      );
    notifyListeners();
  }

  /// Mete o actualiza un viaje en la lista.
  ///
  /// Lo usa el detalle y el marcado de eventos, que devuelve el viaje
  /// entero ya recalculado justamente para esto.
  void reemplazar(ViajeChofer viaje) {
    final indice = _viajes.indexWhere((v) => v.id == viaje.id);
    if (indice == -1) {
      _viajes.add(viaje);
    } else {
      _viajes[indice] = viaje;
    }
    _ordenar();
    notifyListeners();
  }

  Future<void> cargarCache(int idUsuario) async {
    if (idUsuario <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      final crudo = prefs.getString(_claveCache(idUsuario));
      if (crudo == null || crudo.isEmpty) return;

      final decodificado = json.decode(crudo);
      if (decodificado is! List) return;

      _viajes
        ..clear()
        ..addAll(
          decodificado.whereType<Map>().map(
            (e) => ViajeChofer.fromJson(e.cast<String, dynamic>()),
          ),
        );
      _ordenar();

      final fecha = prefs.getString(_claveCacheFecha(idUsuario));
      if (fecha != null) _sincronizado = DateTime.tryParse(fecha);

      debugPrint('VIAJES: ${_viajes.length} desde caché');
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ No se pudo leer la caché de viajes: $e');
    }
  }

  Future<void> _guardarCache(int idUsuario) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _claveCache(idUsuario),
        json.encode(_viajes.map((v) => v.toJson()).toList()),
      );
      await prefs.setString(
        _claveCacheFecha(idUsuario),
        (_sincronizado ?? DateTime.now()).toIso8601String(),
      );
    } catch (e) {
      debugPrint('⚠️ No se pudo guardar la caché de viajes: $e');
    }
  }

  /// Al cerrar sesión: los viajes de un chofer no son de quien entre después.
  Future<void> limpiar(int idUsuario) async {
    _viajes.clear();
    _sincronizado = null;
    _error = null;
    notifyListeners();

    _pendientesEnvio.clear();

    if (idUsuario <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_claveCache(idUsuario));
      await prefs.remove(_claveCacheFecha(idUsuario));
      await prefs.remove(_claveMarca(idUsuario));
      await MarcaStore.limpiar(idUsuario);
    } catch (e) {
      debugPrint('⚠️ No se pudo limpiar la caché de viajes: $e');
    }
  }

  /// Lo que hay que atender primero, y dentro de eso el más reciente arriba.
  ///
  /// El viaje con un evento abierto va arriba: es el que tiene el cronómetro
  /// corriendo. El WS no promete un orden y el chofer necesita ver eso sin
  /// buscarlo. `numero` es el número dentro del día, así que ordena bien solo
  /// después de agrupar por fecha — y `actualizadoEn` viene en
  /// `yyyy-MM-dd HH:mm:ss`, que ordena bien como texto.
  void _ordenar() {
    _viajes.sort((a, b) {
      if (a.tieneEventoAbierto != b.tieneEventoAbierto) {
        return a.tieneEventoAbierto ? -1 : 1;
      }
      final porFecha = b.actualizadoEn.compareTo(a.actualizadoEn);
      if (porFecha != 0) return porFecha;
      return b.numero.compareTo(a.numero);
    });
  }
}

/// En qué quedó un intento de marcar.
enum EstadoMarca {
  /// Llegó al servidor y el viaje ya se repintó.
  enviada,

  /// Quedó en cola: no había señal. Se enviará después.
  encolada,

  /// No se pudo hablar con el servidor y **no** se encoló, porque quien llamó
  /// pidió no encolar — es el caso del drenaje, donde la marca ya está en la
  /// cola. Se distingue de [rechazada] porque sí hay que reintentarla: tratarlas
  /// igual descartaría el trabajo del chofer por una caída de red.
  sinRed,

  /// El servidor la negó, o le faltaba un dato. No se reintenta.
  rechazada,
}

/// Resultado de marcar o cerrar un evento, con el texto listo para mostrar.
class ResultadoMarca {
  final EstadoMarca estado;

  /// Qué decirle al chofer. Cuando viene del servidor, va sin retocar.
  final String mensaje;

  /// Cuántas marcas quedaron esperando señal. Solo en [EstadoMarca.encolada].
  final int pendientes;

  const ResultadoMarca.enviada(this.mensaje)
    : estado = EstadoMarca.enviada,
      pendientes = 0;

  const ResultadoMarca.encolada(this.mensaje, {this.pendientes = 0})
    : estado = EstadoMarca.encolada;

  const ResultadoMarca.rechazada(this.mensaje)
    : estado = EstadoMarca.rechazada,
      pendientes = 0;

  const ResultadoMarca.sinRed(this.mensaje)
    : estado = EstadoMarca.sinRed,
      pendientes = 0;

  bool get ok => estado != EstadoMarca.rechazada;
}

/// Resultado de vaciar la cola.
class ResultadoDrenaje {
  const ResultadoDrenaje({
    required this.enviadas,
    required this.descartadas,
    this.mensaje,
    this.quedan = 0,
  });

  final int enviadas;

  /// Marcas que el servidor negó por una regla. No se reintentan.
  final int descartadas;

  /// Lo que hay que contarle al chofer, si algo salió mal.
  final String? mensaje;

  final int quedan;

  bool get todoEnviado => quedan == 0 && descartadas == 0;
}

/// Resultado de una sincronización incremental.
class ResultadoSincronizacion {
  const ResultadoSincronizacion({
    required this.actualizados,
    this.desconocidos = 0,
    this.paginas = 0,
    this.error,
  });

  /// Viajes de la lista que se refrescaron con el delta.
  final int actualizados;

  /// Cambios de viajes que no estaban en la lista.
  ///
  /// Es la señal de que hace falta una recarga completa: puede ser una
  /// asignación nueva, y el delta no dice cuáles son los vigentes.
  final int desconocidos;

  /// Cuántas páginas hubo que pedir. Útil para notar un `hayMas` que no baja.
  final int paginas;

  final String? error;

  bool get ok => error == null;

  bool get hayDesconocidos => desconocidos > 0;

  bool get sinCambios => ok && actualizados == 0 && desconocidos == 0;
}
