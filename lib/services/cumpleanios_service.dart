import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/notification_banner.dart';
import '../models/cumpleanios.dart';

class CumpleaniosService extends ChangeNotifier {
  static const String baseUrl =
      "https://servicioslsa.nutri.com.ec/nutrisoft/rest/app/api/v1/cumpleanios";

  List<Cumpleanios> _cumpleanios = [];
  List<Cumpleanios> get cumpleanios => _cumpleanios;

  // OBTENER TODOS LOS CUMPLEAÑOS
  Future<List<Cumpleanios>> listarCumpleanios(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final lista = data is List ? data : data['data'] ?? [];
        _cumpleanios =
            lista.map<Cumpleanios>((e) => Cumpleanios.fromText(jsonEncode(e))).toList();
        return _cumpleanios;
      } else {
        throw Exception("Error al obtener cumpleaños (${response.statusCode})");
      }
    } catch (e) {
      NotificationBanner.show(
        context,
        "Error al obtener cumpleaños: $e",
        NotificationType.error,
      );
      rethrow;
    }
  }

  // CREAR NUEVO CUMPLEAÑOS
  Future<void> crearCumpleanio(BuildContext context, Cumpleanios nuevo) async {
    try {
      final body = jsonEncode({
        "nombre": nuevo.nombre,
        "apellido": nuevo.apellido,
        "correo": nuevo.correo,
        "telefono": nuevo.telefono,
        "planta": nuevo.planta,
        "fechaNacimiento": nuevo.fechaNacimiento.toIso8601String(),
      });

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await listarCumpleanios(context);
      } else {
        throw Exception("Error al crear cumpleaños (${response.statusCode})");
      }
    } catch (e) {
      NotificationBanner.show(
        context,
        "Error al crear cumpleaños: $e",
        NotificationType.error,
      );
      rethrow;
    }
  }

  // ELIMINAR CUMPLEAÑOS
  Future<void> eliminarCumpleanio(BuildContext context, int id) async {
    try {
      final response = await http.delete(Uri.parse("$baseUrl/$id"));
      if (response.statusCode == 200) {
        _cumpleanios.removeWhere((c) => c.hashCode == id);
        notifyListeners();
      } else {
        throw Exception("Error al eliminar cumpleaños (${response.statusCode})");
      }
    } catch (e) {
      NotificationBanner.show(
        context,
        "Error al eliminar cumpleaños: $e",
        NotificationType.error,
      );
      rethrow;
    }
  }
}
