// SERVICIO GLOBAL DE NOTIFICACIONES USANDO PROVIDER (SIN WEBSOCKETS)

import 'package:flutter/foundation.dart';
import '../models/boton_notificacion.dart';

class BotonNotificacionService extends ChangeNotifier {
  final List<Notificacion> _notificaciones = [];

  List<Notificacion> get notificaciones => List.unmodifiable(_notificaciones);

  // AGREGAR NOTIFICACIÓN DESDE OTRO MÓDULO
  void agregarDesdeModulo(String tipo, String descripcion) {
    final id = _notificaciones.length + 1;
    final fecha = DateTime.now().toIso8601String().split('T').first;

    String titulo = '';
    switch (tipo.toUpperCase()) {
      case 'EVENTO':
        titulo = 'Nuevo Evento Creado';
        break;
      case 'CELEBRACION':
        titulo = 'Nueva Celebración Registrada';
        break;
      case 'RECONOCIMIENTO':
        titulo = 'Nuevo Reconocimiento Otorgado';
        break;
      case 'BENEFICIO':
        titulo = 'Nuevo Beneficio Agregado';
        break;
      case 'SUGERENCIA':
        titulo = 'Nueva Sugerencia Recibida';
        break;
      case 'NOTICIA':
        titulo = 'Nueva Noticia Publicada';
        break;
      default:
        titulo = 'Nueva Actividad Registrada';
    }

    final nueva = Notificacion(
      id: id,
      titulo: titulo,
      descripcion: descripcion,
      tipo: tipo,
      fecha: fecha,
    );

    _notificaciones.add(nueva);
    notifyListeners();
  }

  // LIMPIAR TODAS LAS NOTIFICACIONES (OPCIONAL)
  void limpiar() {
    _notificaciones.clear();
    notifyListeners();
  }
}
