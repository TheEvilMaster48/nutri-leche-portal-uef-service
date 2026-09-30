import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../base/base.dart';
import '../models/parametro.dart';

/// Cliente del REST `logo/api/v1` — módulo Logo Nutri.
///
/// Usa el sobre estándar del portal, `{mensaje, correcto, data}`, distinto del
/// de WMS (`msg`) y del JSON desnudo de rutas. Dos cosas que se absorben acá:
///
/// 1. **`correcto: false` con HTTP 200 no siempre es un error.** Verificado en
///    producción: con la tabla vacía, `GET /parametros` responde
///    `{"mensaje":"No hay parametros","correcto":false,"data":null}`. Eso es
///    «no hay datos», no «falló»: si se tratara como fallo, la pantalla
///    mostraría un error rojo donde solo falta que el ERP cargue el catálogo.
///    Por eso [RespuestaLogo] distingue [FalloLogo.vacio] del resto. Con datos,
///    el mismo recurso responde `correcto: true` y un `data` con una lista por
///    campo: ver [CatalogoParametros].
///
/// 2. **Un 404 puede ser «todavía no desplegado»**, no un error de red:
///    `/administracion` y `/guardar_elemento` salieron en la rama `dev` y al
///    2026-09-21 no estaban en producción. Se distingue con un mensaje propio.
class LogoApi {
  LogoApi._();

  static const String _raiz = Base.URL_LOGO;

  static const Duration _timeout = Duration(seconds: 30);

  /// Catálogos de los cuatro desplegables.
  ///
  /// Es `/administracion`, no `/parametros`: este último quedó obsoleto y
  /// devuelve solo `TIPO DE MATERIAL` en un array plano, para no romper las
  /// versiones de la app ya publicadas.
  static const String recursoCatalogo = 'administracion';

  /// Recurso al que se envía un registro capturado.
  ///
  /// Es `/guardar_elemento`, el endpoint para versiones nuevas:
  /// `/guardar_observacion` exige `descripcion` y `referenciaUbicacion` y falla
  /// con error del servidor si falta alguno, y no admite `cantidad`.
  static const String recursoRegistro = 'guardar_elemento';

  @visibleForTesting
  static http.Client cliente = http.Client();

  /// GET a `logo/api/v1/<recurso>`.
  static Future<RespuestaLogo> get(String recurso) async {
    try {
      final respuesta = await cliente
          .get(Uri.parse('$_raiz/$recurso'))
          .timeout(_timeout);
      return _interpretar(recurso, respuesta);
    } catch (e) {
      debugPrint('LOGO $recurso → excepción: $e');
      return const RespuestaLogo.fallo('No se pudo conectar con el servidor.');
    }
  }

  /// POST a `logo/api/v1/<recurso>` con [cuerpo] serializado como JSON.
  static Future<RespuestaLogo> post(
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
      debugPrint('LOGO $recurso → excepción: $e');
      return const RespuestaLogo.fallo('No se pudo conectar con el servidor.');
    }
  }

  /// Saca el JSON de dentro del texto de `data`.
  ///
  /// En este servidor `data` puede venir como objeto o **como un texto con
  /// JSON adentro**: es lo que ya hacen `loginAPPOficial` —donde `AuthService`
  /// decodifica dos veces a mano— y el REST de WMS. Como no se pudo ver una
  /// respuesta con datos, se cubren las dos formas en lugar de apostar a una.
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

  static RespuestaLogo _interpretar(String recurso, http.Response respuesta) {
    if (respuesta.statusCode == 404) {
      // Se distingue del resto a propósito: `/administracion` y
      // `/guardar_elemento` viven en la rama `dev` y al 2026-09-21 todavía dan
      // 404 en producción. Sin este mensaje parecería un problema de red.
      debugPrint('LOGO $recurso → 404, ¿módulo no desplegado?');
      return const RespuestaLogo.fallo(
        'El servicio de Logo Nutri no está disponible en este servidor.',
      );
    }

    if (respuesta.statusCode != 200) {
      debugPrint('LOGO $recurso → HTTP ${respuesta.statusCode}');
      return RespuestaLogo.fallo(
        'El servidor respondió ${respuesta.statusCode}.',
      );
    }

    try {
      final sobre = json.decode(utf8.decode(respuesta.bodyBytes));
      if (sobre is! Map) {
        return const RespuestaLogo.fallo(
          'El servidor devolvió algo inesperado.',
        );
      }

      final mensaje = sobre['mensaje']?.toString() ?? '';
      final datos = sobre['data'];

      if (sobre['correcto'] == true) {
        return RespuestaLogo.exito(_desanidar(datos), mensaje);
      }

      // `correcto: false` con un mensaje del estilo «No hay …» es el catálogo
      // vacío, no una falla: `/administracion` responde así cuando los cuatro
      // catálogos están sin parámetros activos, y manda igual el objeto con
      // las cuatro listas vacías. Se mira el mensaje porque el WS no da ningún
      // otro indicador que separe «vacío» de «falló».
      if (Parametrizacion.pareceVacio(mensaje)) {
        debugPrint('LOGO $recurso → sin datos · $mensaje');
        return RespuestaLogo.sinDatos(
          mensaje.isEmpty ? 'El servidor no devolvió datos.' : mensaje,
        );
      }

      debugPrint('LOGO $recurso → correcto:false · $mensaje');
      return RespuestaLogo.rechazo(
        mensaje.isEmpty ? 'No se pudo completar la operación.' : mensaje,
      );
    } catch (e) {
      debugPrint('LOGO $recurso → cuerpo ilegible: $e');
      return const RespuestaLogo.fallo(
        'No se pudo leer la respuesta del servidor.',
      );
    }
  }
}

/// Reglas de lectura del sobre que conviene poder probar sin red.
class Parametrizacion {
  Parametrizacion._();

  /// Si el mensaje del WS describe una tabla vacía y no una falla.
  static bool pareceVacio(String mensaje) {
    final m = mensaje.toLowerCase();
    return m.contains('no hay') ||
        m.contains('sin datos') ||
        m.contains('no existen') ||
        m.contains('no se encontraron');
  }
}

/// Por qué falló una llamada al REST de Logo Nutri.
enum FalloLogo {
  /// El servidor contestó bien pero no hay registros que devolver.
  vacio,

  /// `correcto: false` por una regla de negocio. Reintentar da lo mismo.
  regla,

  /// Red caída, timeout, 5xx, cuerpo ilegible. Esto sí se reintenta.
  transporte,
}

class RespuestaLogo {
  /// Contenido de `data`: una `List`, un `Map` o `null`.
  final dynamic datos;

  /// El `mensaje` del sobre, escrito para mostrarse tal cual.
  final String mensaje;

  final bool ok;

  /// Solo cuando [ok] es false.
  final FalloLogo? fallo;

  const RespuestaLogo.exito(this.datos, this.mensaje) : ok = true, fallo = null;

  const RespuestaLogo.sinDatos(this.mensaje)
    : datos = null,
      ok = false,
      fallo = FalloLogo.vacio;

  const RespuestaLogo.rechazo(this.mensaje)
    : datos = null,
      ok = false,
      fallo = FalloLogo.regla;

  const RespuestaLogo.fallo(this.mensaje)
    : datos = null,
      ok = false,
      fallo = FalloLogo.transporte;

  /// Si vale la pena volver a intentar más tarde: solo los fallos de
  /// transporte. Un catálogo vacío o un rechazo por regla no cambian solos.
  bool get reintentable => fallo == FalloLogo.transporte;

  /// `true` cuando el servidor respondió pero no hay datos que mostrar.
  bool get vacio => fallo == FalloLogo.vacio;

  String? get error => ok ? null : mensaje;

  /// Los datos como lista de mapas, para los recursos que devuelven un array.
  ///
  /// `parametros` no es uno de ellos: su `data` es un objeto de listas y se lee
  /// con [mapa]. Ver [CatalogoParametros].
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
