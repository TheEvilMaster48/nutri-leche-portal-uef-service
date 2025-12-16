class Pais {
  final String nombre;
  final String bandera;
  final String prefijo;

  Pais({
    required this.nombre,
    required this.bandera,
    required this.prefijo,
  });

  static List<Pais> getPaises() {
    return [
      Pais(nombre: 'Ecuador', bandera: '🇪🇨', prefijo: '+593'),
      Pais(nombre: 'Colombia', bandera: '🇨🇴', prefijo: '+57'),
      Pais(nombre: 'Perú', bandera: '🇵🇪', prefijo: '+51'),
      Pais(nombre: 'Chile', bandera: '🇨🇱', prefijo: '+56'),
      Pais(nombre: 'México', bandera: '🇲🇽', prefijo: '+52'),
    ];
  }
}
