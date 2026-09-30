import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/evento_ruta.dart';
import 'wms_api.dart';

/// Catálogo de eventos que el chofer puede marcar: `GET /eventos`.
///
/// Es el catálogo administrable del ERP —Administración WMS → Motivos de la
/// App— y solo devuelve los activos: un evento dado de baja deja de bajar, pero
/// las marcas que ya lo usaron conservan su nombre.
///
/// Se reusa [EventoRuta], el modelo del catálogo del REST viejo, porque es la
/// **misma tabla** (`ctruta_eventos`) servida por otro endpoint: mismos campos
/// `id`, `nombre`, `tiempoestimado`, `evidencia`, `notas` y `observaciones`.
///
/// Se cachea en disco porque el chofer marca eventos justo donde no hay señal:
/// una parada en la vía es el caso de uso, no la excepción. Sin caché, el
/// selector aparecería vacío exactamente cuando más se necesita.
///
/// El catálogo es global, no por usuario: son los eventos de la operación.
class CatalogoEventoService extends ChangeNotifier {
  /// Clave nueva a propósito: la caché anterior guardaba el catálogo de
  /// `tipos_incidente` —códigos de texto y un flag `grave`—, que ya no existe.
  /// Leerla dejaría el selector lleno de eventos que el servidor rechaza.
  static const String _claveCache = 'wms_catalogo_eventos_v2';
  static const String _claveCacheFecha = 'wms_catalogo_eventos_v2_fecha';

  final List<EventoRuta> _eventos = [];
  List<EventoRuta> get eventos => List.unmodifiable(_eventos);

  bool _cargando = false;
  bool get cargando => _cargando;

  String? _error;
  String? get error => _error;

  DateTime? _sincronizado;
  DateTime? get sincronizado => _sincronizado;

  bool get vacio => _eventos.isEmpty;

  EventoRuta? porId(int id) {
    for (final e in _eventos) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Muestra la caché y refresca detrás.
  Future<void> iniciar() async {
    await cargarCache();
    await sincronizar();
  }

  /// Trae el catálogo y lo guarda.
  ///
  /// Si falla, **conserva** lo que ya había: un catálogo viejo sirve para
  /// marcar, uno vacío no. El servidor rechaza un evento dado de baja con un
  /// mensaje que pide actualizar la lista, así que el riesgo de usar una copia
  /// vieja está cubierto del otro lado.
  Future<bool> sincronizar() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    final respuesta = await WmsApi.get('eventos');

    _cargando = false;

    if (!respuesta.ok) {
      _error = respuesta.error;
      debugPrint('EVENTOS: no se pudo sincronizar → ${respuesta.error}');
      notifyListeners();
      return false;
    }

    final lista =
        respuesta.lista
            .map(EventoRuta.fromJson)
            .where((e) => e.id > 0 && e.nombre.isNotEmpty)
            .toList();

    if (lista.isEmpty) {
      _error = 'El servidor no devolvió eventos.';
      notifyListeners();
      return false;
    }

    _eventos
      ..clear()
      ..addAll(lista);
    _ordenar();
    _sincronizado = DateTime.now();

    debugPrint('EVENTOS: ${_eventos.length} sincronizados');
    notifyListeners();

    await _guardarCache();
    return true;
  }

  Future<void> cargarCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(_claveCache);
      if (crudo == null || crudo.isEmpty) return;

      final decodificado = json.decode(crudo);
      if (decodificado is! List) return;

      _eventos
        ..clear()
        ..addAll(
          decodificado.whereType<Map>().map(
            (e) => EventoRuta.fromJson(e.cast<String, dynamic>()),
          ),
        );
      _ordenar();

      final fecha = prefs.getString(_claveCacheFecha);
      if (fecha != null) _sincronizado = DateTime.tryParse(fecha);

      debugPrint('EVENTOS: ${_eventos.length} desde caché');
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ No se pudo leer la caché de eventos: $e');
    }
  }

  Future<void> _guardarCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _claveCache,
        json.encode(_eventos.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(
        _claveCacheFecha,
        (_sincronizado ?? DateTime.now()).toIso8601String(),
      );
    } catch (e) {
      debugPrint('⚠️ No se pudo guardar la caché de eventos: $e');
    }
  }

  /// Por nombre, que es como el chofer los busca en el selector.
  ///
  /// El orden del catálogo es el de creación en el ERP y no le dice nada a
  /// nadie; alfabético al menos es predecible con el camión detenido.
  void _ordenar() {
    _eventos.sort(
      (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
    );
  }
}
