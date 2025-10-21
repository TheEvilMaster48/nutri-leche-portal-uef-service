import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/chat_service.dart';
import '../models/mensaje.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contactoNombre),
        backgroundColor: const Color(0xFF4ADE80), // ✅ Color fijo
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Mensaje>>(
              stream: _chatService.getMensajes(widget.chatId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final mensajes = snapshot.data!;
                return ListView.builder(
                  reverse: true,
                  itemCount: mensajes.length,
                  itemBuilder: (context, index) {
                    final msg = mensajes[index];
                    final esMio = msg.senderId == "usuario_actual";
                    return Align(
                      alignment: esMio
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.all(6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: esMio
                              ? const Color(0xFFDCF8C6)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                        child: Text(msg.content),
                      ),
                    );
                  },
                );
              },
            ),
          ),
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
                    if (_controller.text.trim().isEmpty) return;
                    final mensaje = Mensaje(
                      id: const Uuid().v4(),
                      chatId: widget.chatId,
                      senderId: "usuario_actual",
                      senderName: "Yo",
                      content: _controller.text.trim(),
                      timestamp: DateTime.now(),
                    );
                    _chatService.sendMensaje(mensaje);
                    _controller.clear();
                  },
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
