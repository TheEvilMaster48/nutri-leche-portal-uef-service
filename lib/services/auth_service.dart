import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../models/usuario.dart';

class AuthService extends ChangeNotifier {
  Usuario? _currentUser;
  Map<String, dynamic>? _currentNotification;

  Usuario? get currentUser => _currentUser;
  Map<String, dynamic>? get currentNotification => _currentNotification;

  // Base URL Generada en el Backend UEF Services
  static const String BASE_URL =
      "http://10.170.4.15:8080/nutrisoft/rest/app/api/v1";

  // LOGIN
  Future<bool> login(String usuario, String password) async {
    final uri = Uri.parse("$BASE_URL/login");

    try {
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "usuario": usuario,
          "clave": password,
        }),
      );

      developer.log("📩 Respuesta Login: ${response.statusCode} ${response.body}");

      if (response.statusCode == 200) {
        final map = json.decode(response.body);

        // Verificacion del Login
        if (map['correcto'] == true || map['status'] == 'OK') {
          final data = map['data'] ?? map;

          final user = Usuario.fromJson(data);
          _currentUser = user;

          showNotification("Bienvenido ${user.nombre}", "success");
          notifyListeners();
          return true;
        } else {
          showNotification(map['mensaje'] ?? "Usuario o contraseña incorrectos", "error");
          return false;
        }
      } else {
        showNotification(
          "Error en la conexión (${response.statusCode})",
          "error",
        );
        return false;
      }
    } catch (e) {
      showNotification("Error de conexión: ${e.toString()}", "error");
      return false;
    }
  }

  // REGISTRO
  Future<bool> register(Usuario usuario) async {
    final uri = Uri.parse("$BASE_URL/registro");

    try {
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(usuario.toJson()),
      );

      developer.log("📩 Respuesta Registro: ${response.statusCode} ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final map = json.decode(response.body);

        if (map['correcto'] == true || map['status'] == 'OK') {
          _currentUser = Usuario.fromJson(map['data'] ?? map);
          showNotification("Registro exitoso. Bienvenido ${_currentUser!.nombre}", "success");
          notifyListeners();
          return true;
        } else {
          showNotification(map['mensaje'] ?? "No se pudo registrar el usuario", "error");
          return false;
        }
      } else {
        showNotification("Error al registrar (${response.statusCode})", "error");
        return false;
      }
    } catch (e) {
      showNotification("Error de conexión: ${e.toString()}", "error");
      return false;
    }
  }

  // CERRAR SESIÓN
  Future<void> logout() async {
    _currentUser = null;
    showNotification("Sesión cerrada correctamente", "success");
    notifyListeners();
  }

  // NOTIFICACIONES
  void showNotification(String message, String type) {
    _currentNotification = {"message": message, "type": type};
    notifyListeners();
    Future.delayed(const Duration(seconds: 3), clearNotification);
  }

  void clearNotification() {
    _currentNotification = null;
    notifyListeners();
  }
}
