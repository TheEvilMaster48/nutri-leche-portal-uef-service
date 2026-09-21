import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../base/base.dart';

/// Cliente del REST `wms/api/v1` — «API Viajes del Chofer».
///
/// Es un REST **distinto** del `rutas/api/v1` que usaba la app Android, con otro
/// modelo de datos y otro sobre de respuesta, así que tiene su propio cliente.
/// Dos diferencias que se absorben acá y en ningún otro lado:
///
/// 1. **`data` es un texto con JSON adentro**, no un objeto: hay que decodificar
///    dos veces. Es el mismo comportamiento de `loginAPPOficial`, donde
///    `AuthService` ya hace este baile a mano.
///
/// 2. **Los errores de negocio llegan con HTTP 200** y `correcto: false`. El
///    `msg` viene redactado para mostrárselo al chofer tal cual, así que se
///    propaga sin retocar en lugar de reemplazarlo por un texto genérico.
///
/// No hay login propio: cada llamada manda el `usuario_id` ya autenticado, que
/// es el `Usuario.id` del portal. El servidor resuelve la ficha del chofer por
/// `wms_chofer.usuario_id`.
class WmsApi {
  WmsApi._();

  static const String _raiz = Base.URL_WMS;

  static const Duration _timeout = Duration(seconds: 30);

  /// Cliente HTTP. Se puede sustituir en pruebas para ejercer el desanidado del
  /// sobre y los errores con HTTP 200, que es donde están las trampas.
  @visibleForTesting
  static http.Client cliente = http.Client();

  /// `GET /test` — para saber si el servicio está arriba.
  ///
  /// Útil mientras el módulo no esté desplegado en todos los ambientes: sin
  /// esto, un 404 se confunde con «este chofer no tiene viajes».
  static Future<RespuestaWms> test() => get('test');

  /// GET a `wms/api/v1/<recurso>`.
  ///
  /// Los catálogos del módulo son GET, no POST: `tipos_incidente` responde 405 a
  /// un POST. No llevan `usuario_id` porque no dependen del chofer.
  static Future<RespuestaWms> get(String recurso) async {
    try {
      final respuesta =
          await cliente.get(Uri.parse('$_raiz/$recurso')).timeout(_timeout);
      return _interpretar(recurso, respuesta);
    } catch (e) {
      debugPrint('WMS $recurso → excepción: $e');
      return const RespuestaWms.fallo('No se pudo conectar con el servidor.');
    }
  }

  /// POST a `wms/api/v1/<recurso>` con [cuerpo] serializado como JSON.
  static Future<RespuestaWms> post(
    String recurso,
    Map<String, dynamic> cuerpo,
  ) async {
    try {
      final respuesta = await cliente
          .post(
            Uri.parse('$_raiz/$recurso'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(cuerpo),
          )
          .timeout(_timeout);

      return _interpretar(recurso, respuesta);
    } catch (e) {
      debugPrint('WMS $recurso → excepción: $e');
      return const RespuestaWms.fallo('No se pudo conectar con el servidor.');
    }
  }

  static RespuestaWms _interpretar(String recurso, http.Response respuesta) {
    if (respuesta.statusCode == 404) {
      // Se distingue del resto a propósito: mientras el módulo WMS no esté
      // desplegado, todo da 404 y hay que poder decirlo sin que parezca que el
      // chofer no tiene viajes.
      debugPrint('WMS $recurso → 404, ¿módulo no desplegado?');
      return const RespuestaWms.fallo(
        'El servicio de viajes no está disponible en este servidor.',
      );
    }

    if (respuesta.statusCode != 200) {
      debugPrint('WMS $recurso → HTTP ${respuesta.statusCode}');
      return RespuestaWms.fallo(
        'El servidor respondió ${respuesta.statusCode}.',
      );
    }

    try {
      final sobre = json.decode(utf8.decode(respuesta.bodyBytes));
      if (sobre is! Map) {
        return const RespuestaWms.fallo('El servidor devolvió algo inesperado.');
      }

      final correcto = sobre['correcto'] == true;
      final mensaje = sobre['msg']?.toString() ?? '';

      if (!correcto) {
        // El msg del WS está escrito para el chofer; se muestra sin retocar.
        debugPrint('WMS $recurso → correcto:false · $mensaje');
        return RespuestaWms.rechazo(
          mensaje.isEmpty ? 'No se pudo completar la operación.' : mensaje,
        );
      }

      return RespuestaWms.exito(_desanidar(sobre['data']), mensaje);
    } catch (e) {
      debugPrint('WMS $recurso → cuerpo ilegible: $e');
      return const RespuestaWms.fallo(
        'No se pudo leer la respuesta del servidor.',
      );
    }
  }

  /// Saca el JSON de dentro del texto de `data`.
  ///
  /// Se decodifica en bucle porque el sobre puede venir con una capa de texto
  /// (lo documentado) o con dos (lo que ya pasa en `loginAPPOficial`, donde
  /// `AuthService` decodifica y vuelve a decodificar). Si `data` ya llegara como
  /// objeto, se devuelve tal cual.
  static dynamic _desanidar(dynamic data) {
    var actual = data;
    for (var i = 0; i < 3 && actual is String; i++) {
      final texto = actual.trim();
      if (texto.isEmpty) return null;
      try {
        actual = json.decode(texto);
      } catch (_) {
        // Un texto que no es JSON es un dato legítimo, no un error.
        return actual;
      }
    }
    return actual;
  }
}

/// Por qué falló una llamada.
///
/// La distinción existe para la cola de marcas sin señal: un rechazo por regla
/// de negocio no cambia por reintentarlo — el servidor va a decir lo mismo —,
/// mientras que un fallo de transporte es exactamente lo que la cola espera
/// para volver a intentar más tarde. Tratarlos igual dejaría marcas
/// reintentándose para siempre, o perdería el trabajo del chofer.
enum FalloWms {
  /// `correcto: false` con HTTP 200. El servidor entendió y dijo que no.
  regla,

  /// Red caída, timeout, 404, 500, cuerpo ilegible. El servidor no contestó
  /// algo que se pueda interpretar.
  transporte,
}

/// Resultado de una llamada al REST de WMS.
class RespuestaWms {
  /// Contenido de `data`, ya desanidado: una `List`, un `Map` o `null`.
  final dynamic datos;

  /// El `msg` del sobre. Cuando [ok] es false, es el texto para el chofer.
  final String mensaje;

  final bool ok;

  /// Solo cuando [ok] es false.
  final FalloWms? fallo;

  const RespuestaWms.exito(this.datos, this.mensaje)
      : ok = true,
        fallo = null;

  /// Rechazo del servidor: entendió la petición y la negó.
  const RespuestaWms.rechazo(this.mensaje)
      : datos = null,
        ok = false,
        fallo = FalloWms.regla;

  /// No se pudo hablar con el servidor, o lo que contestó no se entiende.
  const RespuestaWms.fallo(this.mensaje)
      : datos = null,
        ok = false,
        fallo = FalloWms.transporte;

  /// Si vale la pena volver a intentar esta misma llamada más tarde.
  bool get reintentable => fallo == FalloWms.transporte;

  /// `null` cuando [ok]; el mensaje de error cuando no.
  String? get error => ok ? null : mensaje;

  List<Map<String, dynamic>> get lista {
    final d = datos;
    if (d is! List) return const [];
    return d.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Map<String, dynamic>? get mapa {
    final d = datos;
    return d is Map ? d.cast<String, dynamic>() : null;
  }
}
