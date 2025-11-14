import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../models/usuario.dart';

class LoginService {
  static const String baseUrl =
      "http://10.170.4.15:8080/nutrisoft/rest/app/api/v1/loginAPPOficial";

  /// 🔐 Realiza login con el backend UEF Service
  Future<Usuario?> loginUEF(String usuario, String password) async {
    final uri = Uri.parse(baseUrl);

    try {
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'usuario': usuario,
          'clave': password,
          'produccion': '',
        }),
      );

      developer.log("📩 Respuesta del UEF Service: ${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> map = json.decode(response.body);

        if (map['correcto'] == true && map['data'] != null) {
          final Map<String, dynamic> userData = json.decode(map['data']);
          return Usuario.fromJson(userData);
        } else {
          developer.log("⚠️ Credenciales incorrectas o sin acceso autorizado.");
          return null;
        }
      } else {
        developer.log("❌ Error HTTP: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      developer.log("🚨 Error al conectar con el UEF Service: $e");
      return null;
    }
  }
}
