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
  void initState() {
    super.initState();
    // CONECTAR WEBSOCKET PARA ESTE CHAT
    _chatService.conectarChat(widget.chatId, (msg) {
      setState(() {}); // ACTUALIZA LA INTERFAZ CUANDO LLEGAN NUEVOS MENSAJES
    });
  }

  @override
  void dispose() {
    _chatService.desconectar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final Usuario? usuarioActual = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contactoNombre),
        backgroundColor: const Color(0xFF4ADE80),
      ),
      body: Column(
        children: [
          // MENSAJES EN TIEMPO REAL
          Expanded(
            child: StreamBuilder<List<Mensaje>>(
              stream: _chatService.getMensajesStream(widget.chatId),
              builder: (context, snapshot) {
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
                    final esMio = usuarioActual != null &&
                        msg.remitenteId == usuarioActual.id.toString();

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
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!esMio)
                              Text(
                                msg.remitenteNombre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            Text(
                              msg.texto,
                              style: const TextStyle(fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Text(
                                "${msg.fecha.hour.toString().padLeft(2, '0')}:${msg.fecha.minute.toString().padLeft(2, '0')}", 
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // CAMPO DE TEXTO
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                  onPressed: () async {
                    final texto = _controller.text.trim();
                    if (texto.isEmpty || usuarioActual == null) return;

                    final mensaje = Mensaje(
                      id: const Uuid().v4(),
                      chatId: widget.chatId,
                      remitenteId: usuarioActual.id.toString(),
                      remitenteNombre: usuarioActual.nombre,
                      texto: texto,
                      fecha: DateTime.now(),
                    );

                    _chatService.enviarMensaje(mensaje);
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
