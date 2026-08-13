import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../base/base.dart';

/// Pinta texto libre convirtiendo las URLs que encuentre en enlaces tocables.
///
/// Sin esto la descripción que envía el WS se ve como texto plano y los links
/// que manda RRHH dentro del mensaje no son accionables. Se usa en el detalle
/// de eventos, de cumpleaños y de calendario para que el comportamiento sea el
/// mismo en las tres pantallas.
class TextoConEnlaces extends StatefulWidget {
  const TextoConEnlaces({
    super.key,
    required this.texto,
    required this.estilo,
    this.estiloEnlace,
  });

  final String texto;
  final TextStyle estilo;

  /// Estilo del tramo del enlace. Por defecto azul corporativo subrayado.
  final TextStyle? estiloEnlace;

  /// http/https hasta el primer espacio o carácter de cierre. La puntuación
  /// final se recorta aparte, al limpiar la coincidencia.
  static final RegExp _urlRegex =
      RegExp(r'https?:\/\/[^\s<>"\)\]]+', caseSensitive: false);

  /// `true` si el texto contiene al menos una URL abrible.
  static bool contieneEnlaces(String texto) => _urlRegex.hasMatch(texto);

  @override
  State<TextoConEnlaces> createState() => _TextoConEnlacesState();
}

class _TextoConEnlacesState extends State<TextoConEnlaces> {
  /// Un recognizer por URL detectada. Se reutilizan entre builds (no se
  /// recrean) y se liberan al destruir el widget.
  final Map<String, TapGestureRecognizer> _recognizers = {};

  @override
  void dispose() {
    for (final r in _recognizers.values) {
      r.dispose();
    }
    _recognizers.clear();
    super.dispose();
  }

  Future<void> _abrirEnlace(String url) async {
    final uri = Uri.tryParse(url);

    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enlace inválido: $url')),
      );
      return;
    }

    bool ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }

    // Algunos navegadores en Android devuelven false aunque abran; se reintenta
    // dejando que el sistema elija el manejador antes de dar el error.
    if (!ok) {
      try {
        ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {
        ok = false;
      }
    }

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el enlace: $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final valor = widget.texto;
    final matches = TextoConEnlaces._urlRegex.allMatches(valor).toList();
    if (matches.isEmpty) return Text(valor, style: widget.estilo);

    final estiloEnlace = widget.estiloEnlace ??
        widget.estilo.copyWith(
          color: Base().COLOR_AZUL_CORP,
          decoration: TextDecoration.underline,
          decorationColor: Base().COLOR_AZUL_CORP,
          fontWeight: FontWeight.w600,
        );

    final spans = <InlineSpan>[];
    int cursor = 0;

    for (final m in matches) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: valor.substring(cursor, m.start)));
      }

      // La puntuación final suele pertenecer a la frase, no a la URL.
      var url = m.group(0)!;
      while (url.isNotEmpty && '.,;:!?'.contains(url[url.length - 1])) {
        url = url.substring(0, url.length - 1);
      }

      if (url.isEmpty) {
        cursor = m.end;
        continue;
      }

      final recognizer = _recognizers.putIfAbsent(
        url,
        () => TapGestureRecognizer()..onTap = () => _abrirEnlace(url),
      );

      spans.add(TextSpan(
        text: url,
        style: estiloEnlace,
        recognizer: recognizer,
      ));

      cursor = m.start + url.length;
    }

    if (cursor < valor.length) {
      spans.add(TextSpan(text: valor.substring(cursor)));
    }

    return Text.rich(TextSpan(style: widget.estilo, children: spans));
  }
}
