import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ids que el usuario eliminó de sus listas de notificaciones.
///
/// El borrado real vive en el backend (se envía un POST que cambia el estado),
/// pero mientras el WS siga devolviendo el registro en `ObtenerEventos` /
/// `ObtenerCumpleanos` haría reaparecer la tarjeta en el siguiente refresh. Se
/// guarda entonces la lista local por usuario y se filtra al cargar.
///
/// Se separa por [idUsuario] porque un mismo teléfono puede usarse con varias
/// cuentas y lo eliminado es personal.
class OcultosStore {
  OcultosStore._();

  static String _clave(String grupo, int idUsuario) =>
      'ocultos_${grupo}_$idUsuario';

  static Future<Set<int>> leer(String grupo, int idUsuario) async {
    if (idUsuario <= 0) return <int>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      final lista = prefs.getStringList(_clave(grupo, idUsuario)) ?? const [];
      return lista
          .map((e) => int.tryParse(e) ?? 0)
          .where((e) => e > 0)
          .toSet();
    } catch (e) {
      debugPrint('⚠️ No se pudieron leer los ocultos de $grupo: $e');
      return <int>{};
    }
  }

  static Future<void> agregar(String grupo, int idUsuario, int id) async {
    if (idUsuario <= 0 || id <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final clave = _clave(grupo, idUsuario);
      final lista = prefs.getStringList(clave) ?? <String>[];
      if (!lista.contains(id.toString())) {
        lista.add(id.toString());
        await prefs.setStringList(clave, lista);
      }
    } catch (e) {
      debugPrint('⚠️ No se pudo guardar el oculto de $grupo: $e');
    }
  }

  static Future<void> quitar(String grupo, int idUsuario, int id) async {
    if (idUsuario <= 0 || id <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final clave = _clave(grupo, idUsuario);
      final lista = prefs.getStringList(clave) ?? <String>[];
      lista.remove(id.toString());
      await prefs.setStringList(clave, lista);
    } catch (e) {
      debugPrint('⚠️ No se pudo quitar el oculto de $grupo: $e');
    }
  }
}
