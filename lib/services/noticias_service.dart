import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/noticias.dart';

class NoticiasService extends ChangeNotifier {
  List<Noticia> _noticias = [];
  List<Noticia> get noticias => _noticias;

  static const String baseUrl =
      "https://servicioslsa.nutri.com.ec/nutrisoft/rest/app/api/v1/noticias";

  // OBTENER TODAS LAS NOTICIAS
  Future<void> obtenerNoticias() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final lista = data is List ? data : data['data'] ?? [];
        _noticias = lista.map<Noticia>((e) => Noticia.fromJson(e)).toList();
        notifyListeners();
        debugPrint("✅ NOTICIAS CARGADAS CORRECTAMENTE (${_noticias.length}).");
      } else {
        debugPrint("⚠️ ERROR AL CARGAR NOTICIAS (${response.statusCode}).");
      }
    } catch (e) {
      debugPrint("❌ EXCEPCIÓN AL OBTENER NOTICIAS: $e");
    }
  }

  // CREAR UNA NUEVA NOTICIA
  Future<void> crearNoticia(Noticia noticia) async {
    try {
      final body = jsonEncode(noticia.toJson());
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("✅ NOTICIA CREADA CORRECTAMENTE.");
        await obtenerNoticias();
      } else {
        debugPrint("⚠️ ERROR AL CREAR NOTICIA (${response.statusCode}).");
      }
    } catch (e) {
      debugPrint("❌ EXCEPCIÓN AL CREAR NOTICIA: $e");
    }
  }

  // ACTUALIZAR NOTICIA EXISTENTE
  Future<void> actualizarNoticia(Noticia noticia) async {
    try {
      final body = jsonEncode(noticia.toJson());
      final response = await http.put(
        Uri.parse("$baseUrl/${noticia.id}"),
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        final index = _noticias.indexWhere((n) => n.id == noticia.id);
        if (index != -1) {
          _noticias[index] = noticia;
        }
        notifyListeners();
        debugPrint("📝 NOTICIA ACTUALIZADA CORRECTAMENTE.");
      } else {
        debugPrint("⚠️ ERROR AL ACTUALIZAR NOTICIA (${response.statusCode}).");
      }
    } catch (e) {
      debugPrint("❌ EXCEPCIÓN AL ACTUALIZAR NOTICIA: $e");
    }
  }

  // ELIMINAR NOTICIA
  Future<void> eliminarNoticia(String id) async {
    try {
      final response = await http.delete(Uri.parse("$baseUrl/$id"));

      if (response.statusCode == 200) {
        _noticias.removeWhere((n) => n.id == id);
        notifyListeners();
        debugPrint("🗑️ NOTICIA ELIMINADA CORRECTAMENTE.");
      } else if (response.statusCode == 404) {
        debugPrint("⚠️ NOTICIA NO ENCONTRADA AL ELIMINAR (404).");
      } else {
        debugPrint("⚠️ ERROR AL ELIMINAR NOTICIA (${response.statusCode}).");
      }
    } catch (e) {
      debugPrint("❌ EXCEPCIÓN AL ELIMINAR NOTICIA: $e");
    }
  }
}
