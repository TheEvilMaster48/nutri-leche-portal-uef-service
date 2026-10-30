import 'package:geolocator/geolocator.dart';

/// Comedor donde se puede registrar una reserva.
///
/// Cada sede tiene su propio endpoint en `nfc` (el backend graba el centro
/// según cuál se llame), así que la app decide a cuál enviar por la posición
/// del teléfono: solo se reserva estando a [radioMetros] o menos del comedor.
class SedeComedor {
  final String codigo;
  final double latitud;
  final double longitud;

  /// Ruta relativa a `BASE_URL`.
  final String ruta;

  const SedeComedor({
    required this.codigo,
    required this.latitud,
    required this.longitud,
    required this.ruta,
  });

  /// Distancia máxima al comedor para poder reservar.
  static const double radioMetros = 50;

  static const List<SedeComedor> todas = [
    SedeComedor(
      codigo: 'CU',
      latitud: -2.875918,
      longitud: -78.978448,
      ruta: 'nfc/registrar_reservacu',
    ),
    SedeComedor(
      codigo: 'SA',
      latitud: -2.484439,
      longitud: -78.952893,
      ruta: 'nfc/registrar_reservasa',
    ),
  ];

  double distanciaDesde(double lat, double lng) =>
      Geolocator.distanceBetween(lat, lng, latitud, longitud);

  /// La sede más cercana a la posición, con su distancia en metros.
  static ({SedeComedor sede, double metros}) masCercana(
    double lat,
    double lng,
  ) {
    var mejor = todas.first;
    var metros = mejor.distanciaDesde(lat, lng);
    for (final sede in todas.skip(1)) {
      final d = sede.distanciaDesde(lat, lng);
      if (d < metros) {
        mejor = sede;
        metros = d;
      }
    }
    return (sede: mejor, metros: metros);
  }

  /// La sede dentro de [radioMetros], o `null` si no hay ninguna tan cerca.
  static SedeComedor? dentroDelRadio(double lat, double lng) {
    final cercana = masCercana(lat, lng);
    return cercana.metros <= radioMetros ? cercana.sede : null;
  }
}
