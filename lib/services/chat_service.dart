import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat.dart';
import '../models/mensaje.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // CREAR CHAT
  Future<void> createChat(Chat chat) async {
    await _firestore.collection('chats').doc(chat.id).set(chat.toMap());
  }

  // OBTENER LISTA DE CHATS EN TIEMPO REAL
  Stream<List<Chat>> getChatsStream() {
    return _firestore.collection('chats').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Chat.fromMap(doc.data())).toList();
    });
  }

  // ENVIAR MENSAJE
  Future<void> sendMensaje(Mensaje mensaje) async {
    await _firestore
        .collection('chats')
        .doc(mensaje.chatId)
        .collection('mensajes')
        .doc(mensaje.id)
        .set(mensaje.toMap());

    await _firestore.collection('chats').doc(mensaje.chatId).update({
      'lastMessage': mensaje.texto,
      'lastMessageTime': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ESCUCHAR MENSAJES EN TIEMPO REAL
  Stream<List<Mensaje>> getMensajesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('mensajes')
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Mensaje.fromMap(doc.data())).toList());
  }

  // ELIMINAR CHAT COMPLETO
  Future<void> deleteChat(String chatId) async {
    final mensajes = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('mensajes')
        .get();

    for (var doc in mensajes.docs) {
      await doc.reference.delete();
    }

    await _firestore.collection('chats').doc(chatId).delete();
  }
}
