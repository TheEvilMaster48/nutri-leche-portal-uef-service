import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:url_launcher/url_launcher.dart';
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

  File? _pdfFile;

  double get _mediaHeight => MediaQuery.of(context).size.height * 0.35;

  final MediaStore _mediaStore = MediaStore();

  /// Un recognizer por URL detectada en el texto libre. Se reutilizan entre
  /// builds (no se recrean) y se liberan al destruir la pantalla.
  final Map<String, TapGestureRecognizer> _linkRecognizers = {};

  /// http/https hasta el primer espacio o carácter de cierre. Se excluyen los
  /// signos finales de puntuación al momento de limpiar la coincidencia.
  static final RegExp _urlRegex =
      RegExp(r'https?:\/\/[^\s<>"\)\]]+', caseSensitive: false);

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

    _mediaUrl = url?.trim();

    final hasMedia = _mediaUrl != null && _mediaUrl!.isNotEmpty;
    if (!hasMedia) return;

    if (!_isHttpUrl(_mediaUrl!)) {
      // si el WS manda algo raro, no intentamos
      _mediaError = true;
      return;
    }

    _isImage = _looksLikeImageUrl(_mediaUrl!);
    _isPdf = _looksLikePdfUrl(_mediaUrl!);
    _isVideo = _looksLikeVideoUrl(_mediaUrl!);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isPdf) {
        _initPdfFromUrl(_mediaUrl!);
      } else if (_isVideo) {
        _initAndPlayVideoFromUrl(_mediaUrl!);
      }
    });
  }

  @override
  void dispose() {
    _player?.dispose();
    _limpiarRecognizers();
    super.dispose();
  }

  void _limpiarRecognizers() {
    for (final r in _linkRecognizers.values) {
      r.dispose();
    }
    _linkRecognizers.clear();
  }

  Future<void> _abrirEnlace(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    bool ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el enlace: $url')),
      );
    }
  }

  /// Convierte el texto libre en un `Text.rich` donde las URLs quedan
  /// subrayadas y se pueden tocar. Sin esto la descripción se pinta como texto
  /// plano y los enlaces enviados en el evento no son accionables.
  Widget _textoConEnlaces(String value, TextStyle baseStyle) {
    final matches = _urlRegex.allMatches(value).toList();
    if (matches.isEmpty) return Text(value, style: baseStyle);

    final linkStyle = baseStyle.copyWith(
      color: Base().COLOR_AZUL_CORP,
      decoration: TextDecoration.underline,
      decorationColor: Base().COLOR_AZUL_CORP,
      fontWeight: FontWeight.w600,
    );

    final spans = <InlineSpan>[];
    int cursor = 0;

    for (final m in matches) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: value.substring(cursor, m.start)));
      }

      // La puntuación final suele pertenecer a la frase, no a la URL.
      var url = m.group(0)!;
      while (url.isNotEmpty && '.,;:!?'.contains(url[url.length - 1])) {
        url = url.substring(0, url.length - 1);
      }

      final recognizer = _linkRecognizers.putIfAbsent(
        url,
        () => TapGestureRecognizer()..onTap = () => _abrirEnlace(url),
      );

      spans.add(TextSpan(
        text: url,
        style: linkStyle,
        recognizer: recognizer,
      ));

      cursor = m.start + url.length;
    }

    if (cursor < value.length) {
      spans.add(TextSpan(text: value.substring(cursor)));
    }

    return Text.rich(TextSpan(style: baseStyle, children: spans));
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

    Widget buildMedia() {
      final hasMedia = _mediaUrl != null && _mediaUrl!.trim().isNotEmpty;

      if (!hasMedia) {
        return _placeholder(Icons.image_not_supported);
      }

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

      // Desconocido
      return _placeholder(Icons.insert_drive_file);
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
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                              ),
                              child: buildMedia(),
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
                      ? _textoConEnlaces(value, estilo)
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
