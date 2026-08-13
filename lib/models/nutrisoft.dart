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
