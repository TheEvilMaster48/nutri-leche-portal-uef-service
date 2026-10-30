import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../base/base.dart';
import '../models/chatbot.dart';

/// Cliente de `appOficial/api/v1/chatbot/responder`: el chatbot de menú de
/// opciones que se configura desde nutrisoft.
///
/// Solo se envían `idUsuario` e `idOpcion`. El código SAP, la cédula y demás
/// datos del empleado los toma el backend de la base —ignora lo que llegue en
/// `parametros`— para que nadie consulte los datos de otro.
class ChatbotService {
  ChatbotService._();

  static const Duration _timeout = Duration(seconds: 30);

  @visibleForTesting
  static http.Client cliente = http.Client();

  /// Pide la respuesta a [idOpcion]; sin ella (o con 0), el menú inicial.
  ///
  /// Lanza [ChatbotException] con un mensaje listo para mostrar.
  static Future<ChatbotRespuesta> responder({
    required int idUsuario,
    int? idOpcion,
  }) async {
    final http.Response respuesta;
    try {
      respuesta = await cliente
          .post(
            Uri.parse('${Base.URL_APPOFICIAL}/chatbot/responder'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'idUsuario': idUsuario,
              if (idOpcion != null && idOpcion != 0) 'idOpcion': idOpcion,
            }),
          )
          .timeout(_timeout);
    } catch (e) {
      debugPrint('CHATBOT → excepción: $e');
      throw const ChatbotException('No se pudo conectar con el servidor.');
    }

    if (respuesta.statusCode != 200) {
      debugPrint('CHATBOT → HTTP ${respuesta.statusCode}');
      throw ChatbotException(
        'El servidor respondió con error (${respuesta.statusCode}).',
      );
    }

    try {
      final sobre = jsonDecode(utf8.decode(respuesta.bodyBytes));
      if (sobre['correcto'] != true) {
        final mensaje = (sobre['mensaje'] ?? '').toString();
        throw ChatbotException(
          mensaje.isEmpty ? 'No se pudo obtener la respuesta.' : mensaje,
        );
      }
      return ChatbotRespuesta.desdeData(sobre['data']);
    } on ChatbotException {
      rethrow;
    } catch (e) {
      debugPrint('CHATBOT → respuesta ilegible: $e');
      throw const ChatbotException('La respuesta del servidor no es válida.');
    }
  }
}

class ChatbotException implements Exception {
  const ChatbotException(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}
