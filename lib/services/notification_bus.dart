import 'dart:async';

/// Canal interno por el que viajan las notificaciones push recibidas en primer
/// plano, para que la UI (los badges del menú) reaccione sin acoplarse a
/// Firebase.
///
/// Lo alimenta [PushService] en `onMessage` y lo escucha `MenuScreen`.
/// Vivía dentro de `menu.dart`, pero el servicio también necesita publicarlo y
/// un servicio no debe importar una pantalla.
class FirebaseNotificationBus {
  static final _controller = StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get stream => _controller.stream;

  static void add(Map<String, dynamic> data) => _controller.add(data);
}
