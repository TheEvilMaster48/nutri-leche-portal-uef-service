class Usuario {
  final int id;
  final String nombre;
  final String correo;
  final String telefono;
  final String cargo;
  final String areaUsuario;
  final String modulos;

  Usuario({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.telefono,
    required this.cargo,
    required this.areaUsuario,
    required this.modulos,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? '',
      correo: json['correo'] ?? '',
      telefono: json['telefono'] ?? '',
      cargo: json['cargo'] ?? '',
      areaUsuario: json['areaUsuario'] ?? '',
      modulos: json['modulos'] ?? '',
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
    };
  }

  String get nombreCompleto => nombre;
}
