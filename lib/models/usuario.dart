class Usuario {
  final int id;              
  final String nombre;       
  final String correo;       
  final String telefono;     
  final String cargo;        
  final String areaUsuario;  
  final String modulos;      
  final String usuario;      
  final String centro;       
  final String? cedula;  
  final String? genero;    

  Usuario({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.telefono,
    required this.cargo,
    required this.areaUsuario,
    required this.modulos,
    required this.usuario,
    required this.centro,
    required this.cedula,
    required this.genero
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
      usuario: json['usuario'] ?? '',
      centro: json['centro']?.toString() ?? '',
      cedula: json['cedula'] ??
          json['usuCedula'] ??
          json['documento'] ??
          json['dni'] ??
          json['ci'],
      genero: json['genero'] ?? '',
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
      'usuario': usuario,
      'centro': centro,
      'cedula': cedula,
      'genero': genero,
    };
  }
}
