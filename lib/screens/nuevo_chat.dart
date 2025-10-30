import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';
import 'chat_detalle.dart';
import 'package:uuid/uuid.dart';

class NuevoChatScreen extends StatelessWidget {
  const NuevoChatScreen({super.key, required this.contacts});
  final List contacts;

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Chat', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF4ADE80),
      ),
      body: ListView.builder(
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          final c = contacts[index];
          final nombre = c['nombre'] ?? 'Sin nombre';
          final idUsuario = c['id'] ?? 'user_${index + 1}';

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF4ADE80),
              child: Text(
                nombre[0].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(nombre),
            subtitle: const Text('Toca para iniciar chat'),
            trailing:
                const Icon(Icons.chat_bubble_outline, color: Color(0xFF4ADE80)),
            onTap: () async {
              final chat = Chat(
                id: const Uuid().v4(),
                userId: idUsuario,
                userName: nombre,
                userRole: 'usuario',
              );

              await chatService.createChat(chat);

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
