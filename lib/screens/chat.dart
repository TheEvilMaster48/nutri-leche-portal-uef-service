import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../services/chat_service.dart';
import '../models/chat.dart';
import 'chat_detalle_screen.dart';
import 'nuevo_chat.dart';

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
        stream: chatService.getChats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No tienes conversaciones'));
          }

          final chats = snapshot.data!;
          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF4ADE80),
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text(chat.userName),
                subtitle: Text(chat.lastMessage ?? 'Sin mensajes'),
                trailing: chat.lastMessageTime != null
                    ? Text(
                        TimeOfDay.fromDateTime(chat.lastMessageTime!)
                            .format(context),
                        style: const TextStyle(fontSize: 12),
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
        child: const Icon(Icons.chat_outlined, size: 28),
        onPressed: () async {
          if (await FlutterContacts.requestPermission()) {
            final contacts = await FlutterContacts.getContacts(
              withProperties: true,
              withPhoto: false,
            );
            final filtered = contacts.where((c) => c.phones.isNotEmpty).toList();
            // ignore: use_build_context_synchronously
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NuevoChatScreen(contacts: filtered),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Permiso de contactos denegado'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }
}
