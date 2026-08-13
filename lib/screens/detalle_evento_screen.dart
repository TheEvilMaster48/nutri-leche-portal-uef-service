import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:nutri/base/base.dart';
import 'package:nutri/screens/pdf_fullscreen_screen.dart';
import 'package:nutri/screens/media_fullscreen_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/evento.dart';
import '../models/calendario_evento.dart';
import '../models/reaccion.dart';
import '../widget/barra_reacciones.dart';
import '../widget/texto_con_enlaces.dart';

class DetalleEventoScreen extends StatefulWidget {
  final dynamic evento;
  const DetalleEventoScreen({super.key, required this.evento});

  @override
  State<DetalleEventoScreen> createState() => _DetalleEventoScreenState();
}

class _DetalleEventoScreenState extends State<DetalleEventoScreen> {
  Player? _player;
  VideoController? _videoController;

  bool _loadingMedia = false;
  bool _mediaError = false;

  // Ahora es URL (no Base64)
  String? _mediaUrl;

  bool _isImage = false;
  bool _isPdf = false;
  bool _isVideo = false;

  /// `true` solo si el evento trae un archivo adjunto usable (URL http/https).
  /// Si el WS no manda nada — o manda algo que no es una URL — la sección de
  /// multimedia no se dibuja: nada de recuadro gris con ícono de "sin imagen".
  bool _tieneArchivo = false;

  File? _pdfFile;

  double get _mediaHeight => MediaQuery.of(context).size.height * 0.35;

  final MediaStore _mediaStore = MediaStore();

  // -------------------------
  // Helpers URL / Tipo archivo
  // -------------------------

  bool _isHttpUrl(String s) {
    final v = s.trim();
    final uri = Uri.tryParse(v);
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https');
  }

  /// Valores que el WS manda cuando el evento NO tiene adjunto. Llegan como
  /// texto, así que un simple `isNotEmpty` no alcanza.
  static const Set<String> _valoresSinArchivo = {
    'null',
    'nulo',
    'undefined',
    'n/a',
    'na',
    'none',
    'false',
    '0',
    '-',
    '--',
    'sin imagen',
    'sin archivo',
  };

  /// `true` solo si [v] es una URL http/https que apunta a un archivo concreto.
  ///
  /// Descarta: vacío, los textos de [_valoresSinArchivo], cualquier cosa que no
  /// sea URL, y URLs sin nombre de archivo (`https://host/`, `.../uploads/`,
  /// `.../null`) que es lo que devuelve el backend cuando concatena una ruta
  /// vacía a la base.
  bool _urlApuntaAArchivo(String v) {
    if (v.isEmpty) return false;
    if (_valoresSinArchivo.contains(v.toLowerCase())) return false;
    if (!_isHttpUrl(v)) return false;

    final uri = Uri.tryParse(v);
    if (uri == null) return false;

    final segmentos =
        uri.pathSegments.where((s) => s.trim().isNotEmpty).toList();
    if (segmentos.isEmpty) return false;

    final ultimo = segmentos.last.toLowerCase();
    if (_valoresSinArchivo.contains(ultimo)) return false;

    return true;
  }

  String _lowerExtFromUrl(String url) {
    final uri = Uri.parse(url);
    final path = uri.path.toLowerCase();
    final dot = path.lastIndexOf('.');
    if (dot == -1) return '';
    return path.substring(dot + 1); // png, jpg, pdf, mp4...
  }

  bool _looksLikeImageUrl(String url) {
    final ext = _lowerExtFromUrl(url);
    return ['png', 'jpg', 'jpeg', 'webp', 'gif'].contains(ext);
  }

  bool _looksLikePdfUrl(String url) {
    final ext = _lowerExtFromUrl(url);
    return ext == 'pdf';
  }

  bool _looksLikeVideoUrl(String url) {
    final ext = _lowerExtFromUrl(url);
    return ['mp4', 'mov', 'm4v', 'webm'].contains(ext);
  }

  // -------------------------
  // Download PDF (porque flutter_pdfview requiere filePath)
  // -------------------------

  Future<File> _downloadUrlToTempFile(String url, {String? forceExt}) async {
    final uri = Uri.parse(url);
    final resp = await http.get(uri);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('HTTP ${resp.statusCode}');
    }

    final dir = await getTemporaryDirectory();
    final ext = (forceExt ?? _lowerExtFromUrl(url)).trim();
    final safeExt = ext.isEmpty ? 'bin' : ext;

    final file = File(
      '${dir.path}/tmp_${DateTime.now().millisecondsSinceEpoch}.$safeExt',
    );
    await file.writeAsBytes(resp.bodyBytes, flush: true);
    return file;
  }

  Future<void> _initPdfFromUrl(String url) async {
    setState(() {
      _loadingMedia = true;
      _mediaError = false;
      _pdfFile = null;
    });

    try {
      final file = await _downloadUrlToTempFile(url, forceExt: 'pdf');
      setState(() {
        _pdfFile = file;
        _loadingMedia = false;
      });
    } catch (e) {
      debugPrint("PDF(URL) INIT ERROR: $e");
      setState(() {
        _loadingMedia = false;
        _mediaError = true;
      });
    }
  }

  Future<void> _initAndPlayVideoFromUrl(String url) async {
    setState(() {
      _loadingMedia = true;
      _mediaError = false;
    });

    try {
      // Libera cualquier reproductor previo ANTES de crear el nuevo,
      // para no mantener dos instancias de decodificador a la vez.
      await _disposePlayer();

      final player = Player();
      final controller = VideoController(player);

      player.stream.error.listen((e) {
        debugPrint('VIDEO(URL) ERROR: $e');
      });

      await player.open(Media(url));
      await player.setPlaylistMode(PlaylistMode.loop);
      await player.play();

      setState(() {
        _player = player;
        _videoController = controller;
        _loadingMedia = false;
      });
    } catch (e) {
      debugPrint('VIDEO(URL) INIT ERROR: $e');
      setState(() {
        _loadingMedia = false;
        _mediaError = true;
      });
    }
  }

  Future<void> _disposePlayer() async {
    final p = _player;
    _player = null;
    _videoController = null;
    await p?.dispose();
  }

  // Insignia de "pantalla completa" reutilizable para imagen/GIF y video.
  Widget _fullscreenBadge() {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.fullscreen,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  Future<void> _openMediaFullscreen({required bool isVideo}) async {
    if (_mediaUrl == null || _mediaUrl!.isEmpty) return;

    // Pausa el video en línea mientras se ve en pantalla completa,
    // para no tener dos reproductores activos al mismo tiempo.
    final estabaReproduciendo = isVideo && (_player?.state.playing ?? false);
    if (estabaReproduciendo) {
      await _player?.pause();
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaFullscreenScreen(
          url: _mediaUrl!,
          isVideo: isVideo,
          title: (widget.evento.titulo ?? '').toString(),
        ),
      ),
    );

    if (estabaReproduciendo) {
      await _player?.play();
    }
  }

  /// Devuelve `true` si se guardó en una carpeta (Android: Descargas),
  /// `false` si se abrió el share sheet (iOS) y no podemos confirmar el guardado.
  Future<bool> _savePdfToDownloads(File pdfFile) async {
    // iOS no tiene carpeta "Descargas" compartida: cada app vive en su sandbox.
    // La forma correcta de "guardar/descargar" es presentar el share sheet del
    // sistema, donde el usuario elige "Guardar en Archivos", AirDrop, Mail, etc.
    if (Platform.isIOS) {
      final fileName = pdfFile.uri.pathSegments.last;
      await Printing.sharePdf(
        bytes: await pdfFile.readAsBytes(),
        filename: fileName.toLowerCase().endsWith('.pdf')
            ? fileName
            : 'documento.pdf',
      );
      return false;
    }

    // Android: guardar en la carpeta compartida de Descargas vía MediaStore.
    // En Android <= 10 (API <= 29) la escritura requiere WRITE_EXTERNAL_STORAGE
    // concedido en runtime. En Android 11+ (scoped storage) no hace falta.
    final sdkInt = await _mediaStore.getPlatformSDKInt();
    if (sdkInt <= 29) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('Permiso de almacenamiento denegado');
      }
    }

    await _mediaStore.saveFile(
      tempFilePath: pdfFile.path,
      dirType: DirType.download,
      dirName: DirName.download,
    );
    return true;
  }

  // -------------------------
  // Lifecycle
  // -------------------------

  @override
  void initState() {
    super.initState();

    final evento = widget.evento;




    // Ajusta aquí según tu modelo real: tú dices que viene en "imagenBase64" pero ahora es URL.
    // En tu código anterior usabas evento.imagenPath.
    // Dejo fallback a ambas por seguridad.
    final String? url =
    (evento is Evento)
        ? (evento.imagenPath) // o cambia a evento.imagenBase64 si ese es el campo real
        : (evento is CalendarioEvento)
            ? evento.imagenBase64
            : (evento.imagenBase64 ?? evento.imagenPath);

    final String crudo = (url ?? '').trim();
    debugPrint('EVENTO ADJUNTO → valor recibido: "$crudo"');

    if (!_urlApuntaAArchivo(crudo)) {
      // El evento no trae adjunto: la sección multimedia no se dibuja.
      _mediaUrl = null;
      debugPrint('EVENTO ADJUNTO: sin archivo, no se muestra la sección');
      return;
    }

    _mediaUrl = crudo;

    _isImage = _looksLikeImageUrl(crudo);
    _isPdf = _looksLikePdfUrl(crudo);
    _isVideo = _looksLikeVideoUrl(crudo);

    if (_isImage || _isPdf || _isVideo) {
      _tieneArchivo = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isPdf) {
          _initPdfFromUrl(crudo);
        } else if (_isVideo) {
          _initAndPlayVideoFromUrl(crudo);
        }
      });
      return;
    }

    // La URL no tiene extensión reconocible (p. ej. links firmados o rutas sin
    // ".ext"). En vez de pintar un recuadro gris con ícono de archivo, se
    // pregunta al servidor qué es: si no es imagen/PDF/video —o no existe— la
    // sección queda oculta. Se mantiene `_tieneArchivo = false` mientras se
    // resuelve para no mostrar un placeholder que luego desaparece.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _resolverTipoPorContentType(crudo),
    );
  }

  /// Averigua el tipo real del adjunto leyendo el `Content-Type`.
  ///
  /// Se usa un GET con `Range: bytes=0-0` (en lugar de HEAD) porque varios
  /// servidores responden 405 al HEAD; el cliente se cierra en cuanto llegan las
  /// cabeceras, así que no se descarga el archivo completo.
  Future<void> _resolverTipoPorContentType(String url) async {
    String contentType = '';
    final client = http.Client();

    try {
      final request = http.Request('GET', Uri.parse(url))
        ..headers['Range'] = 'bytes=0-0';
      final respuesta = await client.send(request);

      if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) {
        contentType = (respuesta.headers['content-type'] ?? '').toLowerCase();
      } else {
        debugPrint('EVENTO ADJUNTO: HTTP ${respuesta.statusCode} → se oculta');
      }
    } catch (e) {
      debugPrint('EVENTO ADJUNTO: no se pudo verificar el archivo: $e');
    } finally {
      client.close();
    }

    if (!mounted) return;

    final esImagen = contentType.startsWith('image/');
    final esPdf = contentType.contains('pdf');
    final esVideo = contentType.startsWith('video/');

    if (!esImagen && !esPdf && !esVideo) {
      debugPrint('EVENTO ADJUNTO: content-type "$contentType" no mostrable');
      setState(() => _tieneArchivo = false);
      return;
    }

    setState(() {
      _isImage = esImagen;
      _isPdf = esPdf;
      _isVideo = esVideo;
      _tieneArchivo = true;
    });

    if (esPdf) {
      await _initPdfFromUrl(url);
    } else if (esVideo) {
      await _initAndPlayVideoFromUrl(url);
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  // -------------------------
  // UI
  // -------------------------


  @override
  Widget build(BuildContext context) {
    final evento = widget.evento;

    final String titulo = evento.titulo ?? '';
    final String descripcion = evento.descripcion ?? '';
    final String fecha =
    (evento is Evento) ? evento.fecha : (evento.fecha ?? '');
    final String hora =
    (evento is Evento)
        ? (evento.horaEvento.isNotEmpty ? evento.horaEvento : '')
        : (evento.hora ?? '');

    // Las reacciones se guardan contra el id del evento corporativo.
    //
    // Esta pantalla se reutiliza para el calendario (CalendarioEvento), y esos
    // registros salen del MISMO `ObtenerEventos`: su `id` es el `idEvento`. Por
    // eso ambos casos reaccionan sobre el mismo contenido y lo que se marque
    // desde el calendario se ve también en la lista de eventos.
    final int idParaReacciones = (evento is Evento)
        ? evento.idEvento
        : (evento is CalendarioEvento ? evento.id : 0);

    Widget buildMedia() {
      // Sin adjunto no se dibuja nada (la sección ya viene filtrada desde el
      // build, esto es solo una red de seguridad).
      if (!_tieneArchivo) return const SizedBox.shrink();

      // ✅ 1) Imagen por URL (incluye GIF)
      if (_isImage) {
        return GestureDetector(
          onTap: () => _openMediaFullscreen(isVideo: false),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CachedNetworkImage(
                imageUrl: _mediaUrl!,
                height: _mediaHeight,
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    _placeholder(Icons.image_not_supported),
                placeholder: (_, __) => _loadingBox(),
              ),
              _fullscreenBadge(),
            ],
          ),
        );
      }

      // ✅ 2) PDF (descargado a temp)
      if (_isPdf) {
        if (_loadingMedia) return _loadingBox();
        if (_mediaError || _pdfFile == null) {
          return _placeholder(Icons.picture_as_pdf);
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: _mediaHeight,
              child: PDFView(
                filePath: _pdfFile!.path,
                enableSwipe: true,
                swipeHorizontal: true,
                autoSpacing: false,
                pageFling: true,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.open_in_full, color: Colors.black),
                      label: const Text(
                        "Ver completo",
                        style: TextStyle(color: Colors.black),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => PdfFullscreenScreen(
                              pdfFile: _pdfFile!,
                              title: "Documento",
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.download, color: Colors.white),
                      label: const Text(
                        "Descargar",
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Base().COLOR_AZUL_CORP,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        try {
                          final savedToFolder =
                              await _savePdfToDownloads(_pdfFile!);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                savedToFolder
                                    ? "PDF guardado en Descargas ✅"
                                    : "Elige dónde guardar el PDF",
                              ),
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Error guardando en Descargas: $e"),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }

      // ✅ 3) Video (streaming desde URL)
      if (_isVideo) {
        if (_loadingMedia) return _loadingBox();

        if (_mediaError || _player == null || _videoController == null) {
          return _placeholder(Icons.videocam_off);
        }

        return SizedBox(
          height: _mediaHeight,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Video(
                controller: _videoController!,
                controls: NoVideoControls,
                fit: BoxFit.contain,
              ),
              StreamBuilder<bool>(
                stream: _player!.stream.playing,
                initialData: _player!.state.playing,
                builder: (context, snapshot) {
                  final isPlaying = snapshot.data ?? false;
                  return GestureDetector(
                    onTap: () {
                      if (isPlaying) {
                        _player!.pause();
                      } else {
                        _player!.play();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => _openMediaFullscreen(isVideo: true),
                  child: _fullscreenBadge(),
                ),
              ),
            ],
          ),
        );
      }

      // Tipo no mostrable: no se pinta nada (lo resuelve
      // `_resolverTipoPorContentType`, que oculta la sección).
      return const SizedBox.shrink();
    }

    // Inset físico de la barra de estado / notch (consistente iOS/Android).
    final double topInset = MediaQuery.of(context).viewPadding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          ClipPath(
            clipper: DetalleEventoWaveClipper(),
            child: Container(
              height: 120 + topInset,
              decoration: BoxDecoration(color: Base().COLOR_AZUL_CORP),
            ),
          ),
          Column(
            children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, topInset + 12, 16, 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'DETALLE DEL EVENTO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [

                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    titulo,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Base().COLOR_AZUL_CORP,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: Base().COLOR_AZUL_CORP,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _buildInfoRow(
                                    icon: Icons.description,
                                    label: 'Descripción',
                                    value: descripcion,
                                    detectarEnlaces: true,
                                  ),
                                  const SizedBox(height: 20),
                                  if (fecha.trim().isNotEmpty) ...[
                                    _buildInfoRow(
                                      icon: Icons.calendar_month_outlined,
                                      label: 'Fecha',
                                      value: fecha,
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  if (hora.trim().isNotEmpty) ...[
                                    _buildInfoRow(
                                      icon: Icons.access_time,
                                      label: 'Hora',
                                      value: hora,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // Solo se muestra el bloque multimedia si el evento
                            // realmente trae un archivo.
                            if (_tieneArchivo)
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20),
                                ),
                                child: buildMedia(),
                              ),
                            // id 0 = registro sin identificar: no hay contra qué
                            // guardar la reacción.
                            if (idParaReacciones > 0)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    24, 20, 24, 24),
                                child: BarraReacciones(
                                  origen: OrigenReaccion.evento,
                                  idContenido: idParaReacciones,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _loadingBox() {
    return Container(
      height: 220,
      color: Colors.black12,
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _placeholder(IconData icon) {
    return Container(
      height: 220,
      color: const Color(0xFFE0E0E0),
      child: Center(
        child: Icon(icon, size: 80, color: Base().COLOR_GRIS),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool detectarEnlaces = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Base().COLOR_AZUL_CORP.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Base().COLOR_AZUL_CORP, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Base().COLOR_AZUL_CORP,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Builder(builder: (_) {
                  final estilo = TextStyle(
                    fontSize: 15,
                    color: Base().COLOR_GRIS,
                    height: 1.4,
                  );
                  return detectarEnlaces
                      ? TextoConEnlaces(texto: value, estilo: estilo)
                      : Text(value, style: estilo);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DetalleEventoWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 30);

    var firstControlPoint = Offset(size.width * 0.25, size.height - 40);
    var firstEndPoint = Offset(size.width * 0.5, size.height - 30);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    var secondControlPoint = Offset(size.width * 0.75, size.height - 20);
    var secondEndPoint = Offset(size.width, size.height - 30);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondControlPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
