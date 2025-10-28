import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/calendario_evento.dart';
import '../core/notification_banner.dart';

class CalendarioEventoService extends ChangeNotifier {
  final String _baseUrl =
      'https://servicioslsa.nutri.com.ec/nutrisoft/rest/app/api/v1/calendarioeventos';

  List<CalendarioEvento> _eventos = [];

  List<CalendarioEvento> get eventos => _eventos;

  // OBTENER TODOS LOS EVENTOS DESDE LA API
  Future<void> obtenerEventos(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse(_baseUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _eventos = data.map((e) => CalendarioEvento.fromJson(e)).toList();
        notifyListeners();
      } else {
        throw Exception('Error al obtener eventos (${response.statusCode})');
      }
    } catch (e) {
      NotificationBanner.show(
        context,
        'Error al cargar eventos: $e',
        NotificationType.error,
      );
    }
  }

  // CREAR NUEVO EVENTO
  Future<void> crearEvento(
      BuildContext context, CalendarioEvento evento) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(evento.toJson()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await obtenerEventos(context);
        NotificationBanner.show(
          context,
          '✅ Evento agregado correctamente',
          NotificationType.success,
        );
      } else {
        throw Exception('Error al crear evento (${response.statusCode})');
      }
    } catch (e) {
      NotificationBanner.show(
        context,
        'Error al crear evento: $e',
        NotificationType.error,
      );
    }
  }

  // ELIMINAR EVENTO POR ID
  Future<void> eliminarEvento(BuildContext context, int id) async {
    try {
      final url = '$_baseUrl/$id';
      final response = await http.delete(Uri.parse(url));
      if (response.statusCode == 200) {
        _eventos.removeWhere((e) => e.id == id);
        notifyListeners();
        NotificationBanner.show(
          context,
          '🗑️ Evento eliminado correctamente',
          NotificationType.success,
        );
      } else {
        throw Exception('Error al eliminar evento (${response.statusCode})');
      }
    } catch (e) {
      NotificationBanner.show(
        context,
        'Error al eliminar evento: $e',
        NotificationType.error,
      );
    }
  }

  // ACTUALIZAR EVENTO
  Future<void> actualizarEvento(
      BuildContext context, CalendarioEvento evento) async {
    try {
      final url = '$_baseUrl/${evento.id}';
      final response = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(evento.toJson()),
      );
      if (response.statusCode == 200) {
        await obtenerEventos(context);
        NotificationBanner.show(
          context,
          '✏️ Evento actualizado correctamente',
          NotificationType.success,
        );
      } else {
        throw Exception('Error al actualizar evento (${response.statusCode})');
      }
    } catch (e) {
      NotificationBanner.show(
        context,
        'Error al actualizar evento: $e',
        NotificationType.error,
      );
    }
  }
}
