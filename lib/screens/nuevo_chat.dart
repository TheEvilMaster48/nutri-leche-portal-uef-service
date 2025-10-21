import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';
import 'chat_detalle_screen.dart';
import 'package:uuid/uuid.dart';

class NuevoChatScreen extends StatelessWidget {
  final List<Contact> contacts;
  const NuevoChatScreen({super.key, required this.contacts});

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar contacto', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF4ADE80),
      ),
      body: ListView.builder(
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          final c = contacts[index];
          final nombre = c.displayName;
          final telefono = c.phones.isNotEmpty ? c.phones.first.number : 'Sin número';

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF4ADE80),
              child: Text(
                nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(nombre),
            subtitle: Text(telefono),
            trailing: const Icon(Icons.chat_bubble_outline, color: Color(0xFF4ADE80)),
            onTap: () async {
              // ✅ Crear chat nuevo en Firebase
              final chat = Chat(
                id: const Uuid().v4(),
                userId: telefono,
                userName: nombre,
                userRole: 'contacto',
                lastMessage: null,
                lastMessageTime: null,
              );

              await chatService.createChat(chat);

              // Navegar al detalle del chat
              // ignore: use_build_context_synchronously
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
      ),
    );
  }
}
