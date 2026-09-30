import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../base/base.dart';
import '../models/registro_logo.dart';
import 'logo_api.dart';
import 'registro_logo_store.dart';

/// Resultado de intentar mandar un registro al servidor.
class ResultadoEnvio {
  final bool ok;
  final String mensaje;

  /// Si conviene volver a intentar más tarde (fallo de red) o no (el servidor
  /// entendió y rechazó, o el envío todavía no está habilitado).
  final bool reintentable;

  const ResultadoEnvio.exito([this.mensaje = 'Registro enviado.'])
    : ok = true,
      reintentable = false;

  const ResultadoEnvio.fallo(this.mensaje, {this.reintentable = true})
    : ok = false;
}

/// Captura y cola de envío del módulo Logo Nutri.
///
/// **Primero el teléfono, después el servidor.** Guardar un registro nunca
/// depende de la red: se escribe en la cola local y recién entonces se intenta
/// mandar. Si no hay señal, se queda en «Pendientes envío» y el usuario lo
/// reintenta cuando vuelva la cobertura.
///
/// ## Cómo viajan las fotos
///
/// Una petición por foto, las tres en paralelo, al `upload.php` del módulo.
/// Cada foto va en un formulario `x-www-form-urlencoded` con los campos
/// `base64` (la imagen) e `ImageName` (el nombre): es lo que leen los
/// `upload.php` de servicioslsa, igual que en las apps de producción y
/// autoventa. En multipart el PHP no encuentra esos campos, no guarda nada y
/// aun así responde 200 vacío, por eso la confirmación se lee del cuerpo
/// («Image uploaded») y no del código HTTP.
///
/// La otra mitad de la velocidad está en la captura: la cámara entrega la foto
/// ya reducida (ver `LogoNutriScreen`), lo que baja cada imagen de varios MB a
/// unos cientos de KB. Sobre datos móviles eso pesa más que cualquier detalle
/// del transporte.
class RegistroLogoService extends ChangeNotifier {
  /// Servidor de archivos del módulo: el mismo `logoNutri/upload.php` que ya
  /// estaba declarado en [Base].
  static final String _urlArchivos = Base().BASE_URL_ARCHIVOS_IMAGEN_NUTRI;

  /// Lo que responde `upload.php` cuando de verdad escribió el archivo.
  static const String _confirmacionSubida = 'Image uploaded';

  static const Duration _timeoutSubida = Duration(seconds: 60);

  @visibleForTesting
  static http.Client cliente = http.Client();

  int _idUsuario = 0;

  final List<RegistroLogo> _registros = [];

  /// La cola, del más viejo al más nuevo.
  List<RegistroLogo> get registros => List.unmodifiable(_registros);

  /// Los que todavía no llegaron al servidor: es lo que muestra la pestaña.
  List<RegistroLogo> get pendientes =>
      _registros.where((r) => r.estado != EstadoRegistro.enviado).toList();

  int get totalPendientes => pendientes.length;

  bool _enviando = false;
  bool get enviando => _enviando;

  /// Carga la cola del usuario conectado.
  Future<void> cargar(int idUsuario) async {
    _idUsuario = idUsuario;
    _registros
      ..clear()
      ..addAll(await RegistroLogoStore.leer(idUsuario));
    debugPrint('LOGO: ${_registros.length} registros en cola');
    notifyListeners();
  }

  /// Guarda una captura nueva y devuelve el registro encolado.
  ///
  /// [fotos] son los archivos que entregó la cámara; se copian a la carpeta de
  /// la app antes de encolar, porque el temporal de la cámara no sobrevive.
  /// Devuelve `null` si no se pudo guardar ninguna foto: un registro sin
  /// evidencia no sirve y es mejor que el usuario lo sepa al instante.
  Future<RegistroLogo?> guardarCaptura({
    required int idUsuario,
    required String usuarioCreacion,
    required List<File> fotos,
    required String tipoMaterial,
    required int cantidad,
    required String entorno,
    required String estadoMaterial,
    required String accion,
    String ciudad = '',
    String establecimiento = '',
    String descripcion = '',
    String referenciaUbicacion = '',
    double? latitud,
    double? longitud,
    double? precision,
    DateTime? fechaHora,
  }) async {
    _idUsuario = idUsuario;

    final nombres = <String>[];
    for (final foto in fotos) {
      final nombre = await RegistroLogoStore.guardarFoto(foto, idUsuario);
      if (nombre != null) nombres.add(nombre);
    }

    if (nombres.isEmpty) {
      debugPrint('LOGO: ninguna foto se pudo guardar, no se encola');
      return null;
    }

    final registro = RegistroLogo(
      id: DateTime.now().millisecondsSinceEpoch,
      idUsuario: idUsuario,
      usuarioCreacion: usuarioCreacion,
      fotos: nombres,
      tipoMaterial: tipoMaterial,
      cantidad: cantidad,
      entorno: entorno,
      estadoMaterial: estadoMaterial,
      accion: accion,
      ciudad: ciudad,
      establecimiento: establecimiento,
      descripcion: descripcion,
      referenciaUbicacion: referenciaUbicacion,
      latitud: latitud,
      longitud: longitud,
      precision: precision,
      fechaHora: fechaHora ?? DateTime.now(),
    );

    _registros
      ..clear()
      ..addAll(await RegistroLogoStore.encolar(idUsuario, registro));
    notifyListeners();

    return registro;
  }

  /// Intenta mandar un registro. No lanza: todo vuelve como [ResultadoEnvio].
  Future<ResultadoEnvio> enviar(RegistroLogo registro) async {
    // El WS exige coordenadas y rechaza el registro sin ellas. Se corta acá
    // para no gastar la subida de las fotos en algo que va a volver rechazado,
    // y para que el motivo que ve el usuario sea el real.
    if (!registro.tieneUbicacion) {
      return _anotarFallo(
        registro,
        'El registro no tiene ubicación y el servidor la exige.',
        reintentable: false,
      );
    }

    await _marcar(registro.copyWith(estado: EstadoRegistro.enviando));

    // 1) Las fotos que falten por subir, en paralelo.
    var subidas = registro.fotosSubidas;
    if (subidas.length < registro.fotos.length) {
      final resultado = await _subirFotos(registro.fotos);
      if (resultado == null) {
        return _anotarFallo(
          registro,
          'No se pudieron subir las fotos. Se reintenta con señal.',
        );
      }
      subidas = resultado;
      // Se persiste antes del POST: si el POST falla, el reintento no vuelve a
      // subir las mismas imágenes.
      registro = registro.copyWith(fotosSubidas: subidas);
      await _marcar(registro);
    }

    // 2) El registro.
    // Los errores de validación llegan con HTTP 200 y `correcto: false`, con
    // el motivo ya redactado («Debe enviar el tipo de material»): [LogoApi] los
    // marca como no reintentables, así que el registro queda en la cola con el
    // motivo a la vista en lugar de reintentarse para siempre.
    final respuesta = await LogoApi.post(
      LogoApi.recursoRegistro,
      registro.toEnvio(),
    );

    if (!respuesta.ok) {
      return _anotarFallo(
        registro,
        respuesta.mensaje,
        reintentable: respuesta.reintentable,
      );
    }

    // Aceptado: sale de la cola y sus fotos dejan de ocupar el teléfono.
    _registros
      ..clear()
      ..addAll(await RegistroLogoStore.quitar(_idUsuario, registro.id));
    notifyListeners();

    return ResultadoEnvio.exito(
      respuesta.mensaje.isEmpty ? 'Registro enviado.' : respuesta.mensaje,
    );
  }

  /// Drena la cola en orden. Se detiene ante el primer fallo de red: si no hay
  /// señal para uno, no la hay para los siguientes, y seguir solo sumaría
  /// intentos fallidos a todos los registros.
  Future<int> enviarPendientes() async {
    if (_enviando) return 0;
    _enviando = true;
    notifyListeners();

    var enviados = 0;
    try {
      for (final registro in [...pendientes]) {
        final resultado = await enviar(registro);
        if (resultado.ok) {
          enviados++;
        } else if (resultado.reintentable) {
          break;
        }
      }
    } finally {
      _enviando = false;
      notifyListeners();
    }
    return enviados;
  }

  /// Borra un registro de la cola junto con sus fotos.
  Future<void> eliminar(int idRegistro) async {
    _registros
      ..clear()
      ..addAll(await RegistroLogoStore.quitar(_idUsuario, idRegistro));
    notifyListeners();
  }

  /// Descarta la cola en memoria. Se llama al cerrar sesión: lo guardado en
  /// disco se conserva, segmentado por usuario, para cuando vuelva a entrar.
  void limpiar() {
    _idUsuario = 0;
    _registros.clear();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------

  Future<void> _marcar(RegistroLogo registro) async {
    _registros
      ..clear()
      ..addAll(await RegistroLogoStore.reemplazar(_idUsuario, registro));
    notifyListeners();
  }

  Future<ResultadoEnvio> _anotarFallo(
    RegistroLogo registro,
    String motivo, {
    bool reintentable = true,
  }) async {
    await _marcar(
      registro.copyWith(
        estado: EstadoRegistro.error,
        intentos: registro.intentos + 1,
        ultimoError: motivo,
      ),
    );
    return ResultadoEnvio.fallo(motivo, reintentable: reintentable);
  }

  /// Sube las fotos y devuelve los nombres con los que quedaron en el servidor,
  /// o `null` si alguna falló: un registro con evidencia incompleta no se manda.
  Future<List<String>?> _subirFotos(List<String> nombres) async {
    final resultados = await Future.wait(nombres.map(_subirFoto));
    if (resultados.any((r) => r == null)) return null;
    return resultados.cast<String>();
  }

  Future<String?> _subirFoto(String nombre) async {
    try {
      final archivo = await RegistroLogoStore.archivoFoto(nombre);
      if (!await archivo.exists()) {
        debugPrint('LOGO: la foto $nombre ya no está en el teléfono');
        return null;
      }

      final respuesta = await cliente
          .post(
            Uri.parse(_urlArchivos),
            body: {
              'base64': base64Encode(await archivo.readAsBytes()),
              'ImageName': nombre,
            },
          )
          .timeout(_timeoutSubida);

      if (!subidaConfirmada(respuesta.statusCode, respuesta.body)) {
        debugPrint(
          'LOGO: subida de $nombre a $_urlArchivos → '
          'HTTP ${respuesta.statusCode}, sin «$_confirmacionSubida»',
        );
        return null;
      }

      return nombre;
    } catch (e) {
      debugPrint('LOGO: subida de $nombre a $_urlArchivos → excepción: $e');
      return null;
    }
  }

  /// Si `upload.php` guardó la foto.
  ///
  /// El PHP responde 200 pase lo que pase; solo cuando escribe el archivo
  /// agrega «Image uploaded» al final (antes repite el base64 recibido). El
  /// archivo queda con el nombre que se mandó en `ImageName`.
  @visibleForTesting
  static bool subidaConfirmada(int status, String cuerpo) =>
      status == 200 && cuerpo.trimRight().endsWith(_confirmacionSubida);
}
