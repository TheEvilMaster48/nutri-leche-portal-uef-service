import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../models/calendario_evento.dart';
import '../models/cumpleanios.dart';
import '../services/auth_service.dart';

class CalendarioEventoService extends ChangeNotifier {
  final List<CalendarioEvento> _eventos = [];
  final List<Cumpleanios> _cumpleanios = [];

  List<CalendarioEvento> get eventos => _eventos;
  List<Cumpleanios> get cumpleanios => _cumpleanios;

  final String _baseUrl =
      'https://servicioslsaqas.nutri.com.ec/nutrisoft/rest/appOficial/api/v1';

  // OBTENER EVENTOS DEL USUARIO LOGUEADO
  Future<void> obtenerEventos(BuildContext context) async {
    final auth = context.read<AuthService>();
    final usuario = auth.currentUser;
    final idUsuario = usuario?.id ?? 0;

    if (idUsuario == 0) {
      debugPrint('⚠️ NO HAY USUARIO LOGUEADO PARA CARGAR EVENTOS');
      return;
    }

    final url = Uri.parse('$_baseUrl/ObtenerEventos');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"idUsuario": idUsuario}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['correcto'] == true && data['appEventoList'] is List) {
          final lista = data['appEventoList'] as List;

          _eventos
            ..clear()
            ..addAll(lista.map((e) => CalendarioEvento.fromJson(e)).toList());

          debugPrint('✅ EVENTOS CARGADOS (${idUsuario}): ${_eventos.length}');
        } else {
          debugPrint('⚠️ SIN EVENTOS PARA ESTE USUARIO');
        }
      } else {
        debugPrint('⚠️ ERROR HTTP EVENTOS: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ ERROR AL CARGAR EVENTOS: $e');
    }
  }

  // OBTENER CUMPLEAÑOS DEL USUARIO LOGUEADO
  Future<void> obtenerCumpleanos(BuildContext context) async {
    final auth = context.read<AuthService>();
    final usuario = auth.currentUser;
    final idUsuario = usuario?.id ?? 0;

    if (idUsuario == 0) {
      debugPrint('⚠️ NO HAY USUARIO LOGUEADO PARA CARGAR CUMPLEAÑOS');
      return;
    }

    final url = Uri.parse('$_baseUrl/ObtenerCumpleanos');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"idUsuario": idUsuario}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['correcto'] == true && data['appEventoList'] is List) {
          final lista = data['appEventoList'] as List;

          _cumpleanios
            ..clear()
            ..addAll(lista.map((e) => Cumpleanios.fromJson(e)).toList());

          debugPrint(
              '🎂 CUMPLEAÑOS CARGADOS (${idUsuario}): ${_cumpleanios.length}');
        } else {
          debugPrint('⚠️ SIN CUMPLEAÑOS PARA ESTE USUARIO');
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
      obtenerEventos(context),
      obtenerCumpleanos(context),
    ]);

    notifyListeners();
  }
}
