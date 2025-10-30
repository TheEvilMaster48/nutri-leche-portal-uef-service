// PANTALLA DE NOTIFICACIONES AL ESTILO FACEBOOK

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/boton_notificacion_service.dart';
import '../models/boton_notificacion.dart';

class BotonNotificacionScreen extends StatelessWidget {
  const BotonNotificacionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        centerTitle: true,
      ),
      body: Consumer<BotonNotificacionService>(
        builder: (context, service, child) {
          final notificaciones = service.notificaciones.reversed.toList();

          if (notificaciones.isEmpty) {
            return const Center(
              child: Text('No hay notificaciones por el momento.'),
            );
          }

          return ListView.builder(
            itemCount: notificaciones.length,
            itemBuilder: (context, index) {
              final notif = notificaciones[index];
              return ListTile(
                leading: Icon(_getIconoPorTipo(notif.tipo), size: 32),
                title: Text(
                  notif.titulo,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(notif.descripcion),
                trailing: Text(
                  notif.fecha,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getIconoPorTipo(String tipo) {
    switch (tipo.toUpperCase()) {
      case 'EVENTO':
        return Icons.event;
      case 'CELEBRACION':
        return Icons.cake;
      case 'RECONOCIMIENTO':
        return Icons.emoji_events;
      case 'BENEFICIO':
        return Icons.card_giftcard;
      case 'SUGERENCIA':
        return Icons.mail;
      case 'NOTICIA':
        return Icons.newspaper;
      default:
        return Icons.notifications;
    }
  }
}
