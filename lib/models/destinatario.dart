/// Punto de entrega de un viaje.
///
/// No se pide por separado: los destinatarios llegan dentro de la respuesta de
/// `cambiar_status_viaje` al iniciar el viaje, en el campo `dests`. El endpoint
/// `pots_destinatarios` que aparece declarado en la app Android **no existe en
/// producción** (responde 404), así que no hay que apoyarse en él.
class Destinatario {
  final int id;

  final String nombre;

  /// Dirección de entrega.
  ///
  /// En el cable la llave es `dirrecion` — errata del backend. Se lee también
  /// `direccion` por si alguna vez se corrige, pero al serializar se manda con
  /// la errata para no romper el contrato vigente.
  final String direccion;

  /// Número de entrega. Aquí llega como entero; en [Viaje] el mismo concepto
  /// llega como texto. La inconsistencia es del backend, así que cada modelo la
  /// absorbe con el tipo que realmente recibe.
  final int nentrega;

  final String ciudad;
  final String provincia;

  /// Código del destinatario.
  final String coddest;

  final String codcliente;
  final String nombreCliente;
  final String nombreTransp;
  final String codigoTransp;
  final String fechaLogistica;

  final String observaciones;
  final String fechaCreacion;
  final String usuarioCreacion;

  const Destinatario({
    required this.id,
    required this.nombre,
    this.direccion = '',
    this.nentrega = 0,
    this.ciudad = '',
    this.provincia = '',
    this.coddest = '',
    this.codcliente = '',
    this.nombreCliente = '',
    this.nombreTransp = '',
    this.codigoTransp = '',
    this.fechaLogistica = '',
    this.observaciones = '',
    this.fechaCreacion = '',
    this.usuarioCreacion = '',
  });

  /// Ciudad y provincia en una línea, para la tarjeta de la lista.
  String get ubicacion {
    final partes = [ciudad, provincia].where((p) => p.trim().isNotEmpty);
    return partes.join(', ');
  }

  factory Destinatario.fromJson(Map<String, dynamic> json) => Destinatario(
        id: _aInt(json['id']),
        nombre: _aTexto(json['nombre']).trim(),
        direccion: _aTexto(json['dirrecion'] ?? json['direccion']).trim(),
        nentrega: _aInt(json['nentrega']),
        ciudad: _aTexto(json['ciudad']).trim(),
        provincia: _aTexto(json['provincia']).trim(),
        coddest: _aTexto(json['coddest']),
        codcliente: _aTexto(json['codcliente']),
        nombreCliente: _aTexto(json['nombreCliente']).trim(),
        nombreTransp: _aTexto(json['nombreTransp']).trim(),
        codigoTransp: _aTexto(json['codigoTransp']),
        fechaLogistica: _aTexto(json['fechaLogistica']),
        observaciones: _aTexto(json['observaciones']),
        fechaCreacion: _aTexto(json['fechaCreacion']),
        usuarioCreacion: _aTexto(json['usuarioCreacion']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        // Con la errata del backend, a propósito. Ver [direccion].
        'dirrecion': direccion,
        'nentrega': nentrega,
        'ciudad': ciudad,
        'provincia': provincia,
        'coddest': coddest,
        'codcliente': codcliente,
        'nombreCliente': nombreCliente,
        'nombreTransp': nombreTransp,
        'codigoTransp': codigoTransp,
        'fechaLogistica': fechaLogistica,
        'observaciones': observaciones,
        'fechaCreacion': fechaCreacion,
        'usuarioCreacion': usuarioCreacion,
      };

  @override
  String toString() => 'Destinatario($id, $nombre, $ciudad)';
}

int _aInt(dynamic v) =>
    v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

String _aTexto(dynamic v) => v?.toString() ?? '';
