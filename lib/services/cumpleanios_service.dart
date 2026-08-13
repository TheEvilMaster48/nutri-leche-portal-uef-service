import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../base/base.dart';
import '../models/cumpleanios.dart';
import 'ocultos_store.dart';

class CumpleaniosService extends ChangeNotifier {
  final List<Cumpleanios> _cumpleanios = [];
  List<Cumpleanios> get cumpleanios => List.unmodifiable(_cumpleanios);

  /// Estado con el que el backend marca un cumpleaños eliminado por el usuario.
  static const int estadoEliminado = 2;

  static const String _grupoOcultos = 'cumpleanios';

  late String baseUrl = Base().BASE_URL_APPOFICIAL;

  Future<void> obtenerCumpleanios({required int idUsuario}) async {
    final url = Uri.parse("$baseUrl/ObtenerCumpleanos");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"idUsuario": idUsuario}),
      );

      if (response.statusCode == 200) {
        final map = json.decode(response.body);

        if (map["appEventoList"] != null &&
            map["appEventoList"] is List &&
            map["appEventoList"].isNotEmpty) {

          final List<dynamic> lista = map["appEventoList"];

          // Se descartan los eliminados: por estado (si el backend ya lo
          // marca) y por la lista local de ocultos.
          final ocultos = await OcultosStore.leer(_grupoOcultos, idUsuario);

          _cumpleanios
            ..clear()
            ..addAll(lista
                .map((e) => Cumpleanios.fromJson(e))
                .where((c) =>
                    c.estado != estadoEliminado &&
                    !ocultos.contains(c.idCumpleanios)));

          notifyListeners();
          debugPrint(lista.toString());
          debugPrint("CUMPLEAÑOS RECIBIDOS (${_cumpleanios.length})");
        }
        // SI ESTÁ VACÍO → NO IMPRIME NADA
      } else {
        debugPrint("ERROR HTTP: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("ERROR AL CARGAR CUMPLEAÑOS: $e");
    }
  }

  Future<void> marcarCumpleaniosComoVisto({
    required int idUsuario,
    required int idCumpleanios,
  }) async {
    final url = Uri.parse("$baseUrl/evento_id_visto");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "idUsuario": idUsuario,
          "idEvento": idCumpleanios,
        }),
      );

      if (response.statusCode == 200) {
        final index =
            _cumpleanios.indexWhere((c) => c.idCumpleanios == idCumpleanios);

        if (index != -1) {
          _cumpleanios[index].estado = 1;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("ERROR HTTP AL MARCAR CUMPLEAÑOS COMO VISTO: $e");
    }
  }

  /// Elimina el cumpleaños de la lista de notificaciones del usuario.
  ///
  /// Endpoint pendiente en el backend: `eliminar_evento` (la misma ruta que
  /// comparte con eventos, igual que `evento_id_visto`), cambiando el estado
  /// del registro a [estadoEliminado] para ese usuario.
  Future<bool> eliminarCumpleanios({
    required int idUsuario,
    required int idCumpleanios,
  }) async {
    final index =
        _cumpleanios.indexWhere((c) => c.idCumpleanios == idCumpleanios);
    if (index != -1) {
      _cumpleanios.removeAt(index);
      notifyListeners();
    }

    await OcultosStore.agregar(_grupoOcultos, idUsuario, idCumpleanios);

    final url = Uri.parse("$baseUrl/eliminar_evento");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "idUsuario": idUsuario,
          "idEvento": idCumpleanios,
          "estado": estadoEliminado,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint("ELIMINAR CUMPLEAÑOS: HTTP ${response.statusCode}");
        return false;
      }

      return true;
    } catch (e) {
      debugPrint("ERROR HTTP AL ELIMINAR CUMPLEAÑOS: $e");
      return false;
    }
  }

  void agregarDesdeWs(Map<String, dynamic> data) {
    try {
      final nuevo = Cumpleanios.fromJson(data);

      if (_cumpleanios.any((c) => c.idCumpleanios == nuevo.idCumpleanios)) return;

      _cumpleanios.insert(0, nuevo);
      notifyListeners();

      debugPrint("CUMPLEAÑOS RECIBIDO VIA WS: ${nuevo.titulo}");
    } catch (e) {
      debugPrint("ERROR AL PROCESAR CUMPLEAÑOS WS: $e");
    }
  }

  void limpiar() {
    _cumpleanios.clear();
    notifyListeners();
  }
}
