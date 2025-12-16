/*import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recurso.dart';
import '../models/usuario.dart';

class RecursoService {
  final String baseUrl =
      'https://servicioslsa.nutri.com.ec/nutrisoft/rest/app/api/v1';

  // Obtener todos los recursos del backend UEF Service
  Future<List<Recurso>> obtenerRecursos(Usuario usuario) async {
    final url = Uri.parse('$baseUrl/recursos');

    final response = await http.get(url, headers: {
      'Content-Type': 'application/json',
    });

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => Recurso.fromJson(e)).toList();
    } else {
      throw Exception('Error al obtener recursos (${response.statusCode})');
    }
  }
}
*/