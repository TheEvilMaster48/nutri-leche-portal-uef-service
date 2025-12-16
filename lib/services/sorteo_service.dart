import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
    } catch (e) {}
  }

  Future<void> guardarRegistroLocal(int idUsuario, int idSorteo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("sorteo_${idUsuario}_$idSorteo", true);
  }

  Future<bool> verificarRegistroLocal(int idUsuario, int idSorteo) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool("sorteo_${idUsuario}_$idSorteo") ?? false;
  }

  Future<Map<String, dynamic>> marcarSorteoComoRegistro({
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
        final jsonResp = json.decode(response.body);
        await guardarRegistroLocal(idUsuario, idSorteo);
        return jsonResp;
      }
    } catch (e) {}

    return {"correcto": false};
  }

  void agregarDesdeWs(Map<String, dynamic> data) {
    try {
      notifyListeners();
    } catch (e) {}
  }

  void limpiar() {
    _sorteos.clear();
    notifyListeners();
  }
}
