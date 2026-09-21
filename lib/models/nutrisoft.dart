/// Mensaje del módulo Nutrisoft.
///
/// A diferencia de `Evento` solo trae título y descripción: no hay imágenes,
/// videos, archivos ni fecha/hora. El resto del ciclo (pendiente → visto →
/// eliminado) es idéntico al de eventos.
///
/// El backend los llama "mensajes" (REST `appMensaje`), de ahí [idMensaje].
class Nutrisoft {
  final int idMensaje;
  final String titulo;
  final String descripcion;

  /// Campo `visto` tal como lo manda el backend: 0 = no visto, 1 = visto.
  ///
  /// A diferencia de eventos y cumpleaños (que usan `estado`), aquí el
  /// eliminado no viaja en este campo: se resuelve con la lista local de
  /// ocultos y con que el WS deje de devolver el registro.
  int visto;

  String get id => idMensaje.toString();

  bool get pendiente => visto == 0;

  /// Si el comunicado habla de un viaje del chofer.
  ///
  /// El WS de mensajes no trae un campo que lo diga: los avisos del módulo de
  /// rutas llegan por el mismo `appMensaje` que el resto, sin metadata propia.
  /// Así que se deduce del texto, que es lo único que hay. Se piden dos señales
  /// (una palabra de viaje + una de ruta/entrega, o "viaje" en el título) para
  /// no poner el botón en cualquier comunicado que mencione la palabra de paso.
  ///
  /// Cuando la notificación llega por push, `PushService` sí sabe que es de
  /// viaje por el `data`, y manda el dato explícito a la pantalla de detalle;
  /// esta heurística cubre el caso de abrir el mensaje desde el listado.
  bool get esDeViaje {
    final tituloBajo = _sinTildes(titulo);
    if (tituloBajo.contains('viaje')) return true;

    final texto = '$tituloBajo ${_sinTildes(descripcion)}';
    final hablaDeViaje = texto.contains('viaje') || texto.contains('ruta');
    if (!hablaDeViaje) return false;

    return texto.contains('chofer') ||
        texto.contains('entrega') ||
        texto.contains('transport') ||
        texto.contains('guia') ||
        texto.contains('despacho') ||
        texto.contains('asignad');
  }

  static String _sinTildes(String texto) {
    var t = texto.toLowerCase();
    const acentos = {
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
    };
    acentos.forEach((con, sin) => t = t.replaceAll(con, sin));
    return t;
  }

  Nutrisoft({
    required this.idMensaje,
    required this.titulo,
    required this.descripcion,
    this.visto = 0,
  });

  Map<String, dynamic> toJson() => {
        'idMensaje': idMensaje,
        'titulo': titulo,
        'descripcion': descripcion,
        'visto': visto,
      };

  factory Nutrisoft.fromJson(Map<String, dynamic> json) {
    final rawId = json['idMensaje'] ?? json['idNutrisoft'] ?? json['id'] ?? 0;

    // Se acepta `estado` como alias por si algún registro viejo lo trae así.
    final rawVisto = json['visto'] ?? json['estado'];

    return Nutrisoft(
      idMensaje: rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0,
      titulo: (json['titulo'] ?? json['asunto'] ?? '').toString(),
      descripcion:
          (json['descripcion'] ?? json['mensaje'] ?? json['detalle'] ?? '')
              .toString(),
      visto: rawVisto != null ? int.tryParse(rawVisto.toString()) ?? 0 : 0,
    );
  }
}
