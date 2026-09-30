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

  /// Código SAP del empleado. Es lo que se MUESTRA en el perfil en lugar del
  /// [id]; el [id] se sigue usando para toda la funcionalidad (requests al WS).
  final String codigoSap;

  /// Departamento del empleado. Reemplaza a [areaUsuario] en la vista de perfil.
  final String departamento;

  /// Permisos del usuario, tal como los entrega el WS en `accesos`
  /// (el backend arma ahí `usuario.getModulos().toString()`, así que llega como
  /// texto tipo "[APPKM, EVENTOS]"). Es el campo con el que se decide si se ve
  /// el módulo de Rutas; [modulos] queda para los permisos que ya lo usaban.
  final String accesos;

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
    required this.genero,
    this.codigoSap = '',
    this.departamento = '',
    this.accesos = '',
  });

  /// `true` si el WS marca al usuario como dado de baja (`estado` = 1).
  ///
  /// Puede llegar como número o como texto. Si el campo no viene, o trae
  /// cualquier otro valor, el usuario se considera activo. La usan el login y
  /// la relectura del perfil, así las dos aplican la misma regla.
  static bool estadoInactivo(dynamic estado) {
    if (estado == null) return false;
    if (estado is num) return estado == 1;
    return estado.toString().trim() == '1';
  }

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
      codigoSap:
          (json['codigoSap'] ?? json['codigo_sap'] ?? json['codigoSAP'] ?? '')
              .toString(),
      departamento:
          (json['departamento'] ?? json['departamentoNombre'] ?? '').toString(),
      // Se cae a `modulos` para las sesiones guardadas antes de que el WS
      // empezara a mandar `accesos`.
      accesos: (json['accesos'] ?? json['modulos'] ?? '').toString(),
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
      'codigoSap': codigoSap,
      'departamento': departamento,
      'accesos': accesos,
    };
  }
}
