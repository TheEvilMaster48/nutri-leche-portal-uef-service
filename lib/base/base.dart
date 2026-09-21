import 'dart:ui';

import 'package:nutri/base/utils.dart';

// import utils

class Base {
  // ---------------------------------------------------------------------------
  // Servidor. Único lugar donde se escribe el dominio: todo lo que apunte a
  // servicioslsa debe construirse a partir de estas constantes, así un cambio
  // de host o de ambiente se hace en una sola línea.
  //
  // Para apuntar a un servidor local, cambiar ORIGEN_SERVICIOS por ejemplo a:
  //   "http://190.95.184.58"      /  "http://192.168.18.41:8080"
  //   "http://192.170.4.60:8080"
  // ---------------------------------------------------------------------------

  /// Solo el host (sin esquema). Lo usa el override de certificados en main.dart.
  static const String HOST_SERVICIOS = "servicioslsa.nutri.com.ec";

  static const String ORIGEN_SERVICIOS = "https://$HOST_SERVICIOS";

  /// Raíz del REST "app" (login, perfil, sugerencias, recursos).
  static const String URL_APP = "$ORIGEN_SERVICIOS/nutrisoft/rest/app/api/v1";

  /// Raíz del REST "appOficial" (eventos, cumpleaños, sorteos, tokens push).
  static const String URL_APPOFICIAL =
      "$ORIGEN_SERVICIOS/nutrisoft/rest/appOficial/api/v1";

  /// Raíz del REST "appMensaje" (módulo Nutrisoft / mensajes). Es un REST
  /// aparte: solo lo usa NutrisoftService, el resto sigue en appOficial.
  static const String URL_APPMENSAJE =
      "$ORIGEN_SERVICIOS/nutrisoft/rest/appMensaje/api/v1";

  /// Archivos estáticos publicados en el servidor (gifs, imágenes).
  static const String URL_RECURSOS = "$ORIGEN_SERVICIOS/resources";

  /// Raíz del REST "rutas" (módulo de control de rutas: viajes, eventos,
  /// destinatarios, registros de ruta). Verificado en producción: responde
  /// igual que el ambiente QAS contra el que corría la app Android.
  static const String URL_RUTAS = "$ORIGEN_SERVICIOS/nutrisoft/rest/rutas/api/v1";

  /// Raíz del REST "wms" — «API Viajes del Chofer»: viajes asignados, entregas
  /// y marcado de hitos de ruta.
  ///
  /// Es el reemplazo de [URL_RUTAS] para el flujo del chofer, con otro modelo de
  /// datos. Al 2026-08-28 todavía NO está desplegado: `/test` responde 404 tanto
  /// en producción como en QAS, y su documentación indica que faltan dos scripts
  /// SQL. Ver [[WmsApi]], que distingue el 404 de «este chofer no tiene viajes».
  static const String URL_WMS = "$ORIGEN_SERVICIOS/nutrisoft/rest/wms/api/v1";

  // Se conservan los nombres de instancia que ya usa el resto de la app.
  final String BASE_URL_APPOFICIAL = URL_APPOFICIAL;
  final String BASE_URL_APPMENSAJE = URL_APPMENSAJE;
  final String BASE_URL_APP = URL_APP;
  final String BASE_URL_RUTAS = URL_RUTAS;
  final String BASE_URL_WMS = URL_WMS;
  final String BASE_URL_RECURSOS = URL_RECURSOS;
  final String BASE_URL = "$ORIGEN_SERVICIOS/nutrisoft/rest/";

  // Los servicios de subida de archivos se dejan con la URL completa escrita:
  // son endpoints PHP independientes del REST y pueden moverse a otro servidor.
  final String BASE_URL_ARCHIVOS =
      "https://servicioslsa.nutri.com.ec/rrhh/upload.php";
  final String BASE_URL_ARCHIVOS_ENCUESTA =
      "https://servicioslsa.nutri.com.ec/encuesta/upload.php";
  final String BASE_URL_ARCHIVOS_IMAGEN_NUTRI =
      "https://servicioslsa.nutri.com.ec/logoNutri/upload.php";
  // Evidencia fotográfica de los registros de ruta. La app Android subía a
  // este mismo PHP pero en el host QAS; se apunta a producción por coherencia
  // con los tres de arriba. Confirmar con una subida real antes de liberar.
  final String BASE_URL_ARCHIVOS_ACTIVOS =
      "https://servicioslsa.nutri.com.ec/activos/upload.php";
  final Color COLOR_AZUL_CLARO = Utils().colorFromHex("#00AEEF");
  final Color COLOR_AZUL_VERDE = Utils().colorFromHex("#86B918");
  final Color COLOR_AZUL_OSCURO = Utils().colorFromHex("#005EA8");
  final Color COLOR_NEGRO_OSCURO = Utils().colorFromHex("#000000");
  final Color COLOR_AZUL_CORP = Utils().colorFromHex("#0A4697");
  final Color COLOR_GRIS = Utils().colorFromHex("#F666666");
  final Color COLOR_BLANCO = Utils().colorFromHex("#F5F5F5");

// GoogleFonts.montserrat().fontFamily), por defectoo
}
