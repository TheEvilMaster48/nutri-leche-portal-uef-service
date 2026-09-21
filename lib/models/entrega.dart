/// En qué punto de la ruta está una entrega.
///
/// Lo resuelve el servidor y llega ya calculado. No se deduce en el cliente: si
/// cada app lo dedujera, al cambiar una regla habría dos versiones de la verdad.
enum EstadoRutaEntrega {
  pendiente('PENDIENTE', 'Pendiente'),
  enCliente('EN_CLIENTE', 'En el cliente'),
  entregado('ENTREGADO', 'Entregado'),
  noEntregado('NO_ENTREGADO', 'No entregado');

  const EstadoRutaEntrega(this.codigo, this.etiqueta);

  /// Lo que viaja en el campo `hito` de `/marcar_entrega`.
  final String codigo;

  final String etiqueta;

  /// Cerrada es cerrada, se haya entregado o no.
  bool get cerrada => this == entregado || this == noEntregado;

  /// Solo el no entregado exige explicar por qué.
  bool get requiereMotivo => this == noEntregado;

  /// Acepta minúsculas y espacio en vez de guion bajo, igual que el servidor, y
  /// `LLEGADA` como alias de [enCliente] — que es como lo dice el botón.
  static EstadoRutaEntrega? desdeCodigo(String? valor) {
    if (valor == null) return null;
    final v = valor.trim().toUpperCase().replaceAll(' ', '_');
    for (final e in values) {
      if (e.codigo == v) return e;
    }
    return v == 'LLEGADA' ? enCliente : null;
  }
}

/// Una entrega del viaje: a quién va el producto y en qué punto va.
///
/// **Es lo único que el chofer marca por cliente.** Lo demás —almuerzo, falla
/// mecánica, descarga— le pasa al camión con todas las entregas a bordo y va en
/// los eventos del viaje ([EventoMarcado]). Pero llegar a un cliente y dejarle el
/// producto es de esta entrega y de ninguna otra.
class Entrega {
  final int id;

  /// Número de entrega del ERP, p. ej. `80012345`. Es texto, no número.
  final String numero;

  final String cliente;
  final String ciudad;

  /// Referencia del cliente.
  final String referencia;

  final EstadoRutaEntrega estadoRuta;

  /// El estado en palabras, redactado por el servidor. Se prefiere sobre
  /// cualquier texto propio: así el ERP y la app dicen lo mismo.
  final String estadoRutaEtiqueta;

  /// `dd/MM/yyyy HH:mm`, ya formateadas para pintar. Vacías si no aplica.
  final String llegadaEn;
  final String cerradaEn;

  /// Por qué no se pudo entregar. Solo cuando quedó no entregada.
  final String motivo;

  /// Qué botón habilitar. `null` cuando la entrega ya se cerró.
  ///
  /// Viene del servidor y manda: la app habilita lo que le dicen, no lo deduce.
  final EstadoRutaEntrega? siguienteAccion;

  const Entrega({
    required this.id,
    this.numero = '',
    this.cliente = '',
    this.ciudad = '',
    this.referencia = '',
    this.estadoRuta = EstadoRutaEntrega.pendiente,
    this.estadoRutaEtiqueta = '',
    this.llegadaEn = '',
    this.cerradaEn = '',
    this.motivo = '',
    this.siguienteAccion,
  });

  bool get cerrada => estadoRuta.cerrada;

  /// El estado para pintar, con el código de respaldo por si el servidor no
  /// manda la etiqueta.
  String get estadoTexto => estadoRutaEtiqueta.trim().isNotEmpty
      ? estadoRutaEtiqueta.trim()
      : estadoRuta.etiqueta;

  /// Cliente y ciudad en una línea, omitiendo lo que venga vacío.
  String get destino {
    final partes = [cliente, ciudad].where((p) => p.trim().isNotEmpty);
    return partes.join(' · ');
  }

  factory Entrega.fromJson(Map<String, dynamic> json) => Entrega(
        id: _aInt(json['id']),
        numero: _aTexto(json['numero']).trim(),
        cliente: _aTexto(json['cliente']).trim(),
        ciudad: _aTexto(json['ciudad']).trim(),
        referencia: _aTexto(json['referencia']).trim(),
        // Un estado desconocido cae en pendiente, que es lo seguro: preferible a
        // ocultar una entrega que sigue abierta.
        estadoRuta: EstadoRutaEntrega.desdeCodigo(json['estadoRuta']?.toString()) ??
            EstadoRutaEntrega.pendiente,
        estadoRutaEtiqueta: _aTexto(json['estadoRutaEtiqueta']).trim(),
        llegadaEn: _aTexto(json['llegadaEn']).trim(),
        cerradaEn: _aTexto(json['cerradaEn']).trim(),
        motivo: _aTexto(json['motivo']).trim(),
        siguienteAccion:
            EstadoRutaEntrega.desdeCodigo(json['siguienteAccion']?.toString()),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'numero': numero,
        'cliente': cliente,
        'ciudad': ciudad,
        'referencia': referencia,
        'estadoRuta': estadoRuta.codigo,
        'estadoRutaEtiqueta': estadoRutaEtiqueta,
        'llegadaEn': llegadaEn,
        'cerradaEn': cerradaEn,
        'motivo': motivo,
        'siguienteAccion': siguienteAccion?.codigo,
      };

  @override
  String toString() => 'Entrega($id, $numero, ${estadoRuta.codigo})';
}

int _aInt(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

String _aTexto(dynamic v) => v?.toString() ?? '';
