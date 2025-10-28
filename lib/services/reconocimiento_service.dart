import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/reconocimiento.dart';
import '../models/usuario.dart';

class ReconocimientoService extends ChangeNotifier {
  List<Reconocimiento> _reconocimientos = [];
  List<Reconocimiento> get reconocimientos => _reconocimientos;

  static const String baseUrl =
      "https://servicioslsa.nutri.com.ec/nutrisoft/rest/app/api/v1/reconocimiento";

  // OBTENER TODOS LOS RECONOCIMIENTOS
  Future<void> obtenerReconocimientos() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final lista = data is List ? data : data['data'] ?? [];

        _reconocimientos =
            lista.map<Reconocimiento>((e) => Reconocimiento.fromJson(e)).toList();
        notifyListeners();
      } else {
        throw Exception("Error al cargar reconocimientos (${response.statusCode})");
      }
    } catch (e) {
      debugPrint("ERROR OBTENIENDO RECONOCIMIENTOS: $e");
      rethrow;
    }
  }

  // CREAR UN NUEVO RECONOCIMIENTO
  Future<void> crearReconocimiento(
      Reconocimiento nuevo, Usuario usuarioActual) async {
    try {
      final body = jsonEncode({
        "titulo": nuevo.titulo,
        "descripcion": nuevo.descripcion,
        "autor": usuarioActual.nombre,
        "otorgadoA": nuevo.otorgadoA,
        "departamento": usuarioActual.areaUsuario,
        "tipo": nuevo.tipo,
        "fecha": nuevo.fecha.toIso8601String(),
        "archivos": nuevo.archivos,
      });

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await obtenerReconocimientos();
      } else {
        throw Exception(
            "Error al crear reconocimiento (${response.statusCode})");
      }
    } catch (e) {
      debugPrint("ERROR CREANDO RECONOCIMIENTO: $e");
      rethrow;
    }
  }

  // MODIFICAR RECONOCIMIENTO
  Future<void> modificarReconocimiento(
      String id, Reconocimiento actualizado, Usuario usuarioActual) async {
    try {
      final body = jsonEncode({
        "titulo": actualizado.titulo,
        "descripcion": actualizado.descripcion,
        "autor": usuarioActual.nombre,
        "otorgadoA": actualizado.otorgadoA,
        "departamento": usuarioActual.areaUsuario,
        "tipo": actualizado.tipo,
        "fecha": actualizado.fecha.toIso8601String(),
        "archivos": actualizado.archivos,
      });

      final response = await http.put(
        Uri.parse("$baseUrl/$id"),
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        await obtenerReconocimientos();
      } else {
        throw Exception(
            "Error al actualizar reconocimiento (${response.statusCode})");
      }
    } catch (e) {
      debugPrint("ERROR MODIFICANDO RECONOCIMIENTO: $e");
      rethrow;
    }
  }

  // ELIMINAR RECONOCIMIENTO
  Future<void> eliminarReconocimiento(String id) async {
    try {
      final response = await http.delete(Uri.parse("$baseUrl/$id"));

      if (response.statusCode == 200) {
        _reconocimientos.removeWhere((r) => r.id.toString() == id);
        notifyListeners();
      } else {
        throw Exception(
            "Error al eliminar reconocimiento (${response.statusCode})");
      }
    } catch (e) {
      debugPrint("ERROR ELIMINANDO RECONOCIMIENTO: $e");
      rethrow;
    }
  }
}
