import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/beneficio.dart';

class BeneficioService extends ChangeNotifier {
  static const String baseUrl =
      "https://servicioslsa.nutri.com.ec/nutrisoft/rest/app/api/v1/beneficios";

  List<Beneficio> _beneficios = [];
  List<Beneficio> get beneficios => _beneficios;

  // OBTENER TODOS LOS BENEFICIOS
  Future<List<Beneficio>> listar() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final lista = body is List ? body : body['data'] ?? [];
        _beneficios =
            lista.map<Beneficio>((e) => Beneficio.fromJson(e)).toList();
        return _beneficios;
      } else {
        throw Exception("ERROR AL CARGAR BENEFICIOS (${response.statusCode})");
      }
    } catch (e) {
      debugPrint("ERROR OBTENIENDO BENEFICIOS: $e");
      return [];
    }
  }

  // AGREGAR NUEVO BENEFICIO
  Future<bool> agregar(Beneficio beneficio) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(beneficio.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        debugPrint("ERROR AL CREAR BENEFICIO: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("ERROR AGREGANDO BENEFICIO: $e");
      return false;
    }
  }

  // ELIMINAR BENEFICIO
  Future<bool> eliminar(int id) async {
    try {
      final response = await http.delete(Uri.parse("$baseUrl/$id"));
      if (response.statusCode == 200 || response.statusCode == 204) {
        _beneficios.removeWhere((b) => b.id == id);
        notifyListeners();
        return true;
      } else {
        debugPrint("ERROR AL ELIMINAR BENEFICIO (${response.statusCode})");
        return false;
      }
    } catch (e) {
      debugPrint("ERROR ELIMINANDO BENEFICIO: $e");
      return false;
    }
  }
}
