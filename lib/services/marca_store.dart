import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/marca_ruta.dart';

/// Cola de hitos marcados que todavía no llegaron al servidor.
///
/// Es lo que hace que el módulo sirva en ruta: el chofer marca sin señal, la
/// marca queda acá con la hora del teléfono, y se envía cuando haya cobertura.
///
/// **El orden importa.** El servidor exige los hitos en secuencia —rechaza una
/// llegada sin salida— así que la cola es FIFO y se drena en orden. Enviar la
/// llegada antes que la salida haría que el servidor rechace la primera por una
/// regla que en realidad sí se cumplía.
///
/// Segmentada por usuario, como el resto del estado local del módulo: las
/// marcas de un chofer no son de quien entre después en el mismo teléfono.
class MarcaStore {
  MarcaStore._();

  static String _clave(int idUsuario) => 'wms_marcas_pendientes_$idUsuario';

  /// La cola en orden de encolado: la más vieja primero.
  static Future<List<MarcaRuta>> leer(int idUsuario) async {
    if (idUsuario <= 0) return const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(_clave(idUsuario));
      if (crudo == null || crudo.isEmpty) return const [];

      final decodificado = json.decode(crudo);
      if (decodificado is! List) return const [];

      final marcas = decodificado
          .whereType<Map>()
          .map((e) => MarcaRuta.fromJson(e.cast<String, dynamic>()))
          .toList()
        // Se reordena al leer, no se confía en el orden del archivo: el id es
        // correlativo y es la única garantía de secuencia que hay.
        ..sort((a, b) => a.id.compareTo(b.id));

      return marcas;
    } catch (e) {
      debugPrint('⚠️ No se pudo leer la cola de marcas: $e');
      return const [];
    }
  }

  static Future<void> guardar(int idUsuario, List<MarcaRuta> marcas) async {
    if (idUsuario <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (marcas.isEmpty) {
        await prefs.remove(_clave(idUsuario));
        return;
      }
      await prefs.setString(
        _clave(idUsuario),
        json.encode(marcas.map((m) => m.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('⚠️ No se pudo guardar la cola de marcas: $e');
    }
  }

  /// Encola una marca al final y devuelve la cola resultante.
  static Future<List<MarcaRuta>> encolar(
    int idUsuario,
    MarcaRuta marca,
  ) async {
    final marcas = [...await leer(idUsuario), marca];
    await guardar(idUsuario, marcas);
    debugPrint('MARCAS: encolada $marca (${marcas.length} en cola)');
    return marcas;
  }

  /// Saca una marca de la cola por su id local.
  ///
  /// Se llama tanto cuando el servidor la confirma como cuando la rechaza por
  /// una regla: en los dos casos ya no hay nada que reintentar.
  static Future<List<MarcaRuta>> quitar(int idUsuario, int idMarca) async {
    final marcas = await leer(idUsuario);
    marcas.removeWhere((m) => m.id == idMarca);
    await guardar(idUsuario, marcas);
    return marcas;
  }

  /// Reemplaza una marca — se usa para anotarle el intento fallido y el motivo.
  static Future<List<MarcaRuta>> actualizar(
    int idUsuario,
    MarcaRuta marca,
  ) async {
    final marcas = await leer(idUsuario);
    final indice = marcas.indexWhere((m) => m.id == marca.id);
    if (indice == -1) return marcas;
    marcas[indice] = marca;
    await guardar(idUsuario, marcas);
    return marcas;
  }

  /// Siguiente id local. Es `max + 1`, que además garantiza el orden FIFO.
  ///
  /// Se calcula sobre la cola viva, así que después de drenarla vuelve a 1. No
  /// importa: el id no viaja al servidor y solo tiene que ordenar lo que hay.
  static Future<int> siguienteId(int idUsuario) async {
    final marcas = await leer(idUsuario);
    if (marcas.isEmpty) return 1;
    return marcas.map((m) => m.id).reduce((a, b) => a > b ? a : b) + 1;
  }

  static Future<void> limpiar(int idUsuario) async {
    if (idUsuario <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_clave(idUsuario));
    } catch (e) {
      debugPrint('⚠️ No se pudo limpiar la cola de marcas: $e');
    }
  }
}
