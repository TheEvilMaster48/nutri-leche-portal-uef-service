/*import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'device_token_service.dart';

class RealtimeService {
  WebSocketChannel? _channel;
  String? _tokenDispositivo;
  bool _isConnected = false;
  bool _cerradoManualmente = false;
  bool _reintentoHecho = false;

  Future<void> connect(Function(String) onMessageReceived) async {
    if (_cerradoManualmente || _isConnected) return;

    try {
      _tokenDispositivo = await DeviceTokenService.obtenerTokenDispositivo();
      final uri = Uri.parse('ws://10.170.4.15:8080/nutrisoft/ws/eventos')
          .replace(queryParameters: {'token': _tokenDispositivo});

      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;

      _channel!.stream.listen(
        (message) => onMessageReceived(message),
        onError: (_) => _manejarError(onMessageReceived),
        onDone: () {
          if (!_cerradoManualmente) {
            _isConnected = false;
          }
        },
      );
    } catch (_) {
      _manejarError(onMessageReceived);
    }
  }

  void _manejarError(Function(String) onMessageReceived) {
    if (_cerradoManualmente) return;

    if (!_reintentoHecho) {
      _reintentoHecho = true;
      Future.delayed(const Duration(seconds: 3), () {
        if (!_cerradoManualmente) connect(onMessageReceived);
      });
    } else {
      close();
    }
  }

  void send(String destination, String payload) {
    if (_channel != null && !_cerradoManualmente) {
      final data = jsonEncode({
        'destination': destination,
        'body': payload,
        'deviceToken': _tokenDispositivo,
      });
      _channel!.sink.add(data);
    }
  }

  void close() {
    _cerradoManualmente = true;
    _isConnected = false;
    try {
      _channel?.sink.close(status.goingAway);
    } catch (_) {}
  }

  void disconnect() => close();
}
*/