import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/evento.dart';
import '../models/usuario.dart';

class EventoService extends ChangeNotifier {
  List<Evento> _eventos = [];
  List<Evento> get eventos => _eventos;

  static const String baseUrl =
      "https://servicioslsa.nutri.com.ec/nutrisoft/rest/app/api/v1/eventos";

  // Obtener Todos los Eventos (Backend UEF Services)
  Future<void> obtenerEventos() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final lista = data is List ? data : data['data'] ?? [];
        _eventos = lista.map<Evento>((e) => Evento.fromJson(e)).toList();
        notifyListeners();
      } else {
        throw Exception("Error al cargar eventos (${response.statusCode})");
      }
    } catch (e) {
      debugPrint("❌ Error obteniendo eventos: $e");
      rethrow;
    }
  }

  //  Crear Evento
  Future<void> crearEvento(Evento nuevoEvento, Usuario usuarioActual) async {
    try {
      final body = jsonEncode({
        "titulo": nuevoEvento.titulo,
        "descripcion": nuevoEvento.descripcion,
        "fecha": nuevoEvento.fecha,
        "creadoPor": usuarioActual.nombre,
        "planta": usuarioActual.areaUsuario,
        "horaEvento": nuevoEvento.horaEvento,
        "imagenPath": nuevoEvento.imagenPath ?? "",
        "archivoPath": nuevoEvento.archivoPath ?? "",
      });

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await obtenerEventos();
      } else {
        throw Exception("Error al crear evento (${response.statusCode})");
      }
    } catch (e) {
      debugPrint("❌ Error creando evento: $e");
      rethrow;
    }
  }

  //  Editar Evento Existente
  Future<void> modificarEvento(
      String id, Evento eventoActualizado, Usuario usuarioActual) async {
    try {
      final body = jsonEncode({
        "titulo": eventoActualizado.titulo,
        "descripcion": eventoActualizado.descripcion,
        "fecha": eventoActualizado.fecha,
        "creadoPor": usuarioActual.nombre,
        "planta": usuarioActual.areaUsuario,
        "horaEvento": eventoActualizado.horaEvento,
        "imagenPath": eventoActualizado.imagenPath ?? "",
        "archivoPath": eventoActualizado.archivoPath ?? "",
      });

      final response = await http.put(
        Uri.parse("$baseUrl/$id"),
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        await obtenerEventos();
      } else {
        throw Exception("Error al actualizar evento (${response.statusCode})");
      }
    } catch (e) {
      debugPrint("❌ Error modificando evento: $e");
      rethrow;
    }
  }

  // Eliminar Evento
  Future<void> eliminarEvento(String id) async {
    try {
      final response = await http.delete(Uri.parse("$baseUrl/$id"));
      if (response.statusCode == 200) {
        _eventos.removeWhere((e) => e.id == id);
        notifyListeners();
      } else {
        throw Exception("Error al eliminar evento (${response.statusCode})");
      }
    } catch (e) {
      debugPrint("❌ Error eliminando evento: $e");
      rethrow;
    }
  }
}
