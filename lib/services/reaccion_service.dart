import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../base/base.dart';
import '../models/reaccion.dart';

/// Maneja las reacciones (👍 ❤️ 🎉 😂 😮 😢) de eventos y cumpleaños.
///
/// Los códigos que viajan al backend son los canónicos definidos en
/// [TipoReaccion]: `ME_GUSTA`, `ME_ENCANTA`, `FELICITACIONES`, `DIVERTIDO`,
/// `SORPRESA` y `TRISTE`.
///
/// Endpoints del WS (todos POST bajo `$BASE_URL_APPOFICIAL`, con el sobre
/// `{mensaje, correcto, data}` como respuesta):
///
///   /reacciones_evento   { idUsuario, idEvento }        → todas las reacciones
///   /evento_reaccion     { idUsuario, idEvento, tipo }  → reacción del usuario
///   /quitar_reaccion     { idUsuario, idEvento, tipo }  → quita la del usuario
///
/// `idUsuario` es obligatorio en los tres: sin él el WS responde
/// "Error interno al consultar las reacciones".
///
/// La reacción se aplica de forma optimista y se guarda en SharedPreferences,
/// así la UI queda coherente al instante y al volver a entrar; en cuanto el WS
/// responde, sus datos sobreescriben la caché local.
class ReaccionService extends ChangeNotifier {
  /// Lectura: todas las reacciones del evento.
  static const String rutaObtener = 'reacciones_evento';

  /// Escritura: agrega/cambia la reacción del usuario conectado.
  static const String rutaGuardar = 'evento_reaccion';

  /// Escritura: quita la reacción del usuario conectado.
  static const String rutaQuitar = 'quitar_reaccion';

  static const String _prefsKey = 'reacciones_cache_v1';

  final String baseUrl = Base().BASE_URL_APPOFICIAL;

  /// Resúmenes indexados por "origen:idContenido".
  final Map<String, ResumenReacciones> _resumenes = {};

  bool _cacheCargada = false;

  String _clave(String origen, int idContenido) => '$origen:$idContenido';

  /// Resumen actual del contenido (nunca null; vacío si no hay datos).
  ResumenReacciones resumen(String origen, int idContenido) =>
      _resumenes[_clave(origen, idContenido)] ?? ResumenReacciones();

  // -------------------------
  // Caché local
  // -------------------------

  Future<void> _cargarCacheLocal() async {
    if (_cacheCargada) return;
    _cacheCargada = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;

      final map = json.decode(raw);
      if (map is! Map) return;

      map.forEach((clave, valor) {
        if (valor is Map) {
          _resumenes[clave.toString()] =
              ResumenReacciones.fromJson(Map<String, dynamic>.from(valor));
        }
      });
    } catch (e) {
      debugPrint('⚠️ No se pudo leer la caché de reacciones: $e');
    }
  }

  Future<void> _guardarCacheLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        for (final e in _resumenes.entries) e.key: e.value.toJson(),
      };
      await prefs.setString(_prefsKey, json.encode(data));
    } catch (e) {
      debugPrint('⚠️ No se pudo guardar la caché de reacciones: $e');
    }
  }

  // -------------------------
  // Backend
  // -------------------------

  /// POST genérico a una ruta de reacciones. Devuelve el cuerpo decodificado, o
  /// `null` si la llamada falló o el WS marcó `correcto: false`.
  Future<dynamic> _post(String ruta, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl/$ruta');
    final cuerpo = jsonEncode(body);

    debugPrint('REACCIONES → POST $url\n$cuerpo');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: cuerpo,
      );

      debugPrint('REACCIONES ← HTTP ${response.statusCode} ${response.body}');

      if (response.statusCode != 200) return null;

      final decoded = json.decode(response.body);

      if (decoded is Map && decoded['correcto'] == false) {
        debugPrint('REACCIONES: $ruta → ${decoded['mensaje']}');
        return null;
      }

      return decoded;
    } catch (e) {
      debugPrint('REACCIONES: error en $ruta: $e');
      return null;
    }
  }

  /// Trae todas las reacciones del contenido desde `/reacciones_evento`.
  ///
  /// Se consulta SIEMPRE al entrar al detalle: la caché local solo sirve para
  /// pintar algo de inmediato mientras responde el servidor, y en cuanto llega
  /// la respuesta real ésta la sobreescribe.
  Future<void> cargar({
    required String origen,
    required int idContenido,
    required int idUsuario,
  }) async {
    await _cargarCacheLocal();
    notifyListeners();

    if (idContenido <= 0) return;

    if (idUsuario <= 0) {
      // El WS exige idUsuario; sin él responde "Error interno".
      debugPrint('REACCIONES: sin idUsuario, no se consulta el WS');
      return;
    }

    final data = await _post(rutaObtener, {
      'idUsuario': idUsuario,
      'idEvento': idContenido,
      'origen': origen,
    });

    if (data == null) {
      debugPrint('REACCIONES: no se pudo leer el resumen; se usa la caché');
      return;
    }

    final clave = _clave(origen, idContenido);
    final nuevo = ResumenReacciones.desdeRespuesta(data, idUsuario: idUsuario);

    // Si `/reacciones_evento` solo devuelve conteos agregados (sin marcar cuál
    // es la del usuario conectado), se conserva la que ya teníamos para no
    // "des-seleccionar" el chip. Los conteos siempre son los del servidor.
    if (nuevo.miReaccion == null) {
      final anterior = _resumenes[clave]?.miReaccion;
      if (anterior != null && nuevo.conteoDe(anterior) > 0) {
        nuevo.miReaccion = anterior;
      }
    }

    _resumenes[clave] = nuevo;

    notifyListeners();
    await _guardarCacheLocal();
  }

  /// Aplica la reacción de forma optimista y la envía al backend.
  ///
  /// Según el gesto se usa una ruta distinta:
  /// - tocar una reacción nueva o cambiarla → `/evento_reaccion`
  /// - tocar la que ya estaba activa        → `/quitar_reaccion`
  ///
  /// Tras un POST correcto se vuelve a consultar `/reacciones_evento`, así los
  /// conteos que quedan en pantalla son los del servidor y no los estimados.
  ///
  /// Devuelve `false` si el POST no se pudo confirmar. La reacción NO se
  /// revierte en ese caso: se conserva localmente para no perder el gesto del
  /// usuario, y quien llama decide si avisa.
  Future<bool> alternar({
    required String origen,
    required int idContenido,
    required int idUsuario,
    required TipoReaccion tipo,
  }) async {
    await _cargarCacheLocal();

    final clave = _clave(origen, idContenido);
    final resumen = (_resumenes[clave] ?? ResumenReacciones()).copy();
    final quedaActiva = resumen.alternarLocal(tipo);

    _resumenes[clave] = resumen;
    notifyListeners();
    await _guardarCacheLocal();

    if (idContenido <= 0 || idUsuario <= 0) {
      debugPrint('REACCIÓN: NO se envía — '
          'idUsuario=$idUsuario idContenido=$idContenido (ambos deben ser > 0)');
      return false;
    }

    final ruta = quedaActiva ? rutaGuardar : rutaQuitar;

    final data = await _post(ruta, {
      'idUsuario': idUsuario,
      'idEvento': idContenido,
      'origen': origen,
      'tipo': tipo.codigo,
    });

    if (data == null) return false;

    // Ambas rutas devuelven el resumen completo del evento
    // ({total, reacciones:[...], miReaccion, miEmoji}), así que se usa tal cual
    // y no hace falta un segundo request.
    final delServidor =
        ResumenReacciones.desdeRespuesta(data, idUsuario: idUsuario);

    if (delServidor.conteos.isNotEmpty || delServidor.miReaccion != null) {
      // El gesto manda sobre lo que diga la respuesta: al quitar, la reacción
      // propia queda en null aunque el WS la siga reportando.
      delServidor.miReaccion = quedaActiva
          ? (delServidor.miReaccion ?? tipo)
          : null;

      _resumenes[clave] = delServidor;
      notifyListeners();
      await _guardarCacheLocal();
      return true;
    }

    // La respuesta no trajo resumen (p. ej. al quitar la última reacción):
    // se consulta el listado completo.
    await cargar(
      origen: origen,
      idContenido: idContenido,
      idUsuario: idUsuario,
    );

    return true;
  }

  /// Borra todo (al cerrar sesión: las reacciones son por usuario).
  Future<void> limpiar() async {
    _resumenes.clear();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (e) {
      debugPrint('⚠️ No se pudo limpiar la caché de reacciones: $e');
    }
  }
}
