import 'package:flutter/foundation.dart';
import 'package:nutri/services/auth_service.dart';

class GlobalNotifier extends ChangeNotifier {
  static AuthService? auth;

  String _mensajeActual = '';
  bool _mostrarMensaje = false;

  String get mensajeActual => _mensajeActual;
  bool get mostrarMensaje => _mostrarMensaje;

  void mostrarNotificacion(String mensaje) {
    _mensajeActual = mensaje;
    _mostrarMensaje = true;
    notifyListeners();

    Future.delayed(const Duration(seconds: 3), () {
      ocultarNotificacion();
    });
  }

  void ocultarNotificacion() {
    _mostrarMensaje = false;
    notifyListeners();
  }
}
