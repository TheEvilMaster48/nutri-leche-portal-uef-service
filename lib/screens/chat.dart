import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';
import 'chat_detalle.dart';
import 'nuevo_chat.dart';
import 'package:uuid/uuid.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mensajes', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF4ADE80),
      ),
      body: StreamBuilder<List<Chat>>(
        stream: chatService.getChatsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final chats = snapshot.data!;
          if (chats.isEmpty) {
            return const Center(child: Text('No hay chats activos.'));
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF4ADE80),
                  child: Text(
                    chat.userName.isNotEmpty
                        ? chat.userName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  chat.userName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  chat.lastMessage ?? 'Sin mensajes aún',
                  style: const TextStyle(color: Colors.grey),
                ),
                trailing: chat.lastMessageTime != null
                    ? Text(
                        "${chat.lastMessageTime!.hour.toString().padLeft(2, '0')}:${chat.lastMessageTime!.minute.toString().padLeft(2, '0')}",
                        style: const TextStyle(color: Colors.grey),
                      )
                    : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatDetalleScreen(
                        chatId: chat.id,
                        contactoNombre: chat.userName,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4ADE80),
        child: const Icon(Icons.chat_outlined),
        onPressed: () async {
          // SIN FIREBASE — usa contactos simulados o de tu BD
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NuevoChatScreen(contacts: const []),
            ),
          );
        },
      ),
    );
  }
}
