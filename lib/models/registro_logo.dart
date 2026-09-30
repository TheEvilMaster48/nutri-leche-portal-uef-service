import 'package:intl/intl.dart';

import 'parametro.dart';

/// Un registro de captura del módulo Logo Nutri.
///
/// Nace en el teléfono —con fotos, ubicación y hora del dispositivo— y vive en
/// la cola local hasta que el servidor lo acepta.
///
/// Las cuatro opciones elegidas se guardan como **texto**, no como id: el
/// catálogo de `/parametros` devuelve listas de cadenas sin identificador, así
/// que el valor es el dato. Ver [CatalogoParametros].
class RegistroLogo {
  /// Id local. Es el epoch en milisegundos del momento de guardar: sirve de
  /// identificador y de orden de encolado a la vez.
  final int id;

  /// Id del usuario del portal. Viaja como `responsable`: el WS lo usa para
  /// enlazar la relación y mostrar responsable y área en la pantalla web.
  final int idUsuario;

  /// Login del usuario conectado (`ACUESTA`), copiado al capturar. Viaja como
  /// `usuarioCreacion`.
  final String usuarioCreacion;

  /// **Nombres de archivo**, no rutas absolutas.
  ///
  /// En iOS la carpeta de documentos lleva un UUID que cambia al reinstalar o
  /// actualizar la app: una ruta absoluta guardada hoy apunta a la nada mañana
  /// y las fotos de la cola se «pierden» sin haberse borrado. La ruta se
  /// resuelve al leer, contra el directorio del momento.
  final List<String> fotos;

  /// `tipoMaterial` del catálogo: ROTULO, PERCHA, AFICHE…
  final String tipoMaterial;

  final int cantidad;

  /// `entorno`: INTERIOR, EXTERIOR, FACHADA…
  final String entorno;

  /// `estado` del material: BUENO, REGULAR, DETERIORADO…
  ///
  /// Se llama así y no `estado` a secas para no confundirlo con [estado], que
  /// es el estado del **envío** del registro.
  final String estadoMaterial;

  /// `accion`: REPONER, RETIRAR, REPARAR, NINGUNA…
  final String accion;

  /// Ciudad donde se capturó. Opcional para el WS.
  final String ciudad;

  /// Local o punto de venta: «SUPERMAXI LA Y». Opcional.
  final String establecimiento;

  /// Qué se observó. Opcional.
  final String descripcion;

  /// Cómo llegar o dónde está exactamente el elemento, en palabras. Opcional,
  /// y distinto de las coordenadas: el GPS dice el punto, esto dice el sitio.
  final String referenciaUbicacion;

  /// Coordenadas del GPS al capturar. Nulas si el teléfono no pudo fijar
  /// posición y el usuario decidió guardar igual.
  final double? latitud;
  final double? longitud;

  /// Radio de error en metros que reportó el GPS.
  final double? precision;

  /// Fecha y hora del dispositivo al guardar. No se toma del servidor: el
  /// registro puede crearse sin señal, y lo que importa es cuándo se capturó.
  final DateTime fechaHora;

  /// En qué punto del camino al servidor está.
  final EstadoRegistro estado;

  /// Cuántas veces se intentó enviar. Se muestra en la cola.
  final int intentos;

  /// Motivo del último intento fallido, tal como lo dio el servidor o la red.
  final String? ultimoError;

  /// Nombres con los que el servidor de archivos guardó las fotos. Se llenan
  /// cuando la subida sale bien, antes de mandar el registro: si el POST falla
  /// después, el reintento no vuelve a subir las mismas imágenes.
  final List<String> fotosSubidas;

  const RegistroLogo({
    required this.id,
    required this.idUsuario,
    required this.usuarioCreacion,
    required this.fotos,
    required this.tipoMaterial,
    required this.cantidad,
    required this.entorno,
    required this.estadoMaterial,
    required this.accion,
    required this.fechaHora,
    this.ciudad = '',
    this.establecimiento = '',
    this.descripcion = '',
    this.referenciaUbicacion = '',
    this.latitud,
    this.longitud,
    this.precision,
    this.estado = EstadoRegistro.pendiente,
    this.intentos = 0,
    this.ultimoError,
    this.fotosSubidas = const [],
  });

  bool get tieneUbicacion => latitud != null && longitud != null;

  /// Cuántas fotos trae. El formulario exige entre 1 y 3.
  int get totalFotos => fotos.length;

  RegistroLogo copyWith({
    EstadoRegistro? estado,
    int? intentos,
    String? ultimoError,
    bool limpiarError = false,
    List<String>? fotosSubidas,
  }) {
    return RegistroLogo(
      id: id,
      idUsuario: idUsuario,
      usuarioCreacion: usuarioCreacion,
      fotos: fotos,
      tipoMaterial: tipoMaterial,
      cantidad: cantidad,
      entorno: entorno,
      estadoMaterial: estadoMaterial,
      accion: accion,
      fechaHora: fechaHora,
      ciudad: ciudad,
      establecimiento: establecimiento,
      descripcion: descripcion,
      referenciaUbicacion: referenciaUbicacion,
      latitud: latitud,
      longitud: longitud,
      precision: precision,
      estado: estado ?? this.estado,
      intentos: intentos ?? this.intentos,
      ultimoError: limpiarError ? null : (ultimoError ?? this.ultimoError),
      fotosSubidas: fotosSubidas ?? this.fotosSubidas,
    );
  }

  /// Cómo se guarda en la cola local.
  ///
  /// Usa las mismas claves que el WS para los cuatro parámetros, así lo que se
  /// ve en el teléfono y lo que se manda hablan el mismo idioma.
  Map<String, dynamic> toJson() => {
        'id': id,
        'idUsuario': idUsuario,
        'usuarioCreacion': usuarioCreacion,
        'fotos': fotos,
        'tipoMaterial': tipoMaterial,
        'cantidad': cantidad,
        'entorno': entorno,
        'estadoMaterial': estadoMaterial,
        'accion': accion,
        'ciudad': ciudad,
        'establecimiento': establecimiento,
        'descripcion': descripcion,
        'referenciaUbicacion': referenciaUbicacion,
        'latitud': latitud,
        'longitud': longitud,
        'precision': precision,
        'fechaHora': fechaHora.toIso8601String(),
        'estadoEnvio': estado.name,
        'intentos': intentos,
        'ultimoError': ultimoError,
        'fotosSubidas': fotosSubidas,
      };

  factory RegistroLogo.fromJson(Map<String, dynamic> json) {
    List<String> textos(dynamic valor) {
      if (valor is! List) return const [];
      return valor
          .map((e) => e?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return RegistroLogo(
      id: _entero(json['id']),
      idUsuario: _entero(json['idUsuario']),
      usuarioCreacion: json['usuarioCreacion']?.toString() ?? '',
      fotos: textos(json['fotos']),
      tipoMaterial: json['tipoMaterial']?.toString() ?? '',
      cantidad: _entero(json['cantidad']),
      entorno: json['entorno']?.toString() ?? '',
      estadoMaterial: json['estadoMaterial']?.toString() ?? '',
      accion: json['accion']?.toString() ?? '',
      ciudad: json['ciudad']?.toString() ?? '',
      establecimiento: json['establecimiento']?.toString() ?? '',
      descripcion: json['descripcion']?.toString() ?? '',
      referenciaUbicacion: json['referenciaUbicacion']?.toString() ?? '',
      latitud: _decimal(json['latitud']),
      longitud: _decimal(json['longitud']),
      precision: _decimal(json['precision']),
      fechaHora: DateTime.tryParse(json['fechaHora']?.toString() ?? '') ??
          DateTime.now(),
      estado: EstadoRegistro.desde(json['estadoEnvio']?.toString()),
      intentos: _entero(json['intentos']),
      ultimoError: json['ultimoError']?.toString(),
      fotosSubidas: textos(json['fotosSubidas']),
    );
  }

  /// Cuerpo de `POST /guardar_elemento`.
  ///
  /// Va aparte de [toJson] porque son dos contratos distintos: el de la cola
  /// local (que incluye el estado del envío, los intentos y los archivos del
  /// teléfono) y el del servidor.
  ///
  /// Detalles del contrato que se resuelven acá y en ningún otro lado:
  ///
  /// - `fotos` es **un string con los nombres separados por coma**, no un
  ///   arreglo.
  /// - `fechaCreacion` va en `dd/MM/yyyy HH:mm:ss`. Se manda siempre, aunque
  ///   el WS sepa poner la suya: lo que importa es cuándo se capturó, no
  ///   cuándo se logró enviar, y entre las dos cosas puede haber días.
  /// - El estado del material viaja como `estadoMaterial`, no como `estado`:
  ///   `estado` ya es el estado del registro del lado del servidor.
  /// - `precision` no está en el contrato, así que no se manda; queda en el
  ///   teléfono para poder juzgar una lectura dudosa.
  Map<String, dynamic> toEnvio() => {
        'fotos': fotosSubidas.join(','),
        FamiliaParametro.material.clave: tipoMaterial,
        'cantidad': cantidad,
        FamiliaParametro.entorno.clave: entorno,
        'latitud': latitud,
        'longitud': longitud,
        'estadoMaterial': estadoMaterial,
        FamiliaParametro.accion.clave: accion,
        // Los cuatro opcionales se omiten vacíos en lugar de mandar "": así el
        // WS guarda null y la pantalla web no muestra celdas con texto vacío.
        if (ciudad.isNotEmpty) 'ciudad': ciudad,
        if (establecimiento.isNotEmpty) 'establecimiento': establecimiento,
        if (descripcion.isNotEmpty) 'descripcion': descripcion,
        if (referenciaUbicacion.isNotEmpty)
          'referenciaUbicacion': referenciaUbicacion,
        'usuarioCreacion': usuarioCreacion,
        'fechaCreacion': fechaCreacionTexto,
        'responsable': idUsuario,
      };

  /// La fecha de captura en el formato que pide el WS.
  String get fechaCreacionTexto =>
      DateFormat('dd/MM/yyyy HH:mm:ss').format(fechaHora);

  static int _entero(dynamic valor) {
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();
    return int.tryParse(valor?.toString() ?? '') ?? 0;
  }

  static double? _decimal(dynamic valor) {
    if (valor == null) return null;
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor.toString());
  }

  @override
  String toString() =>
      'RegistroLogo($id, $tipoMaterial x$cantidad, ${estado.name})';
}

/// En qué punto del camino al servidor está un registro.
enum EstadoRegistro {
  /// Guardado en el teléfono, esperando envío.
  pendiente,

  /// Se está enviando ahora mismo.
  enviando,

  /// El servidor lo aceptó.
  enviado,

  /// El último intento falló. Sigue en la cola y se puede reintentar.
  error;

  static EstadoRegistro desde(String? nombre) {
    for (final e in EstadoRegistro.values) {
      if (e.name == nombre) return e;
    }
    return EstadoRegistro.pendiente;
  }

  String get etiqueta => switch (this) {
        EstadoRegistro.pendiente => 'Pendiente',
        EstadoRegistro.enviando => 'Enviando…',
        EstadoRegistro.enviado => 'Enviado',
        EstadoRegistro.error => 'Con error',
      };
}
