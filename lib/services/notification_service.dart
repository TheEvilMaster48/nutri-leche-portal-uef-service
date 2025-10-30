import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class NotificationService {
  static Map<String, String> _headers() => {
        'Content-Type': 'application/json',
      };

      // OBTENER NOTIFICACIONES
  static Future<List<Map<String, dynamic>>> obtenerNotificaciones(String usuarioId) async {
    const base = AuthService.baseUrl;
    final List<Map<String, dynamic>> resultados = [];

    try {
      // Eventos
      final eventosUri = Uri.parse('$base/eventos/notificaciones?usuarioId=$usuarioId');
      final eventosResp = await http.get(eventosUri, headers: _headers());

      if (eventosResp.statusCode == 200 && eventosResp.body.isNotEmpty) {
        final List data = jsonDecode(eventosResp.body);
        for (final e in data) {
          final accion = (e['accion'] ?? '').toString().toLowerCase();
          String tipo = 'nuevo_evento';
          if (accion.contains('modificado') || accion.contains('actualizado')) {
            tipo = 'evento_actualizado';
          } else if (accion.contains('eliminado')) {
            tipo = 'evento_eliminado';
          } else if (accion.contains('urgente')) {
            tipo = 'urgente';
          }

          resultados.add({
            'tipo': tipo,
            'titulo': e['titulo'] ?? 'Evento',
            'detalle': e['accion'] ?? '',
            'fecha': e['fecha'] ?? DateTime.now().toIso8601String(),
          });
        }
      }

      // --- Chat ---
      final chatUri = Uri.parse('$base/chat/notificaciones?usuarioId=$usuarioId');
      final chatResp = await http.get(chatUri, headers: _headers());

      if (chatResp.statusCode == 200 && chatResp.body.isNotEmpty) {
        final List data = jsonDecode(chatResp.body);
        for (final c in data) {
          final bool leido = c['leido'] == true;
          resultados.add({
            'tipo': leido ? 'nuevo_chat' : 'mensaje_no_leido',
            'titulo': leido
                ? 'Conversación iniciada'
                : 'Nuevo mensaje de ${c['remitente'] ?? 'Usuario'}',
            'detalle': c['preview'] ?? '',
            'fecha': c['fecha'] ?? DateTime.now().toIso8601String(),
          });
        }
      }

      resultados.sort((a, b) {
        final fa = DateTime.tryParse(a['fecha'] ?? '') ?? DateTime.now();
        final fb = DateTime.tryParse(b['fecha'] ?? '') ?? DateTime.now();
        return fb.compareTo(fa);
      });

      return resultados;
    } catch (e) {
      print('⚠️ Error obteniendo notificaciones: $e');
      return [];
    }
  }
}
