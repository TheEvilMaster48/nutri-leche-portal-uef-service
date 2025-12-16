import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/evento.dart';

class EventoService extends ChangeNotifier {
  final List<Evento> _eventos = [];
  List<Evento> get eventos => List.unmodifiable(_eventos);

  static const String baseUrl =
      "https://servicioslsaqas.nutri.com.ec/nutrisoft/rest/appOficial/api/v1";

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

        if (map["appEventoList"] != null &&
            map["appEventoList"] is List &&
            map["appEventoList"].isNotEmpty) {

          final List<dynamic> lista = map["appEventoList"];

          _eventos
            ..clear()
            ..addAll(lista.map((e) => Evento.fromJson(e)));

          notifyListeners();
          debugPrint("EVENTOS RECIBIDOS (${_eventos.length})");
        }
        // SI ESTÁ VACÍO → SILENCIO TOTAL
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
