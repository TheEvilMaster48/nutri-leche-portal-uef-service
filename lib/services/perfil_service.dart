import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/usuario.dart';
import '../services/auth_service.dart';

class PerfilService with ChangeNotifier {
  final String _baseUrl =
      "https://servicioslsaqas.nutri.com.ec/nutrisoft/rest/app/api/v1/perfil";
  final AuthService _authService;

  PerfilService(this._authService);

  Usuario? _perfil;
  bool _cargando = false;

  Usuario? get perfil => _perfil;
  bool get cargando => _cargando;

  // Perfil Usuario
  Future<void> obtenerPerfil() async {
    final usuario = _authService.currentUser;
    if (usuario == null) return;

    _cargando = true;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse("$_baseUrl/${usuario.id}"));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _perfil = Usuario.fromJson(data);
      } else {
        if (kDebugMode) {
          print("⚠️ Error al obtener perfil: ${response.statusCode}");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error en obtenerPerfil(): $e");
      }
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// Actualiza Perfil
  Future<bool> actualizarPerfil(Usuario perfilActualizado) async {
    try {
      final response = await http.put(
        Uri.parse("$_baseUrl/${perfilActualizado.id}"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(perfilActualizado.toJson()),
      );

      if (response.statusCode == 200) {
        _perfil = perfilActualizado;
        _authService.actualizarUsuario(perfilActualizado);
        notifyListeners();
        return true;
      } else {
        if (kDebugMode) {
          print("⚠️ Error al actualizar perfil: ${response.statusCode}");
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error en actualizarPerfil(): $e");
      }
      return false;
    }
  }

  /// Recargar Perfil
  Future<void> recargarPerfil() async {
    await obtenerPerfil();
  }
}