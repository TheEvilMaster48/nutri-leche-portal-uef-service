import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/parametro.dart';
import 'conexion.dart';
import 'logo_api.dart';

/// Catálogo de los desplegables de Logo Nutri: `GET /administracion`.
///
/// Una sola llamada trae las cuatro listas (tipo de material, entorno, estado y
/// acción requerida) dentro del objeto `data`. Ver [CatalogoParametros].
///
/// Solo bajan los parámetros **activos** del ERP: inactivar uno lo saca del
/// desplegable, pero los registros históricos conservan el valor que usaron.
///
/// Se cachea en disco por la misma razón que el catálogo de eventos de rutas:
/// la captura se hace en bodega o en planta, donde no hay señal. Sin caché el
/// formulario aparecería con los desplegables vacíos justo cuando hace falta.
/// El catálogo es global —son parámetros de la operación—, así que no se
/// segmenta por usuario.
///
/// **Cuándo se descarga.** Al entrar al menú y cada vez que la app vuelve a
/// primer plano, junto con cumpleaños y notificaciones: así el catálogo ya
/// está en el teléfono antes de salir a campo. Al abrir un registro se vuelve
/// a llamar a [iniciar]: con conexión refresca, sin conexión usa lo guardado
/// sin mostrarlo como error.
class ParametroService extends ChangeNotifier {
  /// Clave nueva respecto de la primera versión del módulo: aquella guardaba
  /// una lista de objetos `{id, tipo, descripcion}` que el WS nunca llegó a
  /// devolver. Leerla ahora daría un catálogo vacío sin explicación.
  static const String _claveCache = 'logo_parametros_v2';
  static const String _claveCacheFecha = 'logo_parametros_v2_fecha';

  CatalogoParametros _catalogo = const CatalogoParametros.vacio();
  CatalogoParametros get catalogo => _catalogo;

  bool _cargando = false;
  bool get cargando => _cargando;

  String? _error;
  String? get error => _error;

  DateTime? _sincronizado;
  DateTime? get sincronizado => _sincronizado;

  /// La última vez que se intentó, el servidor no estaba al alcance. No es un
  /// error: se trabaja con la copia del teléfono.
  bool _sinConexion = false;
  bool get sinConexion => _sinConexion;

  bool _cacheLeida = false;

  /// La sincronización en curso, para que el menú y la pantalla de registro no
  /// disparen dos descargas a la vez.
  Future<bool>? _enCurso;

  bool get vacio => _catalogo.vacio;

  /// Las opciones de un desplegable, en el orden del servidor.
  List<String> opciones(FamiliaParametro familia) =>
      _catalogo.opciones(familia);

  /// Carga lo guardado en el teléfono y, si hay conexión, lo refresca.
  ///
  /// Sin conexión no se intenta la petición: se ahorra el timeout de 30 s y
  /// el formulario queda listo con la copia local.
  Future<void> iniciar() async {
    if (!_cacheLeida) await cargarCache();

    if (!await Conexion.hayConexion()) {
      _sinConexion = true;
      _error = null;
      debugPrint(
        'PARÁMETROS: sin conexión, ${_catalogo.total} desde el teléfono',
      );
      notifyListeners();
      return;
    }

    _sinConexion = false;
    await sincronizar();
  }

  /// Trae el catálogo y lo guarda.
  ///
  /// Si falla, **conserva** lo que ya había: un catálogo viejo permite capturar,
  /// uno vacío no.
  Future<bool> sincronizar() {
    return _enCurso ??= _sincronizar().whenComplete(() => _enCurso = null);
  }

  Future<bool> _sincronizar() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    final respuesta = await LogoApi.get(LogoApi.recursoCatalogo);

    _cargando = false;

    if (!respuesta.ok) {
      _error = respuesta.mensaje;
      debugPrint('PARÁMETROS: no se sincronizó → ${respuesta.mensaje}');
      notifyListeners();
      return false;
    }

    // Un catálogo suelto puede llegar vacío con `correcto: true` —el ERP no
    // tiene parámetros activos de ese tipo— y eso no invalida el resto: la
    // pantalla deja ese desplegable opcional en lugar de bloquear la captura.

    final data = respuesta.mapa;
    if (data == null) {
      _error = 'El servidor devolvió los parámetros en un formato inesperado.';
      debugPrint('PARÁMETROS: data no es un objeto → ${respuesta.datos}');
      notifyListeners();
      return false;
    }

    final catalogo = CatalogoParametros.fromJson(data);

    if (catalogo.vacio) {
      _error = 'El servidor no devolvió opciones.';
      notifyListeners();
      return false;
    }

    _catalogo = catalogo;
    _sincronizado = DateTime.now();
    _sinConexion = false;

    debugPrint(
      'PARÁMETROS: ${catalogo.total} opciones en '
      '${catalogo.porFamilia.length} listas',
    );
    if (catalogo.clavesIgnoradas.isNotEmpty) {
      // No se descarta en silencio: si el WS agrega una lista, conviene verlo.
      debugPrint('PARÁMETROS: claves sin usar → ${catalogo.clavesIgnoradas}');
    }
    notifyListeners();

    await _guardarCache();
    return true;
  }

  Future<void> cargarCache() async {
    _cacheLeida = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(_claveCache);
      if (crudo == null || crudo.isEmpty) return;

      final decodificado = json.decode(crudo);
      if (decodificado is! Map) return;

      final data = decodificado.cast<String, dynamic>();
      _catalogo = CatalogoParametros.fromJson(data);

      final fecha = prefs.getString(_claveCacheFecha);
      if (fecha != null) _sincronizado = DateTime.tryParse(fecha);

      debugPrint('PARÁMETROS: ${_catalogo.total} opciones desde caché');
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ No se pudo leer la caché de parámetros: $e');
    }
  }

  Future<void> _guardarCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_claveCache, json.encode(_catalogo.toJson()));
      await prefs.setString(
        _claveCacheFecha,
        (_sincronizado ?? DateTime.now()).toIso8601String(),
      );
    } catch (e) {
      debugPrint('⚠️ No se pudo guardar la caché de parámetros: $e');
    }
  }

  /// Descarta lo cargado en memoria. Se llama al cerrar sesión.
  void limpiar() {
    _catalogo = const CatalogoParametros.vacio();
    _error = null;
    _sincronizado = null;
    _sinConexion = false;
    // La copia en disco se conserva: el catálogo no es del usuario y le sirve
    // al siguiente que entre sin señal. Se vuelve a leer en el próximo inicio.
    _cacheLeida = false;
    notifyListeners();
  }
}
