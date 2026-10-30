import 'dart:convert';

/// Respuesta de `appOficial/api/v1/chatbot/responder`.
///
/// El `data` del sobre `{correcto, mensaje, data}` llega como **JSON dentro de
/// un string**: [ChatbotRespuesta.desdeData] acepta las dos formas por si el
/// backend algún día lo manda ya como objeto.
class ChatbotRespuesta {
  ChatbotRespuesta({
    this.opcion,
    this.bloques = const [],
    this.opciones = const [],
  });

  /// La opción respondida; `null` en el menú inicial.
  final ChatbotOpcion? opcion;

  /// Lo que dice el bot, ya ordenado por `orden`.
  final List<ChatbotBloque> bloques;

  /// Los botones que siguen.
  final List<ChatbotOpcion> opciones;

  factory ChatbotRespuesta.desdeData(dynamic data) {
    final Map<String, dynamic> map =
        data is String
            ? (data.trim().isEmpty
                ? {}
                : jsonDecode(data) as Map<String, dynamic>)
            : (data as Map?)?.cast<String, dynamic>() ?? {};

    final bloques =
        _lista(map['bloques']).map(ChatbotBloque.fromJson).toList()
          ..sort((a, b) => a.orden.compareTo(b.orden));

    return ChatbotRespuesta(
      opcion:
          map['opcion'] is Map
              ? ChatbotOpcion.fromJson(_mapa(map['opcion']))
              : null,
      bloques: bloques,
      opciones: _lista(map['opciones']).map(ChatbotOpcion.fromJson).toList(),
    );
  }
}

class ChatbotOpcion {
  ChatbotOpcion({
    required this.id,
    required this.titulo,
    this.idPadre,
    this.icono,
  });

  final int id;
  final String titulo;

  /// A dónde lleva «Volver»; `null` cuando el padre es el menú inicial.
  final int? idPadre;
  final String? icono;

  factory ChatbotOpcion.fromJson(Map<String, dynamic> json) => ChatbotOpcion(
    id: _entero(json['id']) ?? 0,
    titulo: (json['titulo'] ?? '').toString(),
    idPadre: _entero(json['idPadre']),
    icono: json['icono']?.toString(),
  );
}

enum FormatoBloque { texto, lista, tabla, tarjeta, link, archivo }

class ChatbotBloque {
  ChatbotBloque({
    required this.orden,
    required this.formato,
    this.titulo = '',
    this.texto = '',
    this.vacio = false,
    this.error = false,
    this.columnas = const [],
    this.filas = const [],
    this.tarjetas = const [],
    this.enlaces = const [],
  });

  final int orden;
  final FormatoBloque formato;
  final String titulo;
  final String texto;

  /// Sin datos (o al usuario le falta un dato, p. ej. código SAP): se muestra
  /// [texto] como burbuja informativa, no como error.
  final bool vacio;

  /// Falló el origen de datos en el backend.
  final bool error;

  final List<ChatbotColumna> columnas;

  /// Valores ya formateados por el backend, indexados por `campo`.
  final List<Map<String, String>> filas;
  final List<ChatbotTarjeta> tarjetas;
  final List<ChatbotEnlace> enlaces;

  factory ChatbotBloque.fromJson(Map<String, dynamic> json) => ChatbotBloque(
    orden: _entero(json['orden']) ?? 0,
    formato: _formato(json['formato']),
    titulo: (json['titulo'] ?? '').toString(),
    texto: (json['texto'] ?? '').toString(),
    vacio: json['vacio'] == true,
    error: json['error'] == true,
    columnas: _lista(json['columnas']).map(ChatbotColumna.fromJson).toList(),
    filas:
        _lista(json['filas'])
            .map((f) => f.map((k, v) => MapEntry(k, v?.toString() ?? '')))
            .toList(),
    tarjetas: _lista(json['tarjetas']).map(ChatbotTarjeta.fromJson).toList(),
    enlaces: _lista(json['enlaces']).map(ChatbotEnlace.fromJson).toList(),
  );

  /// Un formato desconocido se pinta como texto para no perder el mensaje.
  static FormatoBloque _formato(dynamic valor) {
    switch ((valor ?? '').toString().toUpperCase()) {
      case 'LISTA':
        return FormatoBloque.lista;
      case 'TABLA':
        return FormatoBloque.tabla;
      case 'TARJETA':
        return FormatoBloque.tarjeta;
      case 'LINK':
        return FormatoBloque.link;
      case 'ARCHIVO':
        return FormatoBloque.archivo;
      default:
        return FormatoBloque.texto;
    }
  }
}

class ChatbotColumna {
  ChatbotColumna({required this.campo, required this.etiqueta, this.tipo});

  final String campo;
  final String etiqueta;
  final String? tipo;

  factory ChatbotColumna.fromJson(Map<String, dynamic> json) => ChatbotColumna(
    campo: (json['campo'] ?? '').toString(),
    etiqueta: (json['etiqueta'] ?? json['campo'] ?? '').toString(),
    tipo: json['tipo']?.toString(),
  );
}

class ChatbotTarjeta {
  ChatbotTarjeta({
    this.titulo = '',
    this.subtitulo = '',
    this.imagen = '',
    this.campos = const [],
  });

  final String titulo;
  final String subtitulo;

  /// URL; puede venir vacía.
  final String imagen;
  final List<MapEntry<String, String>> campos;

  factory ChatbotTarjeta.fromJson(Map<String, dynamic> json) => ChatbotTarjeta(
    titulo: (json['titulo'] ?? '').toString(),
    subtitulo: (json['subtitulo'] ?? '').toString(),
    imagen: (json['imagen'] ?? '').toString(),
    campos:
        _lista(json['campos'])
            .map(
              (c) => MapEntry(
                (c['etiqueta'] ?? '').toString(),
                (c['valor'] ?? '').toString(),
              ),
            )
            .toList(),
  );
}

class ChatbotEnlace {
  ChatbotEnlace({required this.texto, required this.url});

  final String texto;
  final String url;

  factory ChatbotEnlace.fromJson(Map<String, dynamic> json) => ChatbotEnlace(
    texto: (json['texto'] ?? json['url'] ?? '').toString(),
    url: (json['url'] ?? '').toString(),
  );
}

List<Map<String, dynamic>> _lista(dynamic valor) =>
    valor is List ? valor.whereType<Map>().map(_mapa).toList() : const [];

Map<String, dynamic> _mapa(dynamic valor) =>
    (valor as Map).map((k, v) => MapEntry(k.toString(), v));

int? _entero(dynamic valor) =>
    valor is int ? valor : int.tryParse(valor?.toString() ?? '');
