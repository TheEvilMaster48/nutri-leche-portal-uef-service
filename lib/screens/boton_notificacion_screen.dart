import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/boton_notificacion_service.dart';
import '../models/boton_notificacion.dart';

class BotonNotificacionScreen extends StatefulWidget {
  const BotonNotificacionScreen({super.key});

  @override
  State<BotonNotificacionScreen> createState() =>
      _BotonNotificacionScreenState();
}

class _BotonNotificacionScreenState extends State<BotonNotificacionScreen> {
  @override
  void initState() {
    super.initState();
    // ESCUCHAR NOTIFICACIONES EN TIEMPO REAL
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BotonNotificacionService>(context, listen: false)
          .escucharNotificacionesWS();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'Notificaciones',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 4,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0048FF), Color(0xFF64B5F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Consumer<BotonNotificacionService>(
        builder: (context, service, child) {
          final notificaciones = service.notificaciones;

          if (notificaciones.isEmpty) {
            return const Center(
              child: Text(
                'No hay notificaciones por el momento.',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: notificaciones.length,
            itemBuilder: (context, index) {
              final notif = notificaciones[index];
              return _buildNotificacionCard(notif);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificacionCard(Notificacion notif) {
    final iconData = _getIconoPorTipo(notif.tipo);
    final color = _getColorPorTipo(notif.tipo);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(iconData, color: color, size: 26),
        ),
        title: Text(
          notif.titulo,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Color(0xFF1A1A1A),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            notif.descripcion,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF444444),
              height: 1.3,
            ),
          ),
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.more_vert, color: Colors.grey, size: 18),
            const SizedBox(height: 4),
            Text(
              notif.fecha,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
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
        return Icons.notifications_active;
    }
  }

  Color _getColorPorTipo(String tipo) {
    switch (tipo.toUpperCase()) {
      case 'EVENTO':
        return const Color(0xFF0048FF);
      case 'CELEBRACION':
        return const Color(0xFFFF4081);
      case 'RECONOCIMIENTO':
        return const Color(0xFFFFC107);
      case 'BENEFICIO':
        return const Color(0xFF00BCD4);
      case 'SUGERENCIA':
        return const Color(0xFFFF5722);
      case 'NOTICIA':
        return const Color(0xFF009688);
      default:
        return const Color(0xFF9E9E9E);
    }
  }
}
