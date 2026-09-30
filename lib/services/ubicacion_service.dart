import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Motivo por el que no se pudo obtener la posición.
///
/// Se distingue el motivo porque cada uno se resuelve distinto y el chofer
/// necesita saber cuál le toca: prender el GPS no es lo mismo que ir a los
/// ajustes del sistema a rehabilitar un permiso que negó para siempre.
enum FalloUbicacion {
  /// El GPS del teléfono está apagado.
  servicioApagado,

  /// El usuario negó el permiso en este momento; se le puede volver a pedir.
  permisoNegado,

  /// Negado permanentemente. Solo se arregla desde los ajustes del sistema.
  permisoNegadoParaSiempre,

  /// Pasó el tiempo límite sin que el GPS fijara posición.
  sinSenal,

  /// Cualquier otra cosa.
  error,
}

/// Posición puntual, o el motivo por el que no hay.
class ResultadoUbicacion {
  final Position? posicion;
  final FalloUbicacion? fallo;

  /// Mensaje listo para mostrarle al chofer.
  final String? mensaje;

  const ResultadoUbicacion.exito(Position this.posicion)
    : fallo = null,
      mensaje = null;

  const ResultadoUbicacion.error(FalloUbicacion this.fallo, this.mensaje)
    : posicion = null;

  bool get ok => posicion != null;

  /// Si la precisión es peor que [UbicacionService.precisionAceptableMetros].
  ///
  /// No invalida la posición: una lectura de 80 metros sirve para saber que el
  /// camión estaba en tal bodega, y negarse a registrar dejaría al chofer sin
  /// poder trabajar dentro de una nave o entre edificios. Pero la pantalla
  /// debería avisarlo, y el dato queda marcado como flojo.
  bool get precisionDudosa {
    final p = posicion;
    if (p == null) return false;
    return p.accuracy > UbicacionService.precisionAceptableMetros;
  }
}

/// Posición puntual para sellar el inicio y el fin de un evento de ruta.
///
/// Es lo único de geolocalización que usa el módulo: **no hay seguimiento
/// continuo**. Por eso la app pide permiso solo de primer plano y no declara
/// `ACCESS_BACKGROUND_LOCATION` ni un foreground service.
///
/// Mejora deliberadamente lo que hacía la app Android, que llamaba a
/// `getLastLocation()` de FusedLocationProvider. Ese método devuelve la última
/// posición **cacheada por el sistema**, que puede ser nula o de hace horas y de
/// otro lugar: un evento podía quedar sellado con las coordenadas de donde el
/// chofer estuvo antes. Aquí se pide una lectura nueva con
/// `getCurrentPosition`, con tiempo límite, y se descarta la que llegue vieja.
class UbicacionService {
  UbicacionService._();

  /// Cuánto se espera una lectura antes de rendirse.
  ///
  /// 20 segundos es lo que tarda un GPS frío bajo techo o entre edificios.
  /// Menos deja al chofer sin registrar en sitios donde sí habría fijado.
  static const Duration tiempoLimite = Duration(seconds: 20);

  /// Precisión por encima de la cual la lectura se marca como dudosa.
  static const double precisionAceptableMetros = 100;

  /// Antigüedad máxima de una lectura para considerarla del momento.
  static const Duration antiguedadMaxima = Duration(minutes: 2);

  /// Pide una posición nueva, resolviendo permisos y GPS apagado en el camino.
  ///
  /// No lanza excepciones: todo error vuelve como [ResultadoUbicacion] con su
  /// [FalloUbicacion] y un mensaje ya redactado.
  static Future<ResultadoUbicacion> obtener() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const ResultadoUbicacion.error(
          FalloUbicacion.servicioApagado,
          'El GPS está apagado. Actívalo para registrar el evento.',
        );
      }

      final permiso = await _resolverPermiso();
      if (permiso != null) return permiso;

      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: tiempoLimite,
        ),
      );

      // Cinturón y tirantes: si el sistema devolviera una lectura vieja pese a
      // habérsela pedido nueva, es mejor fallar que sellar el evento en el lugar
      // equivocado. Es exactamente el fallo que tenía la app Android.
      if (esVieja(posicion.timestamp)) {
        debugPrint(
          'UBICACIÓN: lectura descartada por vieja '
          '(${posicion.timestamp})',
        );
        return const ResultadoUbicacion.error(
          FalloUbicacion.sinSenal,
          'La ubicación que dio el teléfono es vieja. Sal a un lugar '
          'despejado y vuelve a intentarlo.',
        );
      }

      debugPrint(
        'UBICACIÓN: ${posicion.latitude}, ${posicion.longitude} '
        '(±${posicion.accuracy.toStringAsFixed(0)} m)',
      );

      return ResultadoUbicacion.exito(posicion);
    } on TimeoutException {
      return const ResultadoUbicacion.error(
        FalloUbicacion.sinSenal,
        'No se pudo fijar la ubicación. Sal a un lugar despejado y vuelve a '
        'intentarlo.',
      );
    } catch (e) {
      debugPrint('UBICACIÓN: error inesperado → $e');
      return const ResultadoUbicacion.error(
        FalloUbicacion.error,
        'No se pudo obtener la ubicación.',
      );
    }
  }

  /// Devuelve `null` si el permiso está concedido; el fallo si no.
  static Future<ResultadoUbicacion?> _resolverPermiso() async {
    var permiso = await Geolocator.checkPermission();

    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }

    switch (permiso) {
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return null;

      case LocationPermission.deniedForever:
        return const ResultadoUbicacion.error(
          FalloUbicacion.permisoNegadoParaSiempre,
          'El permiso de ubicación está bloqueado. Habilítalo en los ajustes '
          'del teléfono para poder registrar eventos.',
        );

      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return const ResultadoUbicacion.error(
          FalloUbicacion.permisoNegado,
          'Se necesita el permiso de ubicación para registrar el evento.',
        );
    }
  }

  /// La ciudad de unas coordenadas, o `null` si no se pudo averiguar.
  ///
  /// Es geocodificación inversa contra el servicio del sistema (Geocoder en
  /// Android, CLGeocoder en iOS). **Necesita datos**: sin conexión falla, y es
  /// justo lo normal en bodega o en ruta. Por eso devuelve `null` en vez de
  /// lanzar, y el formulario deja el campo escribible en lugar de bloquearlo.
  ///
  /// No se encadena a [obtener]: sellar la posición no puede quedar esperando a
  /// una consulta de red que quizá no llegue nunca.
  static Future<String?> ciudadDe(double latitud, double longitud) async {
    if (!_geocoderDisponible) return null;

    try {
      final lugares = await Geocoding()
          .placemarkFromCoordinates(latitud, longitud)
          .timeout(tiempoLimiteCiudad);
      if (lugares.isEmpty) return null;

      final ciudad = mejorCiudad(lugares.first);
      debugPrint('UBICACIÓN: ciudad resuelta → $ciudad');
      return ciudad;
    } catch (e) {
      // Sin datos, sin Play Services o sin resultado: todo termina acá y el
      // campo se queda vacío para que lo escriba quien captura.
      debugPrint('UBICACIÓN: no se pudo resolver la ciudad → $e');
      if (esFalloDeCanal(e)) {
        // El lado nativo del plugin no está en este binario: no va a aparecer
        // mientras la app siga corriendo, así que se deja de preguntar. Pasa
        // cuando se agrega el plugin y solo se hace hot restart, y en equipos
        // sin el geocoder del sistema.
        debugPrint('UBICACIÓN: geocoder no disponible, no se reintenta');
        _geocoderDisponible = false;
      }
      return null;
    }
  }

  /// Si vale la pena seguir consultando al geocoder en esta sesión.
  static bool _geocoderDisponible = true;

  /// Si el error es «el plugin no está», y no una falla pasajera de red.
  ///
  /// Un error de canal no se arregla reintentando: el lado nativo no existe en
  /// el binario que está corriendo. Un timeout o un fallo del servicio, en
  /// cambio, sí puede andar en la próxima captura.
  @visibleForTesting
  static bool esFalloDeCanal(Object error) {
    final texto = error.toString();
    return texto.contains('channel-error') ||
        texto.contains('MissingPluginException');
  }

  /// Vuelve a habilitar las consultas. Solo para pruebas.
  @visibleForTesting
  static void reiniciarGeocoder() => _geocoderDisponible = true;

  /// Cuánto se espera al geocoder antes de rendirse.
  ///
  /// Corto a propósito: es un campo opcional que se puede escribir a mano, y no
  /// vale la pena hacer esperar por él.
  static const Duration tiempoLimiteCiudad = Duration(seconds: 8);

  /// Qué campo del resultado es «la ciudad».
  ///
  /// El geocoder no siempre llena `locality`: en zonas rurales y en varias
  /// parroquias del país viene vacío y lo que corresponde es el cantón
  /// (`subAdministrativeArea`) o la provincia (`administrativeArea`). Se baja
  /// por esa escalera en vez de devolver vacío.
  ///
  /// Aparte para poder probarla sin depender del servicio del sistema.
  @visibleForTesting
  static String? mejorCiudad(Placemark lugar) {
    for (final candidato in [
      lugar.locality,
      lugar.subAdministrativeArea,
      lugar.administrativeArea,
    ]) {
      final texto = candidato?.trim() ?? '';
      // En mayúsculas, como el resto de los valores que guarda el ERP.
      if (texto.isNotEmpty) return texto.toUpperCase();
    }
    return null;
  }

  /// Si una lectura es más antigua que [antiguedadMaxima].
  ///
  /// Aparte para poder probarla sin depender del GPS del dispositivo.
  static bool esVieja(DateTime momento, {DateTime? ahora}) {
    final referencia = ahora ?? DateTime.now();
    return referencia.difference(momento.toLocal()) > antiguedadMaxima;
  }

  /// Abre los ajustes donde el usuario puede desbloquear el permiso.
  ///
  /// Es la única salida cuando el fallo es [FalloUbicacion.permisoNegadoParaSiempre]:
  /// desde la app ya no se puede volver a preguntar.
  static Future<void> abrirAjustes(FalloUbicacion fallo) async {
    try {
      if (fallo == FalloUbicacion.servicioApagado) {
        await Geolocator.openLocationSettings();
      } else {
        await Geolocator.openAppSettings();
      }
    } catch (e) {
      debugPrint('UBICACIÓN: no se pudieron abrir los ajustes → $e');
    }
  }
}
