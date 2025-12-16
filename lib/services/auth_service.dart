import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'package:universal_html/js.dart' as js;
import '../models/usuario.dart';
import 'push_service.dart';

class AuthService extends ChangeNotifier {
  Usuario? _currentUser;
  Map<String, dynamic>? _currentNotification;

  Usuario? get currentUser => _currentUser;
  Map<String, dynamic>? get currentNotification => _currentNotification;

  static const String baseUrl =
      "https://servicioslsaqas.nutri.com.ec/nutrisoft/rest/app/api/v1";

  static const String loginUrl =
      "https://servicioslsaqas.nutri.com.ec/nutrisoft/rest/app/api/v1/loginAPPOficial";

  // MÉTODO PARA OBTENER EL GÉNERO DESDE EL BACKEND
  Future<String> obtenerGenero(String userId) async {
    final url = Uri.parse("$baseUrl/obtenerGenero/$userId"); // Ajusta la URL de acuerdo al backend

    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        // Si la respuesta es exitosa, obtenemos el género
        final data = json.decode(response.body);
        return data['genero'] ?? 'masculino';  // Default 'masculino' si no hay género
      } else {
        // Si la respuesta no es exitosa, devolver un valor por defecto
        return 'masculino';
      }
    } catch (e) {
      print("Error obteniendo el género: $e");
      return 'masculino'; // Default en caso de error
    }
  }

  Future<bool> login(String usuario, String password) async {
    String? token;

    // Obtener Token FCM solo donde es seguro
    try {
      if (kIsWeb) {
        // Web
        token = await FirebaseMessaging.instance.getToken();
      } else if (Platform.isAndroid) {
        // Android
        token = await FirebaseMessaging.instance.getToken();
      } else if (Platform.isIOS) {
        // iOS: NO pedimos FCM token aquí para evitar apns-token-not-set
        debugPrint(
            'iOS: no se solicita FCM token en login; se gestionará en PushService.init()');
      } else {
        debugPrint('Plataforma no soportada para FCM en login');
      }
    } catch (e) {
      debugPrint('Error obteniendo FCM token en login: $e');
    }

    print('FCM TOKEN Login = $token');

    final uri = Uri.parse(loginUrl);
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
          showNotification("El servidor devolvió respuesta vacía", "error");
          return false;
        }

        final map = json.decode(response.body);
        developer.log("🧠 BODY DEVUELTO POR EL SERVIDOR: ${response.body}");

        if (map['correcto'] == true && map['data'] != null) {
          dynamic data;

          try {
            if (map['data'] is String) {
              final decodedOnce = json.decode(map['data']);
              if (decodedOnce is String) {
                data = json.decode(decodedOnce);
              } else {
                data = decodedOnce;
              }
            } else {
              data = map['data'];
            }
          } catch (e) {
            developer.log("⚠️ No se pudo decodificar 'data': $e");
            showNotification("Error al procesar datos del servidor", "error");
            return false;
          }

          developer.log("✅ Datos decodificados correctamente: $data");

          try {
            final user = Usuario.fromJson(data);
            _currentUser = user;

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('currentUser', json.encode(user.toJson()));

            showNotification("Bienvenido ${user.nombre}", "success");
            notifyListeners();

            if (token != null) {
              EnviarToken(token, user.id);
            }

            return true;
          } catch (e) {
            developer.log("⚠️ Error al construir Usuario.fromJson: $e");
            showNotification("Error al leer datos del usuario", "error");
            return false;
          }
        } else {
          final mensaje = map['mensaje'] ?? "Usuario o contraseña incorrectos";
          showNotification(mensaje, "error");
          developer.log("❌ Login incorrecto: $mensaje");
          return false;
        }
      } else {
        showNotification("Error HTTP (${response.statusCode})", "error");
        developer.log("❌ Error HTTP: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      developer.log("🚨 Excepción en login(): $e");
      showNotification("Error de conexión: ${e.toString()}", "error");
      return false;
    }
  }

  Future<void> EnviarToken(String token, int idUsuario) async {
    var map = <String, dynamic>{
      'token': token,
      'idUsuario': idUsuario,
    };

    try {
      if (kIsWeb) {
        js.context.callMethod('console.log', ['🌍 Enviando token en Web: $token']);
        final response = await http.post(
          Uri.parse("https://servicioslsaqas.nutri.com.ec/nutrisoft/rest/appOficial/api/v1/ActualizarToken"),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(map),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          js.context.callMethod('console.log', ['✅ Token actualizado correctamente en Web']);
        } else {
          js.context.callMethod('console.error', ['⚠️ Error al actualizar token en Web: ${response.statusCode}']);
        }
      }

      else if (Platform.isAndroid || Platform.isIOS) {
        final response = await http.post(
          Uri.parse("https://servicioslsaqas.nutri.com.ec/nutrisoft/rest/appOficial/api/v1/ActualizarToken"),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(map),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          debugPrint('✅ Token actualizado correctamente en el servidor (Android/iOS).');
        } else {
          debugPrint('⚠️ Error al actualizar token: ${response.statusCode}');
        }
      }

      else {
        debugPrint('❌ Plataforma no soportada para envío de token.');
      }
    } catch (e) {
      debugPrint('❌ Error al enviar token: $e');
    }
  }

  // ELIMINAR TOKEN
  Future<void> EliminarToken(int idUsuario) async {
    var map = <String, dynamic>{
      'idUsuario': idUsuario,
    };

    try {
      final response = await http.post(
        Uri.parse("https://servicioslsaqas.nutri.com.ec/nutrisoft/rest/appOficial/api/v1/EliminarToken"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(map),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('🧹 Token eliminado correctamente en el servidor.');
      } else {
        debugPrint('⚠️ Error al eliminar token: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error al enviar EliminarToken: $e');
    }
  }

  Future<void> logout() async {
    try {
      // AHORA NO SE ACTUALIZA, SE ELIMINA
      if (_currentUser != null) {
        await EliminarToken(_currentUser!.id);
      }
    } catch (_) {}

    await PushService.instance.stopCompletely();

    _currentUser = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('currentUser');

    showNotification("Sesión cerrada correctamente", "success");
    notifyListeners();
  }

  void showNotification(String message, String type) {
    _currentNotification = {"message": message, "type": type};
    notifyListeners();

    Future.delayed(const Duration(seconds: 3), clearNotification);
  }

  void clearNotification() {
    _currentNotification = null;
    notifyListeners();
  }

  Future<void> actualizarUsuario(Usuario nuevoUsuario) async {
    _currentUser = nuevoUsuario;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentUser', json.encode(nuevoUsuario.toJson()));
    } catch (e) {
      if (kDebugMode) {
        print("⚠️ Error al guardar usuario actualizado: $e");
      }
    }
  }

  Future<void> cargarUsuarioGuardado() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('currentUser');

      if (userData != null) {
        final decoded = json.decode(userData);
        _currentUser = Usuario.fromJson(decoded);
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print("⚠️ No se pudo restaurar la sesión: $e");
      }
    }
  }

  bool get isLoggedIn => _currentUser != null;

  Future<bool> verificarSesionGuardada() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('currentUser');

      if (userData != null) {
        final decoded = json.decode(userData);
        _currentUser = Usuario.fromJson(decoded);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint("⚠️ No se pudo verificar sesión guardada: $e");
    }
    return false;
  }
}
