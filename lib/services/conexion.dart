import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../base/base.dart';

/// Si el teléfono llega al servidor de servicios.
///
/// No se pregunta al sistema si hay Wi-Fi o datos: en bodega o en planta el
/// teléfono suele estar «conectado» a una red sin salida, y lo que importa es
/// si responde el servidor. Se abre un socket a [Base.HOST_SERVICIOS] con un
/// timeout corto; sin señal la respuesta llega en segundos, no en los 30 s del
/// timeout de una petición HTTP.
class Conexion {
  Conexion._();

  static const Duration _timeout = Duration(seconds: 3);

  /// Reemplazable en pruebas.
  @visibleForTesting
  static Future<bool> Function() verificador = _alcanzaServidor;

  static Future<bool> hayConexion() => verificador();

  static Future<bool> _alcanzaServidor() async {
    final partes = Base.HOST_SERVICIOS.split(':');
    final host = partes.first;
    final puerto = partes.length > 1 ? int.tryParse(partes[1]) ?? 80 : 80;

    try {
      final socket = await Socket.connect(host, puerto, timeout: _timeout);
      socket.destroy();
      return true;
    } catch (e) {
      debugPrint('CONEXIÓN: sin acceso a $host:$puerto → $e');
      return false;
    }
  }
}
