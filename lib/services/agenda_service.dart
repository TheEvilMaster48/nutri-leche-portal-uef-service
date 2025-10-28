import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/agenda.dart';
import '../models/usuario.dart';

class AgendaService extends ChangeNotifier {
  List<Agenda> _citas = [];
  List<Agenda> get citas => _citas;

  // 🔗 Endpoint base del backend
  static const String baseUrl =
      "https://servicioslsa.nutri.com.ec/nutrisoft/rest/app/api/v1/agenda";

  // OBTENER TODAS LAS CITAS
  Future<void> obtenerCitas() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final lista = data is List ? data : data['data'] ?? [];

        _citas = lista.map<Agenda>((e) => Agenda.fromJson(e)).toList();
        notifyListeners();
      } else {
        throw Exception("Error al cargar citas (${response.statusCode})");
      }
    } catch (e) {
      debugPrint("❌ Error obteniendo citas: $e");
      rethrow;
    }
  }

  
  // CREAR UNA NUEVA CITA
  Future<void> crearCita(Agenda nuevaCita, Usuario usuarioActual) async {
    try {
      final body = jsonEncode({
        "titulo": nuevaCita.titulo,
        "descripcion": nuevaCita.descripcion,
        "fecha": nuevaCita.fecha.toIso8601String(),
        "horaInicio": nuevaCita.horaInicio,
        "horaFin": nuevaCita.horaFin,
        "recordatorio": nuevaCita.recordatorio,
        "creadoPor": usuarioActual.nombre,
        "planta": usuarioActual.areaUsuario,
      });

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await obtenerCitas();
      } else {
        throw Exception("Error al crear cita (${response.statusCode})");
      }
    } catch (e) {
      debugPrint("❌ Error creando cita: $e");
      rethrow;
    }
  }


  // MODIFICAR CITA EXISTENTE
  Future<void> modificarCita(
      String id, Agenda citaActualizada, Usuario usuarioActual) async {
    try {
      final body = jsonEncode({
        "titulo": citaActualizada.titulo,
        "descripcion": citaActualizada.descripcion,
        "fecha": citaActualizada.fecha.toIso8601String(),
        "horaInicio": citaActualizada.horaInicio,
        "horaFin": citaActualizada.horaFin,
        "recordatorio": citaActualizada.recordatorio,
        "actualizadoPor": usuarioActual.nombre,
        "planta": usuarioActual.areaUsuario,
      });

      final response = await http.put(
        Uri.parse("$baseUrl/$id"),
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        await obtenerCitas();
      } else {
        throw Exception("Error al actualizar cita (${response.statusCode})");
      }
    } catch (e) {
      debugPrint("❌ Error modificando cita: $e");
      rethrow;
    }
  }


  // ELIMINAR CITA POR ID
  Future<void> eliminarCita(String id) async {
    try {
      final response = await http.delete(Uri.parse("$baseUrl/$id"));

      if (response.statusCode == 200) {
        _citas.removeWhere((a) => a.id.toString() == id);
        notifyListeners();
      } else {
        throw Exception("Error al eliminar cita (${response.statusCode})");
      }
    } catch (e) {
      debugPrint("❌ Error eliminando cita: $e");
      rethrow;
    }
  }
}
