import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nutri/base/base.dart';
import '../models/evento.dart';
import 'ocultos_store.dart';

class EventoService extends ChangeNotifier {
  final List<Evento> _eventos = [];
  List<Evento> get eventos => List.unmodifiable(_eventos);

  /// Estado con el que el backend marca un evento eliminado por el usuario.
  static const int estadoEliminado = 2;

  static const String _grupoOcultos = 'eventos';

  late String baseUrl = Base().BASE_URL_APPOFICIAL;

  Future<void> obtenerEventos({required int idUsuario}) async {
    final url = Uri.parse("$baseUrl/ObtenerEventos");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"idUsuario": idUsuario}),
      );

      if (response.statusCode == 200) {
        final map = json.decode(response.body);
        print('appEventoList' + map["appEventoList"].toString());
        if (map["appEventoList"] != null &&
            map["appEventoList"] is List &&
            map["appEventoList"].isNotEmpty) {

          final List<dynamic> lista = map["appEventoList"];

          // El push identifica el evento con `idCabecera`. Este log dice, corto
          // y sin que logcat lo trunque, si el WS manda ese campo.
          final primero = lista.first;
          if (primero is Map) {
            debugPrint('EVENTOS: llaves del WS = ${primero.keys.toList()}');
          }
          debugPrint('EVENTOS: ids (idEvento/idCabecera) = '
              '${lista.whereType<Map>().map((e) => "${e['idEvento']}/${e['idCabecera']}").toList()}');

          // Se descartan los eliminados: por estado (si el backend ya lo
          // marca) y por la lista local de ocultos.
          final ocultos = await OcultosStore.leer(_grupoOcultos, idUsuario);

          _eventos
            ..clear()
            ..addAll(lista
                .map((e) => Evento.fromJson(e))
                .where((e) =>
                    e.estado != estadoEliminado &&
                    !ocultos.contains(e.idEvento)));

          notifyListeners();
          debugPrint("EVENTOS RECIBIDOS (${_eventos.length})");
        } else {
          // La lista se deja como está (comportamiento previo), pero se avisa:
          // un listado vacío explica por sí solo que el deep-link del push no
          // encuentre el evento.
          debugPrint('EVENTOS: el WS no devolvió eventos para idUsuario='
              '$idUsuario → ${map["mensaje"]}');
        }
      } else {
        debugPrint("ERROR HTTP: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("ERROR AL CARGAR EVENTOS: $e");
    }
  }

  Future<void> marcarEventoComoVisto({
    required int idUsuario,
    required int idEvento,
  }) async {
    final url = Uri.parse("$baseUrl/evento_id_visto");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "idUsuario": idUsuario,
          "idEvento": idEvento,
        }),
      );

      if (response.statusCode == 200) {
        final index = _eventos.indexWhere((e) => e.idEvento == idEvento);

        if (index != -1) {
          _eventos[index].estado = 1;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("ERROR HTTP AL MARCAR EVENTO COMO VISTO: $e");
    }
  }

  /// Elimina el evento de la lista de notificaciones del usuario.
  ///
  /// Endpoint pendiente en el backend: `eliminar_evento`, con el mismo
  /// contrato que `evento_id_visto`, cambiando el estado del registro a
  /// [estadoEliminado] para ese usuario.
  ///
  /// Se quita de la lista de inmediato (optimista) y se guarda en los ocultos
  /// locales; si el POST falla devuelve `false` para que la pantalla avise que
  /// no se pudo sincronizar, pero la tarjeta no reaparece.
  Future<bool> eliminarEvento({
    required int idUsuario,
    required int idEvento,
  }) async {
    final index = _eventos.indexWhere((e) => e.idEvento == idEvento);
    if (index != -1) {
      _eventos.removeAt(index);
      notifyListeners();
    }

    await OcultosStore.agregar(_grupoOcultos, idUsuario, idEvento);

    final url = Uri.parse("$baseUrl/eliminar_evento");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "idUsuario": idUsuario,
          "idEvento": idEvento,
          "estado": estadoEliminado,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint("ELIMINAR EVENTO: HTTP ${response.statusCode}");
        return false;
      }

      return true;
    } catch (e) {
      debugPrint("ERROR HTTP AL ELIMINAR EVENTO: $e");
      return false;
    }
  }

  void agregarDesdeWs(Map<String, dynamic> data) {
    try {
      final nuevo = Evento.fromJson(data);

      if (_eventos.any((e) => e.idEvento == nuevo.idEvento)) return;

      _eventos.insert(0, nuevo);
      notifyListeners();

      debugPrint("EVENTO RECIBIDO VIA WS: ${nuevo.titulo}");
    } catch (e) {
      debugPrint("ERROR AL PROCESAR EVENTO WS: $e");
    }
  }

  void limpiar() {
    _eventos.clear();
    notifyListeners();
  }
}
