import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/sorteo.dart';

class SorteoService extends ChangeNotifier {
  final List<Sorteo> _sorteos = [];
  List<Sorteo> get sorteos => List.unmodifiable(_sorteos);

  static const String baseUrl =
      "https://servicioslsa.nutri.com.ec/nutrisoft/rest/appOficial/api/v1";

  Future<void> obtenerSorteos({required int idUsuario}) async {
    final url = Uri.parse("$baseUrl/ObtenerSorteo");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"idUsuario": idUsuario}),
      );

      if (response.statusCode == 200) {
        final map = json.decode(response.body);

        if (map["data"] != null) {
          final decoded = json.decode(map["data"]);

          _sorteos
            ..clear()
            ..add(Sorteo.fromJson(decoded));

          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("ERROR AL CARGAR SORTEOS: $e");
    }
  }

  Future<void> marcarSorteoComoRegistro({
    required int idUsuario,
    required int idSorteo,
  }) async {
    final url = Uri.parse("$baseUrl/registro_sorteo");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "idUsuario": idUsuario,
          "idSorteo": idSorteo,
        }),
      );

      if (response.statusCode == 200) {
        final index = _sorteos.indexWhere((s) => s.id == idSorteo);
        if (index != -1) {
          notifyListeners();
        }
      }
    } catch (e) {}
  }

  void agregarDesdeWs(Map<String, dynamic> data) {
    try {
      final nuevo = Sorteo.fromJson(data);
      if (_sorteos.any((s) => s.id == nuevo.id)) return;
      _sorteos.insert(0, nuevo);
      notifyListeners();
    } catch (e) {}
  }

  void limpiar() {
    _sorteos.clear();
    notifyListeners();
  }
}
