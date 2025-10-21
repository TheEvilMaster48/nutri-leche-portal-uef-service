import 'dart:convert';
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/chat.dart';
import '../models/mensaje.dart';

/// ChatService — chat en tiempo real sin Firebase.
/// Usa WebSockets para enviar y recibir mensajes instantáneamente.
class ChatService {
  // URL del servidor WebSocket (puede ser local o remoto)
  final String serverUrl = 'wss://tu-servidor-de-chat.com/socket';
  late WebSocketChannel _channel;

  // Controladores para emitir actualizaciones
  final StreamController<List<Chat>> _chatsController =
      StreamController.broadcast();
  final StreamController<List<Mensaje>> _mensajesController =
      StreamController.broadcast();

  // Listas internas de chats y mensajes
  List<Chat> _chats = [];
  List<Mensaje> _mensajes = [];

  // Conectar al servidor WebSocket
  Future<void> connect() async {
    _channel = WebSocketChannel.connect(Uri.parse(serverUrl));

    _channel.stream.listen((data) {
      final decoded = json.decode(data);

      if (decoded['type'] == 'chat_list') {
        _chats = (decoded['data'] as List)
            .map((c) => Chat.fromMap(Map<String, dynamic>.from(c)))
            .toList();
        _chatsController.add(_chats);
      }

      if (decoded['type'] == 'message_list') {
        _mensajes = (decoded['data'] as List)
            .map((m) => Mensaje.fromMap(Map<String, dynamic>.from(m)))
            .toList();
        _mensajesController.add(_mensajes);
      }

      if (decoded['type'] == 'new_message') {
        final mensaje =
            Mensaje.fromMap(Map<String, dynamic>.from(decoded['data']));
        _mensajes.insert(0, mensaje);
        _mensajesController.add(_mensajes);
      }
    }, onError: (error) {
      print('❌ Error WebSocket: $error');
    });
  }

  // Cerrar la conexión
  void disconnect() {
    _channel.sink.close();
  }

  // Enviar nuevo mensaje al servidor en tiempo real
  Future<void> sendMensaje(Mensaje mensaje) async {
    final jsonMsg = json.encode({
      'type': 'send_message',
      'data': mensaje.toMap(),
    });
    _channel.sink.add(jsonMsg);
  }

  // Crear un nuevo chat
  Future<void> createChat(Chat chat) async {
    final jsonChat = json.encode({
      'type': 'create_chat',
      'data': chat.toMap(),
    });
    _channel.sink.add(jsonChat);
  }

  // Escuchar la lista de chats en tiempo real
  Stream<List<Chat>> getChats() => _chatsController.stream;

  // Escuchar mensajes de un chat específico en tiempo real
  Stream<List<Mensaje>> getMensajes(String chatId) {
    final request = json.encode({
      'type': 'get_messages',
      'chatId': chatId,
    });
    _channel.sink.add(request);
    return _mensajesController.stream;
  }

  // Eliminar chat completo
  Future<void> deleteChat(String chatId) async {
    final request = json.encode({
      'type': 'delete_chat',
      'chatId': chatId,
    });
    _channel.sink.add(request);
  }
}
