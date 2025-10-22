import 'package:stomp_dart_client/stomp_dart_client.dart';

class RealtimeService {
  StompClient? _client;

  void connect(Function(String) onMessageReceived) {
    _client = StompClient(
      config: StompConfig(
        url: 'ws://10.170.4.15:8080/ws/websocket',
        onConnect: (frame) {
          print('✅ Conectado al servidor WebSocket (Spring Boot)');

          //Eventos
          _client?.subscribe(
            destination: '/topic/eventos',
            callback: (frame) {
              if (frame.body != null) {
                print('📩 Mensaje recibido: ${frame.body}');
                onMessageReceived(frame.body!);
              }
            },
          );
        },
        beforeConnect: () async {
          print('⌛ Conectando al servidor WebSocket...');
          await Future.delayed(const Duration(milliseconds: 500));
        },
        onWebSocketError: (error) => print('❌ Error WS: $error'),
        onDisconnect: (frame) => print('🔌 Desconectado del WebSocket'),
        heartbeatIncoming: const Duration(seconds: 5),
        heartbeatOutgoing: const Duration(seconds: 5),
      ),
    );

    _client?.activate();
  }

  void disconnect() {
    _client?.deactivate();
  }
}
