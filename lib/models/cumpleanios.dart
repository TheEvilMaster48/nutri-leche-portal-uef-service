class Cumpleanios {
  final String nombre;
  final String apellido;
  final String correo;
  final String telefono;
  final String planta;
  final DateTime fechaNacimiento;

  Cumpleanios({
    required this.nombre,
    required this.apellido,
    required this.correo,
    required this.telefono,
    required this.planta,
    required this.fechaNacimiento,
  });

  String get nombreCompleto => "$nombre $apellido";

  String toText() {
    return '''
Nombre: $nombre $apellido
Correo: $correo
Teléfono: $telefono
Planta: $planta
Fecha de nacimiento: ${fechaNacimiento.day}/${fechaNacimiento.month}/${fechaNacimiento.year}
''';
  }

  factory Cumpleanios.fromText(String contenido) {
    final lineas = contenido.split('\n');
    String nombre = '', apellido = '', correo = '', telefono = '', planta = '';
    DateTime fecha = DateTime.now();

    for (var linea in lineas) {
      if (linea.startsWith('Nombre:')) {
        final partes = linea.replaceFirst('Nombre:', '').trim().split(' ');
        nombre = partes.isNotEmpty ? partes.first : '';
        apellido = partes.length > 1 ? partes.sublist(1).join(' ') : '';
      } else if (linea.startsWith('Correo:')) {
        correo = linea.replaceFirst('Correo:', '').trim();
      } else if (linea.startsWith('Teléfono:')) {
        telefono = linea.replaceFirst('Teléfono:', '').trim();
      } else if (linea.startsWith('Planta:')) {
        planta = linea.replaceFirst('Planta:', '').trim();
      } else if (linea.startsWith('Fecha de nacimiento:')) {
        final fechaStr =
            linea.replaceFirst('Fecha de nacimiento:', '').trim();
        final partes = fechaStr.split('/');
        if (partes.length == 3) {
          fecha = DateTime(
            int.parse(partes[2]),
            int.parse(partes[1]),
            int.parse(partes[0]),
          );
        }
      }
    }

    return Cumpleanios(
      nombre: nombre,
      apellido: apellido,
      correo: correo,
      telefono: telefono,
      planta: planta,
      fechaNacimiento: fecha,
    );
  }
}
