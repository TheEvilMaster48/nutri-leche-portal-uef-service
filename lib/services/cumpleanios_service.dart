import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/cumpleanios.dart';

class CumpleaniosService extends ChangeNotifier {
  final List<Cumpleanios> _cumpleanios = [];
  List<Cumpleanios> get cumpleanios => List.unmodifiable(_cumpleanios);

  static const String baseUrl =
      "https://servicioslsaqas.nutri.com.ec/nutrisoft/rest/appOficial/api/v1";

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

          _cumpleanios
            ..clear()
            ..addAll(lista.map((e) => Cumpleanios.fromJson(e)));

          notifyListeners();
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
    final url = Uri.parse("$baseUrl/cumpleanios_id_visto");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "idUsuario": idUsuario,
          "idCumpleanios": idCumpleanios,
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
