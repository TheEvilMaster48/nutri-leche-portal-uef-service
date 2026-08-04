import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';

/// Maneja el badge (número rojo) sobre el ícono de la app en el
/// springboard de iOS / launcher de Android. Refleja los pendientes.
class BadgeService {
  BadgeService._();

  /// Actualiza el badge del ícono con [total] pendientes.
  /// Si [total] es 0 (o menor) se limpia el badge.
  static Future<void> actualizar(int total) async {
    try {
      if (!await AppBadgePlus.isSupported()) return;

      if (total > 0) {
        await AppBadgePlus.updateBadge(total);
      } else {
        await AppBadgePlus.updateBadge(0);
      }
    } catch (e) {
      debugPrint('⚠️ No se pudo actualizar el badge del ícono: $e');
    }
  }

  /// Limpia el badge del ícono (por ejemplo al cerrar sesión).
  static Future<void> limpiar() => actualizar(0);
}
