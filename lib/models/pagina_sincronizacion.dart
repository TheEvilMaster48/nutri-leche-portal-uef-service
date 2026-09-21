import 'viaje_chofer.dart';

/// Una página de cambios devuelta por `/sincronizar`.
///
/// El protocolo es un delta con marca de agua: se manda la última [marca]
/// recibida y el servidor devuelve lo que cambió desde entonces. Se compara
/// contra la **última modificación** del viaje, no contra su fecha, así que un
/// viaje de ayer al que hoy se le corrigió la placa vuelve a bajar.
class PaginaSincronizacion {
  /// La marca de agua nueva, en `yyyy-MM-dd HH:mm:ss`. Se guarda y se manda en
  /// la llamada siguiente.
  ///
  /// **Cuando no hay nada nuevo vuelve la misma que se mandó**, no una del
  /// momento actual. Es deliberado del servidor: si adelantara la marca aunque
  /// fuera un segundo respecto al último cambio guardado, la app se saltaría
  /// para siempre lo que se modificara en esa rendija.
  final String marca;

  final int total;

  /// Si se llegó al tope de la página y quedan cambios sin bajar.
  ///
  /// Tomarlo por «ya está al día» deja viajes atrás: hay que volver a llamar
  /// con la [marca] nueva hasta que venga en false.
  final bool hayMas;

  final List<ViajeChofer> viajes;

  const PaginaSincronizacion({
    required this.marca,
    this.total = 0,
    this.hayMas = false,
    this.viajes = const [],
  });

  bool get sinCambios => viajes.isEmpty && !hayMas;

  factory PaginaSincronizacion.fromJson(Map<String, dynamic> json) =>
      PaginaSincronizacion(
        marca: json['marca']?.toString().trim() ?? '',
        total: json['total'] is int
            ? json['total']
            : int.tryParse(json['total']?.toString() ?? '') ?? 0,
        // Se lee laxo a propósito: el WS podría mandar 1/0 o "true".
        hayMas: json['hayMas'] == true ||
            json['hayMas'] == 1 ||
            json['hayMas']?.toString().toLowerCase() == 'true',
        viajes: (json['viajes'] is List)
            ? (json['viajes'] as List)
                .whereType<Map>()
                .map((e) => ViajeChofer.fromJson(e.cast<String, dynamic>()))
                .toList()
            : const [],
      );

  @override
  String toString() => 'PaginaSincronizacion(marca $marca, '
      '${viajes.length}/$total, hayMas $hayMas)';
}
