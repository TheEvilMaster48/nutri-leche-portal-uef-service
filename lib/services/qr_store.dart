import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reserva_service.dart';

/// Código QR del empleado guardado en el teléfono.
///
/// El QR del perfil sale de `usuario.cedula`, pero ese dato vive en el
/// `currentUser` que [PerfilService] sobrescribe con cada consulta al WS: si
/// una respuesta llega sin cédula, el QR desaparecería justo cuando más hace
/// falta (en el comedor, sin señal). Por eso se guarda aparte, por usuario, y
/// solo se pisa con una cédula no vacía.
///
/// Se borra al cerrar sesión: es un dato personal y el siguiente usuario del
/// teléfono no debe verlo.
class QrStore {
  QrStore._();

  static String _clave(int idUsuario) => 'qr_cedula_$idUsuario';

  /// Guarda la cédula y su QR. Ignora cédulas vacías para no borrar lo bueno.
  static Future<void> guardar(int idUsuario, String? cedula) async {
    final valor = (cedula ?? '').trim();
    if (idUsuario <= 0 || valor.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _clave(idUsuario),
        jsonEncode({'cedula': valor, 'qr': ReservaService.qrDeCedula(valor)}),
      );
    } catch (e) {
      debugPrint('⚠️ No se pudo guardar el QR: $e');
    }
  }

  /// El QR guardado del usuario, o `null` si nunca se guardó.
  static Future<QrGuardado?> leer(int idUsuario) async {
    if (idUsuario <= 0) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(_clave(idUsuario));
      if (crudo == null) return null;

      final map = jsonDecode(crudo) as Map<String, dynamic>;
      final cedula = map['cedula']?.toString() ?? '';
      final qr = map['qr']?.toString() ?? '';
      if (cedula.isEmpty || qr.isEmpty) return null;

      return QrGuardado(cedula: cedula, qr: qr);
    } catch (e) {
      debugPrint('⚠️ No se pudo leer el QR guardado: $e');
      return null;
    }
  }

  /// Borra el QR de todos los usuarios que hayan usado el teléfono.
  static Future<void> limpiar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final clave in prefs.getKeys().toList()) {
        if (clave.startsWith('qr_cedula_')) await prefs.remove(clave);
      }
    } catch (e) {
      debugPrint('⚠️ No se pudo borrar el QR guardado: $e');
    }
  }
}

class QrGuardado {
  final String cedula;

  /// Contenido del QR: la cédula en Base64.
  final String qr;

  const QrGuardado({required this.cedula, required this.qr});
}
