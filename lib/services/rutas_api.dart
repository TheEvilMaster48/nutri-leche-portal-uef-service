import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../base/base.dart';

/// Cliente del REST `rutas/api/v1` (módulo Rutas).
///
/// Existe como capa aparte porque ese REST no sigue las convenciones del resto
/// del portal y hay que absorber dos diferencias en un solo lugar:
///
/// 1. **El cuerpo puede ser un escalar, no un objeto.** Los endpoints se
///    declararon en Android con `@Body int id` y `@Body String nulo`, así que
///    Retrofit enviaba `5` y `""` — no `{"id": 5}`. Mandar un mapa hace que el
///    WS responda error y parece un problema de red. Por eso [postRutas] recibe
///    el cuerpo como `Object?` y lo serializa tal cual.
///
/// 2. **Los errores llegan con HTTP 200.** Verificado en producción: un id de
///    chofer inexistente devuelve `200` y el cuerpo `"Chofer no encontrado"`,
///    un string JSON desnudo en lugar de la lista esperada. Un `statusCode ==
///    200` no alcanza para asumir éxito: hay que mirar la *forma* del cuerpo.
///
/// Las respuestas correctas también son JSON desnudo (un array o un objeto),
/// sin el envoltorio `{correcto, data}` que usa el resto del portal.
class RutasApi {
  RutasApi._();

  static const String _raiz = Base.URL_RUTAS;

  static const Duration _timeout = Duration(seconds: 30);

  /// POST a `rutas/api/v1/<recurso>`.
  ///
  /// [cuerpo] se serializa con `jsonEncode` sin envolver, de modo que un `int`
  /// viaja como `5` y un `String` vacío como `""`. Para los endpoints que sí
  /// esperan un objeto, se pasa un `Map`.
  static Future<RespuestaRutas> postRutas(
    String recurso,
    Object? cuerpo,
  ) async {
    final uri = Uri.parse('$_raiz/$recurso');

    try {
      final respuesta = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(cuerpo),
          )
          .timeout(_timeout);

      if (respuesta.statusCode != 200) {
        debugPrint('RUTAS $recurso → HTTP ${respuesta.statusCode}');
        return RespuestaRutas.fallo(
          'El servidor respondió ${respuesta.statusCode}.',
        );
      }

      if (respuesta.body.trim().isEmpty) {
        return RespuestaRutas.fallo(
          'El servidor devolvió una respuesta vacía.',
        );
      }

      final dynamic decodificado = json.decode(
        utf8.decode(respuesta.bodyBytes),
      );

      // Aquí está la trampa: con HTTP 200, un String es el mensaje de error del
      // WS ("Chofer no encontrado"), no un dato. Una List o un Map sí son datos.
      if (decodificado is String) {
        debugPrint('RUTAS $recurso → 200 pero mensaje: $decodificado');
        return RespuestaRutas.fallo(decodificado);
      }

      return RespuestaRutas.exito(decodificado);
    } catch (e) {
      debugPrint('RUTAS $recurso → excepción: $e');
      return RespuestaRutas.fallo('No se pudo conectar con el servidor.');
    }
  }
}

/// Resultado de una llamada al REST de rutas.
///
/// Se prefiere esto a devolver `null` porque el WS distingue entre «no hay
/// datos» y «hay un mensaje que el conductor tiene que leer», y ese mensaje se
/// pierde si el servicio solo puede responder nulo.
class RespuestaRutas {
  /// Cuerpo decodificado cuando [ok] es true: una `List` o un `Map`.
  final dynamic datos;

  /// Mensaje para mostrar al usuario cuando [ok] es false. Puede venir del
  /// propio WS o describir un fallo de red.
  final String? error;

  const RespuestaRutas.exito(this.datos) : error = null;

  const RespuestaRutas.fallo(String this.error) : datos = null;

  bool get ok => error == null;

  /// Los datos como lista de mapas, o vacío si el cuerpo no era una lista.
  ///
  /// Cubre el caso de un endpoint que devuelve `[]` — como `post_lugares` hoy
  /// en producción — sin que el llamador tenga que distinguirlo de un error.
  List<Map<String, dynamic>> get lista {
    final d = datos;
    if (d is! List) return const [];
    return d.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  /// Los datos como un solo mapa, o `null` si el cuerpo no era un objeto.
  Map<String, dynamic>? get mapa {
    final d = datos;
    return d is Map ? d.cast<String, dynamic>() : null;
  }
}
