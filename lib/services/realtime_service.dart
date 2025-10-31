import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class RealtimeService {
  WebSocketChannel? _channel;

  // CONECTAR AL SERVIDOR WEBSOCKET (SPRING BOOT)
  void connect(Function(String) onMessageReceived) {
    try {
      print('⌛ CONECTANDO AL SERVIDOR WEBSOCKET...');
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://10.0.2.2:8080/ws/websocket'),
      );
      print('✅ CONEXIÓN ESTABLECIDA CON EL BACKEND');

      _channel?.stream.listen(
        (message) {
          print('📩 MENSAJE RECIBIDO: $message');
          onMessageReceived(message);
        },
        onError: (error) {
          print('❌ ERROR WS: $error');
        },
        onDone: () {
          print('🔌 CONEXIÓN FINALIZADA');
        },
      );
    } catch (e) {
      print('⚠️ ERROR AL CONECTAR: $e');
    }
  }

  // NUEVO MÉTODO COMPATIBLE CON TU CÓDIGO
  void send(String destination, String payload) {
    if (_channel != null) {
      // AGREGAMOS DESTINO EN EL MENSAJE PARA COMPATIBILIDAD
      final data = jsonEncode({
        'destination': destination,
        'body': payload,
      });

      _channel!.sink.add(data);
      print('📤 MENSAJE ENVIADO A $destination: $payload');
    } else {
      print('⚠️ NO HAY CONEXIÓN WEBSOCKET ACTIVA');
    }
  }

  // OPCIONAL: MÉTODO DIRECTO SIN DESTINO (SI QUIERES ENVIAR SOLO TEXTO)
  void sendMessage(String message) {
    if (_channel != null) {
      _channel!.sink.add(message);
      print('📤 MENSAJE ENVIADO: $message');
    }
  }

  // DESCONECTAR
  void disconnect() {
    _channel?.sink.close(status.goingAway);
    print('🔻 CONEXIÓN WEBSOCKET CERRADA');
  }
}
