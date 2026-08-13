import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nutri/base/base.dart';
import '../models/nutrisoft.dart';

/// Misma lógica que [EventoService], pero contra el REST **appMensaje**.
///
/// Ojo: este módulo NO usa `BASE_URL_APPOFICIAL` como el resto de la app; los
/// mensajes de Nutrisoft viven en su propio REST (`appMensaje/api/v1`).
///
///   POST $BASE_URL_APPMENSAJE/ObtenerMensajes
///        { idUsuario }
///        → { correcto, mensaje, appMensajeList: [ { idMensaje, titulo, descripcion, visto } ] }
///          (`visto`: 0 = no visto, 1 = visto)
///
///   POST $BASE_URL_APPMENSAJE/mensaje_visto
///        { idUsuario, idMensaje }
///        → { correcto: true, mensaje: "Mensaje marcado como visto" }
///
///   POST $BASE_URL_APPMENSAJE/eliminar_mensaje   ← pendiente en el backend
///        { idUsuario, idMensaje, estado: 2 }
///
/// Si los nombres cambian, basta ajustar las constantes de ruta de abajo.
class NutrisoftService extends ChangeNotifier {
  static const String rutaLista = 'ObtenerMensajes';
  static const String rutaVisto = 'mensaje_visto';
  static const String rutaEliminar = 'eliminar_mensaje';

  /// Clave del arreglo dentro de la respuesta de [rutaLista].
  static const String claveLista = 'appMensajeList';

  /// Estado con el que el backend marca un registro eliminado por el usuario.
  static const int estadoEliminado = 2;

  final List<Nutrisoft> _items = [];
  List<Nutrisoft> get items => List.unmodifiable(_items);

  late String baseUrl = Base().BASE_URL_APPMENSAJE;

  Future<void> obtenerNutrisoft({required int idUsuario}) async {
    final url = Uri.parse("$baseUrl/$rutaLista");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"idUsuario": idUsuario}),
      );

      if (response.statusCode == 200) {
        final map = json.decode(response.body);

        if (map[claveLista] != null &&
            map[claveLista] is List &&
            map[claveLista].isNotEmpty) {
          final List<dynamic> lista = map[claveLista];

          // Sin filtro local: lo que el backend devuelve es lo que se muestra.
          // Los eliminados los deja de devolver `ObtenerMensajes`.
          _items
            ..clear()
            ..addAll(lista.map((e) => Nutrisoft.fromJson(e)));

          notifyListeners();
          debugPrint("NUTRISOFT RECIBIDOS (${_items.length})");
        }
        // SI ESTÁ VACÍO → SILENCIO TOTAL
      } else {
        debugPrint("NUTRISOFT: ERROR HTTP ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("ERROR AL CARGAR NUTRISOFT: $e");
    }
  }

  Future<void> marcarComoVisto({
    required int idUsuario,
    required int idMensaje,
  }) async {
    final url = Uri.parse("$baseUrl/$rutaVisto");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "idUsuario": idUsuario,
          "idMensaje": idMensaje,
        }),
      );

      if (response.statusCode == 200) {
        final index = _items.indexWhere((e) => e.idMensaje == idMensaje);

        if (index != -1) {
          _items[index].visto = 1;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("ERROR HTTP AL MARCAR NUTRISOFT COMO VISTO: $e");
    }
  }

  /// Elimina el registro de la lista de notificaciones del usuario.
  ///
  /// El borrado lo manda el backend: aquí NO se guarda nada en caché local. La
  /// tarjeta se quita de inmediato para que la UI responda, pero si el POST
  /// falla se devuelve a su posición y se retorna `false`, de modo que lo que
  /// se ve siempre sea lo que el servidor tiene.
  Future<bool> eliminarNutrisoft({
    required int idUsuario,
    required int idMensaje,
  }) async {
    final index = _items.indexWhere((e) => e.idMensaje == idMensaje);
    final Nutrisoft? removido = index != -1 ? _items[index] : null;

    if (removido != null) {
      _items.removeAt(index);
      notifyListeners();
    }

    final url = Uri.parse("$baseUrl/$rutaEliminar");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "idUsuario": idUsuario,
          "idMensaje": idMensaje,
          "estado": estadoEliminado,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint("ELIMINAR NUTRISOFT: HTTP ${response.statusCode}");
        _restaurar(removido, index);
        return false;
      }

      return true;
    } catch (e) {
      debugPrint("ERROR HTTP AL ELIMINAR NUTRISOFT: $e");
      _restaurar(removido, index);
      return false;
    }
  }

  /// Devuelve a la lista una tarjeta que se quitó de forma optimista pero cuyo
  /// borrado el backend no confirmó.
  void _restaurar(Nutrisoft? item, int index) {
    if (item == null) return;
    _items.insert(index.clamp(0, _items.length), item);
    notifyListeners();
  }

  void agregarDesdeWs(Map<String, dynamic> data) {
    try {
      final nuevo = Nutrisoft.fromJson(data);

      if (_items.any((e) => e.idMensaje == nuevo.idMensaje)) return;

      _items.insert(0, nuevo);
      notifyListeners();

      debugPrint("NUTRISOFT RECIBIDO VIA WS: ${nuevo.titulo}");
    } catch (e) {
      debugPrint("ERROR AL PROCESAR NUTRISOFT WS: $e");
    }
  }

  /// Descarta los mensajes cargados. Se llama al cerrar sesión: el provider
  /// sobrevive al logout y si no, el siguiente usuario vería los del anterior.
  void limpiar() {
    _items.clear();
    notifyListeners();
  }
}
