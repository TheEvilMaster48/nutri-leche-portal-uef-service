import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/boton_notificacion.dart';
import 'realtime_service.dart';

class BotonNotificacionService extends ChangeNotifier {
  final RealtimeService _realtime = RealtimeService();
  final List<Notificacion> _notificaciones = [];

  List<Notificacion> get notificaciones => List.unmodifiable(_notificaciones);

  // ESCUCHAR NOTIFICACIONES EN TIEMPO REAL DESDE EL BACKEND
  void escucharNotificacionesWS() {
    _realtime.connect((String body) {
      try {
        final data = jsonDecode(body);

        // FILTRAR SOLO NOTIFICACIONES
        if (data is Map && data.containsKey('titulo')) {
          final notif = Notificacion(
            id: data['id']?.toString() ?? '',
            titulo: data['titulo'] ?? 'Notificación',
            descripcion: data['descripcion'] ?? '',
            tipo: data['tipo'] ?? 'GENERAL',
            fecha: data['fecha'] ?? DateTime.now().toIso8601String(),
          );

          _notificaciones.insert(0, notif);
          notifyListeners();
          print('🔔 Notificación recibida: ${notif.titulo}');
        }
      } catch (e) {
        print('⚠️ Error al procesar notificación: $e');
      }
    });
  }

  // AGREGAR NOTIFICACIÓN MANUALMENTE DESDE OTRO MÓDULO (SIMULACIÓN)
  void agregarNotificacion(String tipo, String descripcion) {
    final notif = Notificacion(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      titulo: 'Nuevo $tipo',
      descripcion: descripcion,
      tipo: tipo,
      fecha: DateTime.now().toIso8601String(),
    );

    _notificaciones.insert(0, notif);
    notifyListeners();

    // ENVIAR AL BACKEND POR WEBSOCKET
    final payload = jsonEncode({
      'titulo': notif.titulo,
      'descripcion': notif.descripcion,
      'tipo': notif.tipo,
      'fecha': notif.fecha,
    });

    _realtime.send('/app/notificaciones', payload);
    print('📤 Notificación enviada al servidor: $payload');
  }

  // DESCONECTAR
  void desconectar() {
    _realtime.disconnect();
  }
}
