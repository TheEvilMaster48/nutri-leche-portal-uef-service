import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/beneficio.dart';
import '../models/usuario.dart';

class BeneficioService extends ChangeNotifier {
  List<Beneficio> _beneficios = [];
  List<Beneficio> get beneficios => _beneficios;

  static const String baseUrl =
      "https://servicioslsa.nutri.com.ec/nutrisoft/rest/app/api/v1/beneficios";

  // OBTENER TODOS LOS BENEFICIOS
  Future<void> obtenerBeneficios() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final lista = data is List ? data : data['data'] ?? [];
        _beneficios = lista.map<Beneficio>((e) => Beneficio.fromJson(e)).toList();
        notifyListeners();
      } else {
        throw Exception("Error al cargar beneficios (${response.statusCode})");
      }
    } catch (e) {
      debugPrint("ERROR OBTENIENDO BENEFICIOS: $e");
      rethrow;
    }
  }

  // CREAR BENEFICIO
  Future<void> crearBeneficio(Beneficio nuevo, Usuario usuarioActual) async {
    try {
      final body = jsonEncode({
        "nombre": nuevo.nombre,
        "descripcion": nuevo.descripcion,
        "tipo": nuevo.tipo,
        "categoria": nuevo.categoria,
        "imagenUrl": nuevo.imagenUrl,
        "fechaPublicacion": nuevo.fechaPublicacion,
        "activo": nuevo.activo,
        "creadoPor": usuarioActual.nombre,
        "planta": usuarioActual.areaUsuario,
      });

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await obtenerBeneficios();
      } else {
        throw Exception("Error al crear beneficio (${response.statusCode})");
      }
    } catch (e) {
      debugPrint("ERROR CREANDO BENEFICIO: $e");
      rethrow;
    }
  }

  // MODIFICAR BENEFICIO
  Future<void> modificarBeneficio(
      String id, Beneficio actualizado, Usuario usuarioActual) async {
    try {
      final body = jsonEncode({
        "nombre": actualizado.nombre,
        "descripcion": actualizado.descripcion,
        "tipo": actualizado.tipo,
        "categoria": actualizado.categoria,
        "imagenUrl": actualizado.imagenUrl,
        "fechaPublicacion": actualizado.fechaPublicacion,
        "activo": actualizado.activo,
        "actualizadoPor": usuarioActual.nombre,
        "planta": usuarioActual.areaUsuario,
      });

      final response = await http.put(
        Uri.parse("$baseUrl/$id"),
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        await obtenerBeneficios();
      } else {
        throw Exception("Error al actualizar beneficio (${response.statusCode})");
      }
    } catch (e) {
      debugPrint("ERROR MODIFICANDO BENEFICIO: $e");
      rethrow;
    }
  }

  // ELIMINAR BENEFICIO
  Future<void> eliminarBeneficio(String id) async {
    try {
      final response = await http.delete(Uri.parse("$baseUrl/$id"));
      if (response.statusCode == 200) {
        _beneficios.removeWhere((b) => b.id.toString() == id);
        notifyListeners();
      } else {
        throw Exception("Error al eliminar beneficio (${response.statusCode})");
      }
    } catch (e) {
      debugPrint("ERROR ELIMINANDO BENEFICIO: $e");
      rethrow;
    }
  }
}
