class Usuario {
  final int id;
  final String nombre;
  final String correo;
  final String telefono;
  final String cargo;
  final String areaUsuario;
  final String modulos;
  final String? foto; 

  Usuario({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.telefono,
    required this.cargo,
    required this.areaUsuario,
    required this.modulos,
    this.foto,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ??
          json['nombresCompletos'] ??
          json['nombres'] ??
          json['usuario'] ??
          '',
      correo: json['correo'] ?? json['email'] ?? '',
      telefono: json['telefono'] ?? '',
      cargo: json['cargo'] ?? json['cargoNombre'] ?? '',
      areaUsuario: json['areaUsuario'] ?? json['area'] ?? '',
      modulos: json['modulos']?.toString() ?? '',
      foto: json['foto'] ?? json['imagenUrl'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'correo': correo,
      'telefono': telefono,
      'cargo': cargo,
      'areaUsuario': areaUsuario,
      'modulos': modulos,
      'foto': foto,
    };
  }
}
