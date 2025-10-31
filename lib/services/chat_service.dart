import 'dart:convert';
import '../models/mensaje.dart';
import '../models/chat.dart';
import 'realtime_service.dart';

class ChatService {
  final RealtimeService _realtime = RealtimeService();
  final List<Mensaje> _mensajes = [];
  final List<Chat> _chats = [];

  void conectarChat(String chatId, Function(Mensaje) onMensajeRecibido) {
    _realtime.connect((String body) {
      try {
        final data = jsonDecode(body);
        if (data['chatId'] == chatId) {
          final msg = Mensaje.fromMap(data);
          _mensajes.insert(0, msg);
          onMensajeRecibido(msg);
        }
      } catch (e) {
        print('⚠️ Error al procesar mensaje: $e');
      }
    });
  }

  Future<void> enviarMensaje(Mensaje mensaje) async {
    final payload = jsonEncode(mensaje.toMap());
    _realtime.send('/app/chat', payload);
    print('📤 Enviado a /app/chat: $payload');
  }

  void desconectar() {
    _realtime.disconnect();
  }

  Stream<List<Mensaje>> getMensajesStream(String chatId) async* {
    yield _mensajes.where((m) => m.chatId == chatId).toList();
  }

  Future<void> createChat(Chat chat) async {
    _chats.add(chat);
    print('✅ Chat creado: ${chat.userName}');
  }

  Stream<List<Chat>> getChatsStream() async* {
    yield _chats;
  }
}
