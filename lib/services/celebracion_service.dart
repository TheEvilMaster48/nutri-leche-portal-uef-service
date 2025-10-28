import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/celebracion.dart';
import '../core/notification_banner.dart';

class CelebracionService with ChangeNotifier {
  final String baseUrl =
      'https://servicioslsa.nutri.com.ec/nutrisoft/rest/app/api/v1/celebraciones';

  List<Celebracion> _celebraciones = [];
  List<Celebracion> get celebraciones => _celebraciones;

  // OBTENER TODAS LAS CELEBRACIONES
  Future<List<Celebracion>> listarCelebraciones() async {
    final response = await http.get(Uri.parse(baseUrl));
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      _celebraciones = data.map((e) => Celebracion.fromJson(e)).toList();
      notifyListeners();
      return _celebraciones;
    } else {
      throw Exception('Error al obtener celebraciones (${response.statusCode})');
    }
  }

  // CREAR NUEVA CELEBRACIÓN
  Future<void> crearCelebracion(BuildContext context, Celebracion nueva) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(nueva.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        NotificationBanner.show(context, 'Celebración creada correctamente', NotificationType.success);
        await listarCelebraciones();
      } else {
        NotificationBanner.show(context, 'Error al crear celebración (${response.statusCode})', NotificationType.error);
      }
    } catch (e) {
      NotificationBanner.show(context, 'Error de conexión: $e', NotificationType.error);
    }
  }

  // ACTUALIZAR CELEBRACIÓN EXISTENTE
  Future<void> actualizarCelebracion(BuildContext context, Celebracion celebracion) async {
    try {
      final url = '$baseUrl/${celebracion.id}';
      final response = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(celebracion.toJson()),
      );

      if (response.statusCode == 200) {
        NotificationBanner.show(context, 'Celebración actualizada correctamente', NotificationType.success);
        await listarCelebraciones();
      } else {
        NotificationBanner.show(context, 'Error al actualizar celebración (${response.statusCode})', NotificationType.error);
      }
    } catch (e) {
      NotificationBanner.show(context, 'Error de conexión: $e', NotificationType.error);
    }
  }

  // ELIMINAR CELEBRACIÓN
  Future<void> eliminarCelebracion(BuildContext context, int id) async {
    try {
      final url = '$baseUrl/$id';
      final response = await http.delete(Uri.parse(url));

      if (response.statusCode == 200) {
        NotificationBanner.show(context, 'Celebración eliminada correctamente', NotificationType.success);
        await listarCelebraciones();
      } else {
        NotificationBanner.show(context, 'Error al eliminar celebración (${response.statusCode})', NotificationType.error);
      }
    } catch (e) {
      NotificationBanner.show(context, 'Error de conexión: $e', NotificationType.error);
    }
  }
}
