import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/usuario.dart';

class AuthService extends ChangeNotifier {
  Usuario? _currentUser;
  Map<String, dynamic>? _currentNotification;

  Usuario? get currentUser => _currentUser;
  Map<String, dynamic>? get currentNotification => _currentNotification;

  static const String baseUrl =
      "http://10.170.4.15:8080/nutrisoft/rest/app/api/v1";

  // 🔐 LOGIN
  Future<bool> login(String usuario, String password) async {
    final uri = Uri.parse("$baseUrl/loginAPPOficial");
    developer.log("🌐 Intentando iniciar sesión en: $uri");
    developer.log("🧾 Credenciales: usuario=$usuario, clave=$password");

    try {
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "usuario": usuario,
          "clave": password,
          "produccion": "",
        }),
      );

      developer.log("📩 Respuesta Login (${response.statusCode}): ${response.body}");

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          developer.log("⚠️ El servidor devolvió respuesta vacía");
          showNotification("El servidor no devolvió datos válidos", "error");
          return false;
        }

        final map = json.decode(response.body);

        // Validar estructura esperada
        if (map.containsKey('correcto')) {
          if (map['correcto'] == true && map['data'] != null) {
            final dynamic data = map['data'] is String
                ? json.decode(map['data'])
                : map['data'];

            developer.log("✅ Datos recibidos del usuario: $data");

            final user = Usuario.fromJson(data);
            _currentUser = user;

            // Guardar sesión local
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('currentUser', json.encode(user.toJson()));

            showNotification("Bienvenido ${user.nombre}", "success");
            notifyListeners();
            return true;
          } else {
            developer.log("⚠️ Inicio de sesión rechazado: ${map['mensaje']}");
            showNotification(map['mensaje'] ?? "Usuario o contraseña incorrectos", "error");
            return false;
          }
        } else {
          developer.log("⚠️ Respuesta inesperada del servidor: $map");
          showNotification("Estructura de respuesta desconocida", "error");
          return false;
        }
      } else {
        developer.log("❌ Error HTTP: ${response.statusCode}");
        showNotification("Error en la conexión (${response.statusCode})", "error");
        return false;
      }
    } catch (e) {
      developer.log("🚨 Excepción en login(): $e");
      showNotification("Error de conexión: ${e.toString()}", "error");
      return false;
    }
  }

  // 📝 REGISTRO
  Future<bool> register(Usuario usuario) async {
    final uri = Uri.parse("$baseUrl/registro");

    try {
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(usuario.toJson()),
      );

      developer.log("📩 Respuesta Registro (${response.statusCode}): ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final map = json.decode(response.body);

        if (map['correcto'] == true && map['data'] != null) {
          final data = json.decode(map['data']);
          _currentUser = Usuario.fromJson(data);
          showNotification("Registro exitoso. Bienvenido ${_currentUser!.nombre}", "success");
          notifyListeners();
          return true;
        } else {
          showNotification(map['mensaje'] ?? "No se pudo registrar", "error");
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

  // 🚪 CERRAR SESIÓN
  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('currentUser');
    showNotification("Sesión cerrada correctamente", "success");
    notifyListeners();
  }

  // 🔔 NOTIFICACIONES
  void showNotification(String message, String type) {
    _currentNotification = {"message": message, "type": type};
    notifyListeners();
    Future.delayed(const Duration(seconds: 3), clearNotification);
  }

  void clearNotification() {
    _currentNotification = null;
    notifyListeners();
  }

  // 👤 ACTUALIZAR PERFIL LOCALMENTE
  Future<void> actualizarUsuario(Usuario nuevoUsuario) async {
    _currentUser = nuevoUsuario;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentUser', json.encode(nuevoUsuario.toJson()));
      if (kDebugMode) {
        print("✅ Usuario actualizado y guardado localmente.");
      }
    } catch (e) {
      if (kDebugMode) {
        print("⚠️ Error al guardar usuario actualizado: $e");
      }
    }
  }

  // 🔁 AUTOLOGIN (restaurar sesión)
  Future<void> cargarUsuarioGuardado() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('currentUser');
      if (userData != null) {
        final decoded = json.decode(userData);
        _currentUser = Usuario.fromJson(decoded);
        notifyListeners();
        if (kDebugMode) {
          print("✅ Sesión restaurada automáticamente para ${_currentUser!.nombre}");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("⚠️ No se pudo restaurar la sesión: $e");
      }
    }
  }
}
