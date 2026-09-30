/// Las listas desplegables del módulo Logo Nutri, tal como las sirve
/// `GET logo/api/v1/parametros`.
///
/// El WS devuelve un **objeto de listas de texto plano**, una por campo:
///
/// ```json
/// {"correcto": true, "mensaje": "Lista de parametros",
///  "data": {"tipoMaterial": ["ROTULO","PERCHA","AFICHE"],
///           "entorno":      ["INTERIOR","EXTERIOR","FACHADA"],
///           "estado":       ["BUENO","REGULAR","DETERIORADO"],
///           "accion":       ["REPONER","RETIRAR","REPARAR","NINGUNA"]}}
/// ```
///
/// No hay ids ni códigos: **el valor es el dato**. Por eso el registro guarda y
/// manda el texto elegido tal cual, sin traducirlo a ningún identificador.
class CatalogoParametros {
  const CatalogoParametros({
    required this.porFamilia,
    this.clavesIgnoradas = const [],
  });

  const CatalogoParametros.vacio()
      : porFamilia = const {},
        clavesIgnoradas = const [];

  /// Las opciones de cada campo, en el orden en que las mandó el servidor.
  ///
  /// Ese orden es el del ERP y se respeta: `NINGUNA` va al final de las
  /// acciones porque así la pensó quien cargó el catálogo, y ordenar alfabético
  /// la subiría al principio.
  final Map<FamiliaParametro, List<String>> porFamilia;

  /// Claves de `data` que no corresponden a ningún campo del formulario.
  ///
  /// Se conservan para el diagnóstico: si el WS agrega una lista nueva, el
  /// síntoma no es el silencio sino un aviso con el nombre de la clave.
  final List<String> clavesIgnoradas;

  bool get vacio => porFamilia.values.every((v) => v.isEmpty);

  List<String> opciones(FamiliaParametro familia) =>
      porFamilia[familia] ?? const [];

  /// Total de opciones recibidas, para el diagnóstico.
  int get total =>
      porFamilia.values.fold(0, (suma, lista) => suma + lista.length);

  /// Lee el objeto `data`.
  ///
  /// Tolera dos cosas sin perder nada: que la clave venga escrita distinto
  /// (`tipoMaterial`, `tipo_material`, `TIPOMATERIAL` son la misma) y que
  /// algún día los elementos dejen de ser texto y pasen a ser objetos
  /// —`{"valor": "ROTULO"}`—, que es la evolución natural si el ERP les agrega
  /// un id. Lo que no reconoce no lo descarta en silencio: va a
  /// [clavesIgnoradas].
  factory CatalogoParametros.fromJson(Map<String, dynamic> data) {
    final porFamilia = <FamiliaParametro, List<String>>{};
    final ignoradas = <String>[];

    data.forEach((clave, valor) {
      final familia = FamiliaParametro.porClave(clave);
      if (familia == null) {
        ignoradas.add(clave);
        return;
      }
      final valores = _valores(valor);
      if (valores.isEmpty) return;
      // Si dos claves cayeran en la misma familia, se acumulan en vez de
      // pisarse.
      porFamilia.update(
        familia,
        (previas) => [...previas, ...valores],
        ifAbsent: () => valores,
      );
    });

    return CatalogoParametros(
      porFamilia: porFamilia,
      clavesIgnoradas: ignoradas,
    );
  }

  Map<String, dynamic> toJson() => {
        for (final entrada in porFamilia.entries)
          entrada.key.clave: entrada.value,
      };

  /// Los elementos de una lista como textos.
  ///
  /// Acepta `"ROTULO"` y también `{"valor": "ROTULO"}` o
  /// `{"descripcion": "ROTULO"}`, sin exigir ninguna de las dos formas.
  static List<String> _valores(dynamic lista) {
    if (lista is! List) return const [];

    final valores = <String>[];
    for (final elemento in lista) {
      final texto = _texto(elemento);
      // Se descartan los repetidos: dos opciones iguales en un desplegable son
      // un error en tiempo de ejecución de Flutter, no solo algo feo.
      if (texto.isNotEmpty && !valores.contains(texto)) valores.add(texto);
    }
    return valores;
  }

  static String _texto(dynamic elemento) {
    if (elemento == null) return '';
    if (elemento is String) return elemento.trim();
    if (elemento is Map) {
      for (final clave in const [
        'valor',
        'descripcion',
        'nombre',
        'detalle',
        'texto',
      ]) {
        final valor = elemento[clave];
        if (valor != null && valor.toString().trim().isNotEmpty) {
          return valor.toString().trim();
        }
      }
      return '';
    }
    return elemento.toString().trim();
  }
}

/// Cada desplegable del formulario y la clave con la que viaja al WS.
///
/// [clave] es a la vez el nombre que usa `data` al bajar el catálogo y el que
/// se manda al guardar el registro: son el mismo vocabulario, y mantenerlos
/// juntos evita que se separen con el tiempo.
enum FamiliaParametro {
  material('Tipo de material', 'tipoMaterial', ['TIPOMATERIAL', 'MATERIAL']),
  entorno('Entorno', 'entorno', ['ENTORNO', 'AMBIENTE']),
  estado('Estado', 'estado', ['ESTADO', 'CONDICION']),
  accion('Acción requerida', 'accion', ['ACCION', 'ACCIONREQUERIDA']);

  const FamiliaParametro(this.etiqueta, this.clave, this.alias);

  /// Cómo se llama el campo en pantalla.
  final String etiqueta;

  /// La clave del WS: `tipoMaterial`, `entorno`, `estado`, `accion`.
  final String clave;

  /// Otras formas del mismo nombre, ya normalizadas.
  final List<String> alias;

  /// A qué campo corresponde una clave de `data`, o `null` si a ninguno.
  static FamiliaParametro? porClave(String clave) {
    final normalizada = normalizar(clave);
    if (normalizada.isEmpty) return null;

    // Primero la coincidencia exacta: `estado` tiene que ser el estado aunque
    // otra familia lo contenga como fragmento.
    for (final familia in FamiliaParametro.values) {
      if (normalizar(familia.clave) == normalizada) return familia;
    }
    for (final familia in FamiliaParametro.values) {
      if (familia.alias.any(normalizada.contains)) return familia;
    }
    return null;
  }

  /// Mayúsculas, sin acentos y sin separadores: así `tipo_material`,
  /// `tipoMaterial` y `TIPO MATERIAL` son la misma clave.
  static String normalizar(String texto) {
    const conAcento = 'ÁÀÄÂÃÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑÇ';
    const sinAcento = 'AAAAAEEEEIIIIOOOOOUUUUNC';

    final buffer = StringBuffer();
    for (final rune in texto.toUpperCase().runes) {
      final caracter = String.fromCharCode(rune);
      final indice = conAcento.indexOf(caracter);
      final limpio = indice >= 0 ? sinAcento[indice] : caracter;
      if (RegExp(r'[A-Z0-9]').hasMatch(limpio)) buffer.write(limpio);
    }
    return buffer.toString();
  }
}
