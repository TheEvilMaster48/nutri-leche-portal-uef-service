import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/calendario_evento.dart';
import '../models/cumpleanios.dart';

class CalendarioEventoService extends ChangeNotifier {
  final List<CalendarioEvento> _eventos = [];
  final List<Cumpleanios> _cumpleanios = [];

  List<CalendarioEvento> get eventos => _eventos;
  List<Cumpleanios> get cumpleanios => _cumpleanios;

  final String _baseUrl =
      'https://servicioslsa.nutri.com.ec/nutrisoft/rest/appOficial/api/v1';

  // OBTENER EVENTOS
  Future<void> obtenerEventos() async {
    final url = Uri.parse('$_baseUrl/ObtenerEventos');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"idUsuario": 1856}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['correcto'] == true && data['appEventoList'] is List) {
          final lista = data['appEventoList'] as List;
          _eventos
            ..clear()
            ..addAll(lista.map((e) => CalendarioEvento.fromJson(e)).toList());
          debugPrint('✅ EVENTOS CARGADOS: ${_eventos.length}');
        } else {
          debugPrint('⚠️ SIN EVENTOS O FORMATO INCORRECTO');
        }
      } else {
        debugPrint('⚠️ ERROR HTTP EVENTOS: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ ERROR AL CARGAR EVENTOS: $e');
    }
  }

  // OBTENER CUMPLEAÑOS
  Future<void> obtenerCumpleanos() async {
    final url = Uri.parse('$_baseUrl/ObtenerCumpleanos');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"idUsuario": 1856}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['correcto'] == true && data['appEventoList'] is List) {
          final lista = data['appEventoList'] as List;
          _cumpleanios
            ..clear()
            ..addAll(lista.map((e) => Cumpleanios.fromJson(e)).toList());
          debugPrint('🎂 CUMPLEAÑOS CARGADOS: ${_cumpleanios.length}');
        } else {
          debugPrint('⚠️ SIN CUMPLEAÑOS O FORMATO INCORRECTO');
        }
      } else {
        debugPrint('⚠️ ERROR HTTP CUMPLEAÑOS: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ ERROR AL CARGAR CUMPLEAÑOS: $e');
    }
  }

  // CARGAR TODO
  Future<void> cargarTodo(BuildContext context) async {
    await Future.wait([
      obtenerEventos(),
      obtenerCumpleanos(),
    ]);
    notifyListeners();
  }
}