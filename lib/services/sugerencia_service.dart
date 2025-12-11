import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/notification_banner.dart';
import '../models/sugerencia.dart';

class SugerenciaService with ChangeNotifier {
  final String baseUrl =
      'https://servicioslsaqas.nutri.com.ec/nutrisoft/rest/app/api/v1/sugerencia';

  List<Sugerencia> _sugerencias = [];
  List<Sugerencia> get sugerencias => _sugerencias;

  // OBTENER TODAS LAS SUGERENCIAS
  Future<List<Sugerencia>> listarSugerencias(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        _sugerencias = data.map((e) => Sugerencia.fromJson(e)).toList();
        notifyListeners();
        return _sugerencias;
      } else {
        throw Exception(
            'Error al obtener sugerencias (${response.statusCode})');
      }
    } catch (e) {
      NotificationBanner.show(
        context,
        'Error al cargar sugerencias: $e',
        NotificationType.error,
      );
      rethrow;
    }
  }

  // CREAR NUEVA SUGERENCIA
  Future<void> crearSugerencia(BuildContext context, Sugerencia nueva) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(nueva.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        NotificationBanner.show(
          context,
          'Sugerencia enviada correctamente',
          NotificationType.success,
        );
        await listarSugerencias(context);
      } else {
        NotificationBanner.show(
          context,
          'Error al crear sugerencia (${response.statusCode})',
          NotificationType.error,
        );
      }
    } catch (e) {
      NotificationBanner.show(
        context,
        'Error de conexión: $e',
        NotificationType.error,
      );
    }
  }

  // ELIMINAR SUGERENCIA
  Future<void> eliminarSugerencia(BuildContext context, String id) async {
    try {
      final url = '$baseUrl/$id';
      final response = await http.delete(Uri.parse(url));

      if (response.statusCode == 200) {
        NotificationBanner.show(
          context,
          'Sugerencia eliminada correctamente',
          NotificationType.success,
        );
        await listarSugerencias(context);
      } else {
        NotificationBanner.show(
          context,
          'Error al eliminar sugerencia (${response.statusCode})',
          NotificationType.error,
        );
      }
    } catch (e) {
      NotificationBanner.show(
        context,
        'Error de conexión: $e',
        NotificationType.error,
      );
    }
  }
}
