import 'dart:convert';

/// Reacciones disponibles sobre un evento o un cumpleaños.
///
/// El `codigo` es el valor canónico que espera el backend (`ME_GUSTA`,
/// `ME_ENCANTA`, `FELICITACIONES`, `DIVERTIDO`, `SORPRESA`, `TRISTE`), el
/// `emoji` es lo que ve el usuario y la `etiqueta` se usa en tooltips /
/// accesibilidad.
///
/// El backend acepta varios alias por reacción (LIKE, PULGAR, 👍, …) y los
/// normaliza al código canónico; [porCodigo] replica esa misma tabla para poder
/// interpretar cualquier forma que llegue en la respuesta, incluidos los
/// códigos antiguos que esta app usaba antes (`megusta`, `corazon`, …).
enum TipoReaccion {
  meGusta('ME_GUSTA', '👍', 'Me gusta'),
  meEncanta('ME_ENCANTA', '❤️', 'Me encanta'),
  felicitaciones('FELICITACIONES', '🎉', 'Felicitaciones'),
  divertido('DIVERTIDO', '😂', 'Divertido'),
  sorpresa('SORPRESA', '😮', 'Sorpresa'),
  triste('TRISTE', '😢', 'Triste');

  const TipoReaccion(this.codigo, this.emoji, this.etiqueta);

  final String codigo;
  final String emoji;
  final String etiqueta;

  /// Tabla de alias → código canónico (la misma que aplica el backend, más los
  /// códigos históricos de la app).
  static const Map<String, TipoReaccion> _alias = {
    // ME_GUSTA
    'ME_GUSTA': TipoReaccion.meGusta,
    'MEGUSTA': TipoReaccion.meGusta,
    'LIKE': TipoReaccion.meGusta,
    'GUSTA': TipoReaccion.meGusta,
    'PULGAR': TipoReaccion.meGusta,
    'PULGAR_ARRIBA': TipoReaccion.meGusta,
    '👍': TipoReaccion.meGusta,

    // ME_ENCANTA
    'ME_ENCANTA': TipoReaccion.meEncanta,
    'MEENCANTA': TipoReaccion.meEncanta,
    'LOVE': TipoReaccion.meEncanta,
    'ENCANTA': TipoReaccion.meEncanta,
    'CORAZON': TipoReaccion.meEncanta,
    '❤': TipoReaccion.meEncanta,
    '😍': TipoReaccion.meEncanta,

    // FELICITACIONES
    'FELICITACIONES': TipoReaccion.felicitaciones,
    'CELEBRATE': TipoReaccion.felicitaciones,
    'CELEBRAR': TipoReaccion.felicitaciones,
    'FELICIDADES': TipoReaccion.felicitaciones,
    'FELICITAR': TipoReaccion.felicitaciones,
    'APLAUSO': TipoReaccion.felicitaciones,
    'APLAUSOS': TipoReaccion.felicitaciones,
    '👏': TipoReaccion.felicitaciones,
    '🎉': TipoReaccion.felicitaciones,

    // DIVERTIDO
    'DIVERTIDO': TipoReaccion.divertido,
    'HAHA': TipoReaccion.divertido,
    'JAJA': TipoReaccion.divertido,
    'FUNNY': TipoReaccion.divertido,
    'RISA': TipoReaccion.divertido,
    '😂': TipoReaccion.divertido,
    '🤣': TipoReaccion.divertido,

    // SORPRESA
    'SORPRESA': TipoReaccion.sorpresa,
    'WOW': TipoReaccion.sorpresa,
    'ASOMBRO': TipoReaccion.sorpresa,
    'SORPRENDIDO': TipoReaccion.sorpresa,
    '😮': TipoReaccion.sorpresa,
    '😲': TipoReaccion.sorpresa,

    // TRISTE
    'TRISTE': TipoReaccion.triste,
    'SAD': TipoReaccion.triste,
    'TRISTEZA': TipoReaccion.triste,
    '😢': TipoReaccion.triste,
    '😭': TipoReaccion.triste,
  };

  static TipoReaccion? porCodigo(String? codigo) {
    if (codigo == null) return null;

    // Se normaliza igual que el backend: mayúsculas, sin espacios/guiones y sin
    // el selector de variación (U+FE0F) que acompaña a emojis como el corazón.
    final c = codigo
        .trim()
        .toUpperCase()
        .replaceAll('\uFE0F', '')
        .replaceAll(RegExp(r'[\s\-]+'), '_');

    if (c.isEmpty) return null;
    return _alias[c];
  }
}

/// Origen del contenido reaccionado. El backend comparte tabla de eventos para
/// cumpleaños (igual que `evento_id_visto`), pero se envía el origen para que
/// pueda diferenciarlos si más adelante los separa.
class OrigenReaccion {
  static const String evento = 'evento';
  static const String cumpleanios = 'cumpleanios';
}

/// Conteo de reacciones de un contenido + la reacción del usuario actual.
class ResumenReacciones {
  ResumenReacciones({
    Map<TipoReaccion, int>? conteos,
    this.miReaccion,
  }) : conteos = conteos ?? {};

  final Map<TipoReaccion, int> conteos;
  TipoReaccion? miReaccion;

  int get total => conteos.values.fold(0, (a, b) => a + b);

  int conteoDe(TipoReaccion tipo) => conteos[tipo] ?? 0;

  ResumenReacciones copy() => ResumenReacciones(
        conteos: Map<TipoReaccion, int>.from(conteos),
        miReaccion: miReaccion,
      );

  /// Aplica localmente el efecto de tocar [tipo]:
  /// - si ya era la reacción del usuario, la quita;
  /// - si tenía otra, la mueve;
  /// - si no tenía ninguna, la agrega.
  ///
  /// Devuelve `true` si al final el usuario queda reaccionando con [tipo].
  bool alternarLocal(TipoReaccion tipo) {
    final anterior = miReaccion;

    if (anterior == tipo) {
      _sumar(tipo, -1);
      miReaccion = null;
      return false;
    }

    if (anterior != null) _sumar(anterior, -1);
    _sumar(tipo, 1);
    miReaccion = tipo;
    return true;
  }

  void _sumar(TipoReaccion tipo, int delta) {
    final nuevo = (conteos[tipo] ?? 0) + delta;
    if (nuevo <= 0) {
      conteos.remove(tipo);
    } else {
      conteos[tipo] = nuevo;
    }
  }

  Map<String, dynamic> toJson() => {
        'conteos': {
          for (final e in conteos.entries) e.key.codigo: e.value,
        },
        'miReaccion': miReaccion?.codigo,
      };

  // -------------------------
  // Lectura de las respuestas del WS
  // -------------------------

  static int _aInt(dynamic v) =>
      v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

  /// Lee el tipo de una fila, aceptando los nombres de campo que puede usar el
  /// backend.
  static TipoReaccion? _tipoDe(Map m) => TipoReaccion.porCodigo((m['tipo'] ??
          m['reaccion'] ??
          m['codigo'] ??
          m['tipoReaccion'] ??
          m['nombre'] ??
          m['emoji'])
      ?.toString());

  /// Conteo de una fila agregada. `null` si la fila no trae total (entonces la
  /// fila representa a UN usuario y cuenta como 1).
  static int? _conteoDe(Map m) {
    final raw = m['total'] ??
        m['conteo'] ??
        m['cantidad'] ??
        m['count'] ??
        m['numero'];
    if (raw == null) return null;
    return raw is int ? raw : int.tryParse(raw.toString());
  }

  static int _usuarioDe(Map m) => _aInt(
      m['idUsuario'] ?? m['idusuario'] ?? m['usuario'] ?? m['idEmpleado']);

  /// Construye el resumen desde la respuesta de `/reacciones_evento`,
  /// `/evento_reaccion` o `/quitar_reaccion`.
  ///
  /// El WS contesta con el sobre `{mensaje, correcto, data}` y `data` puede
  /// venir de varias formas; se aceptan todas:
  ///
  ///  - lista agregada:      `[{tipo: "ME_GUSTA", total: 3}, ...]`
  ///  - lista por usuario:   `[{idUsuario: 42, tipo: "ME_GUSTA"}, ...]`
  ///  - mapa de conteos:     `{"ME_GUSTA": 3, "TRISTE": 1}`
  ///  - objeto con lista:    `{conteos|reacciones|lista|detalle: [...], miReaccion: "..."}`
  ///  - una sola reacción:   `{tipo: "ME_GUSTA"}` o `"ME_GUSTA"`
  ///
  /// [idUsuario] permite deducir `miReaccion` cuando la respuesta es una lista
  /// por usuario y no trae el campo explícito.
  static ResumenReacciones desdeRespuesta(dynamic raw, {int idUsuario = 0}) {
    final resumen = ResumenReacciones();

    // Desenvuelve el sobre {mensaje, correcto, data}.
    dynamic data = raw;
    if (data is Map &&
        data.containsKey('data') &&
        data['conteos'] == null &&
        data['reacciones'] == null) {
      data = data['data'];
    }

    // OJO: el WS manda `data` como STRING con el JSON adentro
    // ("data":"{\"total\":2,...}"), no como objeto. Se decodifica antes de
    // interpretarlo; el `while` cubre un doble escapado.
    var intentos = 0;
    while (data is String && intentos < 3) {
      final texto = data.trim();
      if (!texto.startsWith('{') && !texto.startsWith('[')) break;
      try {
        data = json.decode(texto);
      } catch (_) {
        break;
      }
      intentos++;
    }

    if (data == null) return resumen;

    // Un string suelto (ya no JSON) es la reacción del usuario.
    if (data is String) {
      resumen.miReaccion = TipoReaccion.porCodigo(data);
      return resumen;
    }

    if (data is Map) {
      resumen.miReaccion = TipoReaccion.porCodigo((data['miReaccion'] ??
              data['reaccionUsuario'] ??
              data['miTipo'] ??
              data['tipoUsuario'] ??
              data['miEmoji'])
          ?.toString());
    }

    // Localiza la colección de reacciones.
    dynamic coleccion = data;
    if (data is Map) {
      coleccion = data['conteos'] ??
          data['reacciones'] ??
          data['resumen'] ??
          data['lista'] ??
          data['detalle'] ??
          data['listaReacciones'] ??
          data;
    }

    void acumular(TipoReaccion? tipo, int n) {
      if (tipo == null || n <= 0) return;
      resumen.conteos[tipo] = (resumen.conteos[tipo] ?? 0) + n;
    }

    if (coleccion is List) {
      for (final item in coleccion) {
        if (item is String) {
          acumular(TipoReaccion.porCodigo(item), 1);
          continue;
        }
        if (item is! Map) continue;

        final tipo = _tipoDe(item);
        if (tipo == null) continue;

        final n = _conteoDe(item);
        if (n != null) {
          acumular(tipo, n);
        } else {
          // Fila por usuario: cuenta 1 y sirve para detectar la reacción propia.
          acumular(tipo, 1);
          if (idUsuario > 0 && _usuarioDe(item) == idUsuario) {
            resumen.miReaccion = tipo;
          }
        }
      }
    } else if (coleccion is Map) {
      // Mapa {codigo: n}. Si ninguna llave es un tipo válido, puede tratarse de
      // una sola reacción ({tipo: "ME_GUSTA"}), que se resuelve más abajo.
      coleccion.forEach((k, v) {
        acumular(TipoReaccion.porCodigo(k?.toString()), _aInt(v));
      });
    }

    // Respuesta de una sola reacción (típico de /evento_reaccion).
    if (data is Map && resumen.miReaccion == null) {
      resumen.miReaccion = _tipoDe(data);
    }

    return resumen;
  }

  factory ResumenReacciones.fromJson(Map<String, dynamic> json) {
    // El backend puede devolver los conteos como mapa {codigo: n} o como lista
    // [{tipo: 'ME_GUSTA', total: 3}]. Se aceptan ambas formas.
    //
    // Varios alias pueden colapsar en el mismo tipo (p. ej. APLAUSO y CELEBRAR
    // → FELICITACIONES), así que los conteos se suman en vez de sobreescribirse.
    final conteos = <TipoReaccion, int>{};
    final crudo = json['conteos'] ?? json['reacciones'] ?? json['resumen'];

    void acumular(TipoReaccion? tipo, int n) {
      if (tipo == null || n <= 0) return;
      conteos[tipo] = (conteos[tipo] ?? 0) + n;
    }

    if (crudo is Map) {
      crudo.forEach((k, v) {
        final n = v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
        acumular(TipoReaccion.porCodigo(k?.toString()), n);
      });
    } else if (crudo is List) {
      for (final item in crudo) {
        if (item is! Map) continue;
        final tipo = TipoReaccion.porCodigo(
          (item['tipo'] ?? item['reaccion'] ?? item['codigo'])?.toString(),
        );
        final rawN = item['total'] ?? item['conteo'] ?? item['cantidad'];
        final n = rawN is int ? rawN : int.tryParse(rawN?.toString() ?? '') ?? 0;
        acumular(tipo, n);
      }
    }

    return ResumenReacciones(
      conteos: conteos,
      miReaccion: TipoReaccion.porCodigo(
        (json['miReaccion'] ?? json['reaccionUsuario'] ?? json['miTipo'])
            ?.toString(),
      ),
    );
  }
}
