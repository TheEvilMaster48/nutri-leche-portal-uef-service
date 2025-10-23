import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../models/mensaje.dart';
import '../models/usuario.dart';

class ChatDetalleScreen extends StatefulWidget {
  final String chatId;
  final String contactoNombre;

  const ChatDetalleScreen({
    super.key,
    required this.chatId,
    required this.contactoNombre,
  });

  @override
  State<ChatDetalleScreen> createState() => _ChatDetalleScreenState();
}

class _ChatDetalleScreenState extends State<ChatDetalleScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // Obtener el usuario actual desde AuthService
    final authService = Provider.of<AuthService>(context);
    final Usuario? usuarioActual = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contactoNombre),
        backgroundColor: const Color(0xFF4ADE80),
      ),
      body: Column(
        children: [
          // Mensajes en tiempo real
          Expanded(
            child: StreamBuilder<List<Mensaje>>(
              stream: _chatService.getMensajes(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final mensajes = snapshot.data ?? [];

                if (mensajes.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay mensajes aún',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  itemCount: mensajes.length,
                  itemBuilder: (context, index) {
                    final msg = mensajes[index];

                    // Identificar si el mensaje es del usuario actual
                    final esMio =
                        usuarioActual != null && msg.senderId == usuarioActual.id.toString();

                    return Align(
                      alignment:
                          esMio ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                              esMio ? const Color(0xFFDCF8C6) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                        child: Text(
                          msg.content,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Campo de texto para enviar mensajes
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF4ADE80)),
                  onPressed: () {
                    final texto = _controller.text.trim();
                    if (texto.isEmpty || usuarioActual == null) return;

                    // Crear mensaje real con los datos del usuario actual
                    final mensaje = Mensaje(
                      id: const Uuid().v4(),
                      chatId: widget.chatId,
                      senderId: usuarioActual.id.toString(),
                      senderName: usuarioActual.nombre,
                      content: texto,
                      timestamp: DateTime.now(),
                    );

                    _chatService.sendMensaje(mensaje);
                    _controller.clear();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
