import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/registro_viaje.dart';
import '../models/viaje.dart';

/// Estado local del módulo Rutas: el viaje en curso y sus registros de evento.
///
/// Reemplaza a Realm, que en la app Android guardaba exactamente esto. El
/// volumen lo justifica: un viaje activo, unas decenas de destinatarios y los
/// registros de ese viaje, que se borran al cerrarlo. Son decenas de filas, no
/// miles, y el portal ya resuelve este problema con JSON en
/// `SharedPreferences` — ver [OcultosStore], del que se copia el patrón. Meter
/// `sqflite` traería migraciones de esquema sin ganar nada.
///
/// El umbral por si cambia: si algún día entra el tracking continuo, con miles
/// de puntos de recorrido en cola, eso sí pide una tabla real.
///
/// Todo va segmentado por [idUsuario] porque un mismo teléfono puede usarse con
/// varias cuentas y un viaje en curso es de quien lo abrió.
class RutaStore {
  RutaStore._();

  static String _claveViaje(int idUsuario) => 'rutas_viaje_activo_$idUsuario';

  static String _claveRegistros(int idUsuario) => 'rutas_registros_$idUsuario';

  // ---------------------------------------------------------------------------
  // Viaje activo
  // ---------------------------------------------------------------------------

  /// El viaje en curso, o `null` si el chofer no tiene ninguno abierto.
  ///
  /// Incluye sus destinatarios: llegan dentro de la respuesta de
  /// `cambiar_status_viaje` y se guardan junto al viaje porque es la única vez
  /// que el servidor los manda. Pedirlos de nuevo no es una opción.
  static Future<Viaje?> leerViajeActivo(int idUsuario) async {
    if (idUsuario <= 0) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(_claveViaje(idUsuario));
      if (crudo == null || crudo.isEmpty) return null;

      final decodificado = json.decode(crudo);
      if (decodificado is! Map) return null;

      return Viaje.fromJson(decodificado.cast<String, dynamic>());
    } catch (e) {
      debugPrint('⚠️ No se pudo leer el viaje activo: $e');
      return null;
    }
  }

  static Future<void> guardarViajeActivo(int idUsuario, Viaje viaje) async {
    if (idUsuario <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _claveViaje(idUsuario),
        json.encode(viaje.toJson()),
      );
    } catch (e) {
      debugPrint('⚠️ No se pudo guardar el viaje activo: $e');
    }
  }

  /// Borra el viaje en curso. **No borra los registros**: al cerrar un viaje
  /// los registros todavía tienen que enviarse, y si el envío falla son lo
  /// único que queda del trabajo del chofer. Se borran aparte, con
  /// [borrarRegistros], y solo cuando el servidor confirmó.
  static Future<void> borrarViajeActivo(int idUsuario) async {
    if (idUsuario <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_claveViaje(idUsuario));
    } catch (e) {
      debugPrint('⚠️ No se pudo borrar el viaje activo: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Registros de evento
  // ---------------------------------------------------------------------------

  static Future<List<RegistroViaje>> leerRegistros(int idUsuario) async {
    if (idUsuario <= 0) return const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(_claveRegistros(idUsuario));
      if (crudo == null || crudo.isEmpty) return const [];

      final decodificado = json.decode(crudo);
      if (decodificado is! List) return const [];

      return decodificado
          .whereType<Map>()
          .map((e) => RegistroViaje.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (e) {
      debugPrint('⚠️ No se pudieron leer los registros de ruta: $e');
      return const [];
    }
  }

  static Future<void> guardarRegistros(
    int idUsuario,
    List<RegistroViaje> registros,
  ) async {
    if (idUsuario <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _claveRegistros(idUsuario),
        json.encode(registros.map((r) => r.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('⚠️ No se pudieron guardar los registros de ruta: $e');
    }
  }

  /// Agrega un registro nuevo a los que ya hay y devuelve la lista resultante.
  static Future<List<RegistroViaje>> agregarRegistro(
    int idUsuario,
    RegistroViaje registro,
  ) async {
    final registros = [...await leerRegistros(idUsuario), registro];
    await guardarRegistros(idUsuario, registros);
    return registros;
  }

  /// Reemplaza un registro por su [RegistroViaje.id] — se usa al cerrarlo.
  ///
  /// Si el id no existe la lista queda igual, sin agregarlo: un registro que no
  /// estaba guardado no debería aparecer por un update.
  static Future<List<RegistroViaje>> actualizarRegistro(
    int idUsuario,
    RegistroViaje registro,
  ) async {
    final registros = await leerRegistros(idUsuario);
    final indice = registros.indexWhere((r) => r.id == registro.id);
    if (indice == -1) {
      debugPrint('⚠️ Registro ${registro.id} no encontrado; no se actualiza');
      return registros;
    }
    registros[indice] = registro;
    await guardarRegistros(idUsuario, registros);
    return registros;
  }

  static Future<void> borrarRegistros(int idUsuario) async {
    if (idUsuario <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_claveRegistros(idUsuario));
    } catch (e) {
      debugPrint('⚠️ No se pudieron borrar los registros de ruta: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Consultas de negocio
  // ---------------------------------------------------------------------------

  /// El registro abierto, o `null` si no hay ninguno.
  ///
  /// Solo puede haber uno a la vez: registrar un evento con otro abierto es la
  /// regla que la app Android validaba antes de dejar entrar a la pantalla.
  static Future<RegistroViaje?> registroAbierto(int idUsuario) async {
    for (final r in await leerRegistros(idUsuario)) {
      if (r.abierto) return r;
    }
    return null;
  }

  static Future<List<RegistroViaje>> registrosCerrados(int idUsuario) async {
    final registros = await leerRegistros(idUsuario);
    return registros.where((r) => r.cerrado).toList();
  }

  /// Siguiente id local para un registro.
  ///
  /// Es `max + 1` sobre lo guardado, como hacía `nextKey()` en Realm. El id no
  /// viaja al servidor — `guardar_registro_ruta` no lo recibe — así que reiniciar
  /// desde 1 después de un envío exitoso no rompe nada.
  static Future<int> siguienteIdRegistro(int idUsuario) async {
    final registros = await leerRegistros(idUsuario);
    if (registros.isEmpty) return 1;
    return registros.map((r) => r.id).reduce((a, b) => a > b ? a : b) + 1;
  }

  /// Borra todo el estado local del módulo para un usuario.
  ///
  /// Se llama al cerrar sesión: un viaje a medias no debe reaparecerle al
  /// siguiente que entre en el mismo teléfono.
  static Future<void> limpiar(int idUsuario) async {
    await borrarViajeActivo(idUsuario);
    await borrarRegistros(idUsuario);
  }
}
