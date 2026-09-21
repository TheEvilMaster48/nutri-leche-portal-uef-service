import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'push_service.dart' show localNotifications;

/// Aviso local que le dice al chofer que un evento pasó su tiempo estimado.
///
/// Reemplaza al `BroadcastService` de la app Android, que mantenía un
/// `CountDownTimer` dentro de un foreground service solo para eso. Aquí se
/// programa una notificación del sistema y se olvida: el aviso llega aunque la
/// app esté cerrada, sin un servicio en primer plano ni la notificación
/// permanente que este obliga a mostrar.
///
/// Se reutiliza el plugin y el canal que ya configura [PushService]: crear otro
/// canal significaría que el chofer tiene que permitir avisos dos veces.
///
/// **Límite conocido:** la app no declara `RECEIVE_BOOT_COMPLETED`, así que un
/// aviso programado **no sobrevive a un reinicio del teléfono**. El registro sí
/// sobrevive — vive en `RutaStore` —, solo se pierde el recordatorio. La
/// mitigación, cuando exista la pantalla del viaje activo, es reprogramar con
/// [programar] al abrirla si hay un registro abierto: eso cubre el reinicio sin
/// pedir un permiso más ni un receptor de arranque. [programar] es idempotente
/// para ese uso, porque reutiliza el mismo id por registro.
class RecordatorioEventoService {
  RecordatorioEventoService._();

  /// Rango de ids reservado para estos recordatorios.
  ///
  /// Las notificaciones de push usan `hashCode` del mensaje, que puede ser
  /// cualquier entero. Sumando esta base al id del registro se evita que un
  /// push pise un recordatorio o al revés, y [cancelar] sabe a quién apuntar.
  static const int _baseId = 910000;

  static bool _zonasListas = false;

  static int idNotificacion(int idRegistro) => _baseId + idRegistro;

  /// Programa el aviso para [vencimiento].
  ///
  /// Si el vencimiento ya pasó no programa nada: una notificación con fecha
  /// vieja se dispararía de inmediato y el chofer recibiría un aviso de algo
  /// que ya sabe.
  static Future<void> programar({
    required int idRegistro,
    required String nombreEvento,
    required DateTime vencimiento,
  }) async {
    if (!vencimiento.isAfter(DateTime.now())) {
      debugPrint('RECORDATORIO: $nombreEvento ya venció, no se programa');
      return;
    }

    try {
      _prepararZonas();

      await localNotifications.zonedSchedule(
        idNotificacion(idRegistro),
        'Evento fuera de tiempo',
        '$nombreEvento superó su tiempo estimado. Recuerda finalizarlo.',
        // Se expresa el instante en UTC a propósito. `zonedSchedule` programa
        // el momento absoluto que representa el TZDateTime, así que en UTC cae
        // exactamente igual que en la zona del teléfono, y así no hace falta
        // otro plugin solo para averiguar cuál es esa zona.
        tz.TZDateTime.from(vencimiento.toUtc(), tz.UTC),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'Notificaciones importantes',
            channelDescription: 'Canal para notificaciones importantes',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        // Inexacto a propósito: el modo exacto pide el permiso
        // SCHEDULE_EXACT_ALARM, y para un aviso de «se te pasó el tiempo» unos
        // minutos de margen no cambian nada. No vale un permiso nuevo.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );

      debugPrint('RECORDATORIO: $nombreEvento programado para $vencimiento');
    } catch (e) {
      // Que no se pueda programar el aviso no debe impedir registrar el evento:
      // el dato operativo es el registro, el recordatorio es una cortesía.
      debugPrint('RECORDATORIO: no se pudo programar → $e');
    }
  }

  /// Cancela el aviso de un registro. Se llama al cerrar el evento a tiempo.
  static Future<void> cancelar(int idRegistro) async {
    try {
      await localNotifications.cancel(idNotificacion(idRegistro));
      debugPrint('RECORDATORIO: cancelado el del registro $idRegistro');
    } catch (e) {
      debugPrint('RECORDATORIO: no se pudo cancelar → $e');
    }
  }

  static void _prepararZonas() {
    if (_zonasListas) return;
    tzdata.initializeTimeZones();
    _zonasListas = true;
  }
}
