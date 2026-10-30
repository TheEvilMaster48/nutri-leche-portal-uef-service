import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/chatbot.dart';
import '../services/auth_service.dart';
import '../services/chatbot_service.dart';
import '../widget/tarjeta_menu.dart';
import 'media_fullscreen_screen.dart';
import 'pdf_fullscreen_screen.dart';
import '../widget/tamano_imagen.dart';

/// Asistente de menú de opciones, configurado desde nutrisoft.
///
/// Es un chat sin texto libre: al abrir pide el menú inicial; cada opción que
/// se toca queda como burbuja del usuario y lo que responde el backend se
/// pinta en orden como burbujas del bot, con las opciones hijas como botones
/// debajo. «Volver» y «Menú inicial» están siempre que no se esté ya en el
/// menú inicial.
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final List<_Mensaje> _mensajes = [];
  final ScrollController _scroll = ScrollController();

  /// La última respuesta: de ella salen los botones de abajo.
  ChatbotRespuesta? _actual;
  bool _cargando = false;

  /// Lo último pedido, para «Reintentar» tras un fallo.
  int? _ultimoPedido;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pedir(null));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _pedir(int? idOpcion, {String? pregunta}) async {
    final usuario = context.read<AuthService>().currentUser;
    if (usuario == null || _cargando) return;

    setState(() {
      if (pregunta != null) _mensajes.add(_Mensaje.usuario(pregunta));
      _cargando = true;
      _ultimoPedido = idOpcion;
    });
    _bajar();

    try {
      final respuesta = await ChatbotService.responder(
        idUsuario: usuario.id,
        idOpcion: idOpcion,
      );
      if (!mounted) return;
      setState(() {
        _actual = respuesta;
        _mensajes.add(_Mensaje.bot(respuesta.bloques));
      });
    } on ChatbotException catch (e) {
      if (!mounted) return;
      setState(() => _mensajes.add(_Mensaje.fallo(e.mensaje)));
    } finally {
      if (mounted) setState(() => _cargando = false);
      _bajar();
    }
  }

  void _bajar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F9),
      appBar: AppBar(
        backgroundColor: PaletaMenu.cabecera,
        foregroundColor: Colors.white,
        title: const Text('Asistente Nutri'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              itemCount: _mensajes.length + (_cargando ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _mensajes.length) return const _Escribiendo();
                return _vistaMensaje(
                  _mensajes[i],
                  esUltimo: i == _mensajes.length - 1,
                );
              },
            ),
          ),
          _Opciones(
            respuesta: _actual,
            habilitado: !_cargando,
            alElegir: (o) => _pedir(o.id, pregunta: o.titulo),
            alVolver: (idPadre) => _pedir(idPadre, pregunta: 'Volver'),
            alInicio: () => _pedir(null, pregunta: 'Menú inicial'),
          ),
        ],
      ),
    );
  }

  Widget _vistaMensaje(_Mensaje m, {required bool esUltimo}) {
    switch (m.tipo) {
      case _TipoMensaje.usuario:
        return _Burbuja.usuario(
          child: Text(m.texto!, style: const TextStyle(color: Colors.white)),
        );
      case _TipoMensaje.fallo:
        return _Burbuja.bot(
          error: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m.texto!),
              if (esUltimo)
                TextButton.icon(
                  onPressed: _cargando ? null : () => _pedir(_ultimoPedido),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
            ],
          ),
        );
      case _TipoMensaje.bot:
        if (m.bloques.isEmpty) {
          return const _Burbuja.bot(child: Text('Elige una opción.'));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final b in m.bloques) _VistaBloque(bloque: b)],
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Mensajes
// ---------------------------------------------------------------------------

enum _TipoMensaje { usuario, bot, fallo }

class _Mensaje {
  _Mensaje.usuario(this.texto)
    : tipo = _TipoMensaje.usuario,
      bloques = const [];
  _Mensaje.bot(this.bloques) : tipo = _TipoMensaje.bot, texto = null;
  _Mensaje.fallo(this.texto) : tipo = _TipoMensaje.fallo, bloques = const [];

  final _TipoMensaje tipo;
  final String? texto;
  final List<ChatbotBloque> bloques;
}

class _Burbuja extends StatelessWidget {
  const _Burbuja.usuario({required this.child})
    : delUsuario = true,
      informativa = false,
      error = false;
  const _Burbuja.bot({
    required this.child,
    this.informativa = false,
    this.error = false,
  }) : delUsuario = false;

  final Widget child;
  final bool delUsuario;

  /// Sin datos o dato faltante del usuario: gris, no rojo.
  final bool informativa;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final Color fondo =
        delUsuario
            ? PaletaMenu.azulCorp
            : error
            ? const Color(0xFFFDECEA)
            : informativa
            ? const Color(0xFFE6E8EB)
            : Colors.white;

    return Align(
      alignment: delUsuario ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth:
              MediaQuery.of(context).size.width * (delUsuario ? 0.75 : 0.88),
        ),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(delUsuario ? 16 : 4),
            bottomRight: Radius.circular(delUsuario ? 4 : 16),
          ),
          boxShadow: [
            if (!delUsuario)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
          ],
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontSize: 14,
            color: error ? const Color(0xFFB3261E) : Colors.black87,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _Escribiendo extends StatelessWidget {
  const _Escribiendo();

  @override
  Widget build(BuildContext context) {
    return const _Burbuja.bot(
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bloques
// ---------------------------------------------------------------------------

class _VistaBloque extends StatelessWidget {
  const _VistaBloque({required this.bloque});

  final ChatbotBloque bloque;

  @override
  Widget build(BuildContext context) {
    final b = bloque;

    // Sin datos (incluye «tu usuario no tiene registrado el dato…»): solo el
    // mensaje, en gris.
    if (b.vacio) {
      return _Burbuja.bot(informativa: true, child: _textoConTitulo(b));
    }
    if (b.error) {
      return _Burbuja.bot(error: true, child: _textoConTitulo(b));
    }

    switch (b.formato) {
      case FormatoBloque.texto:
        return _Burbuja.bot(child: _textoConTitulo(b));
      case FormatoBloque.lista:
        return _Burbuja.bot(child: _conCabecera(b, _Lista(bloque: b)));
      case FormatoBloque.tabla:
        return _Burbuja.bot(child: _conCabecera(b, _Tabla(bloque: b)));
      case FormatoBloque.tarjeta:
        return _Burbuja.bot(
          child: _conCabecera(
            b,
            Column(
              children: [for (final t in b.tarjetas) _Tarjeta(tarjeta: t)],
            ),
          ),
        );
      case FormatoBloque.link:
      case FormatoBloque.archivo:
        return _Burbuja.bot(
          child: _conCabecera(
            b,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in b.enlaces)
                  _Enlace(
                    enlace: e,
                    esArchivo: b.formato == FormatoBloque.archivo,
                  ),
              ],
            ),
          ),
        );
    }
  }

  static Widget _titulo(String titulo) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
  );

  static Widget _textoConTitulo(ChatbotBloque b) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (b.titulo.isNotEmpty) _titulo(b.titulo),
      if (b.texto.isNotEmpty) Text(b.texto),
    ],
  );

  static Widget _conCabecera(ChatbotBloque b, Widget contenido) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (b.titulo.isNotEmpty) _titulo(b.titulo),
      if (b.texto.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(b.texto),
        ),
      contenido,
    ],
  );
}

/// Una tarjetita por fila, con «etiqueta: valor».
class _Lista extends StatelessWidget {
  const _Lista({required this.bloque});

  final ChatbotBloque bloque;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final fila in bloque.filas)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final c in bloque.columnas)
                  _ParEtiquetaValor(
                    etiqueta: c.etiqueta,
                    valor: fila[c.campo] ?? '',
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Tabla extends StatelessWidget {
  const _Tabla({required this.bloque});

  final ChatbotBloque bloque;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 48,
        horizontalMargin: 8,
        columnSpacing: 16,
        headingTextStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          color: PaletaMenu.azulCorp,
          fontSize: 13,
        ),
        dataTextStyle: const TextStyle(fontSize: 13, color: Colors.black87),
        columns: [
          for (final c in bloque.columnas)
            DataColumn(label: Text(c.etiqueta), numeric: _numerica(c.tipo)),
        ],
        rows: [
          for (final fila in bloque.filas)
            DataRow(
              cells: [
                for (final c in bloque.columnas)
                  DataCell(Text(fila[c.campo] ?? '')),
              ],
            ),
        ],
      ),
    );
  }

  static bool _numerica(String? tipo) {
    final t = (tipo ?? '').toUpperCase();
    return t == 'NUMERO' || t == 'MONEDA' || t == 'DECIMAL' || t == 'ENTERO';
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.tarjeta});

  final ChatbotTarjeta tarjeta;

  @override
  Widget build(BuildContext context) {
    final t = tarjeta;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (t.imagen.isNotEmpty)
            CachedNetworkImage(
              imageUrl: t.imagen,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
              memCacheWidth: anchoPantallaPx(context),
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (t.titulo.isNotEmpty)
                  Text(
                    t.titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                if (t.subtitulo.isNotEmpty)
                  Text(
                    t.subtitulo,
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                if (t.campos.isNotEmpty) const SizedBox(height: 6),
                for (final c in t.campos)
                  _ParEtiquetaValor(etiqueta: c.key, valor: c.value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ParEtiquetaValor extends StatelessWidget {
  const _ParEtiquetaValor({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$etiqueta: ',
              style: const TextStyle(color: Colors.black54),
            ),
            TextSpan(
              text: valor,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// LINK abre el navegador; ARCHIVO abre el PDF o la imagen dentro de la app y,
/// si es otro tipo, lo deja al sistema.
class _Enlace extends StatefulWidget {
  const _Enlace({required this.enlace, required this.esArchivo});

  final ChatbotEnlace enlace;
  final bool esArchivo;

  @override
  State<_Enlace> createState() => _EnlaceState();
}

class _EnlaceState extends State<_Enlace> {
  bool _abriendo = false;

  static const _imagenes = {'png', 'jpg', 'jpeg', 'gif', 'webp'};

  Future<void> _abrir() async {
    final url = widget.enlace.url;
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      _avisar('Enlace inválido: $url');
      return;
    }

    final ext = uri.path.split('.').last.toLowerCase();
    if (widget.esArchivo && ext == 'pdf') {
      await _abrirPdf(uri);
    } else if (widget.esArchivo && _imagenes.contains(ext)) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => MediaFullscreenScreen(
                url: url,
                isVideo: false,
                title: widget.enlace.texto,
              ),
        ),
      );
    } else {
      await _abrirFuera(uri);
    }
  }

  /// flutter_pdfview necesita un archivo local: se baja a temporales.
  Future<void> _abrirPdf(Uri uri) async {
    setState(() => _abriendo = true);
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 60));
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final dir = await getTemporaryDirectory();
      final archivo = File(
        '${dir.path}/chatbot_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await archivo.writeAsBytes(resp.bodyBytes, flush: true);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => PdfFullscreenScreen(
                pdfFile: archivo,
                title: widget.enlace.texto,
              ),
        ),
      );
    } catch (e) {
      debugPrint('CHATBOT → no se pudo bajar el PDF: $e');
      _avisar('No se pudo abrir el archivo.');
    } finally {
      if (mounted) setState(() => _abriendo = false);
    }
  }

  Future<void> _abrirFuera(Uri uri) async {
    bool ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    // Algunos navegadores en Android devuelven false aunque abran; se reintenta
    // dejando que el sistema elija el manejador.
    if (!ok) {
      try {
        ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {}
    }
    if (!ok) _avisar('No se pudo abrir el enlace.');
  }

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _abriendo ? null : _abrir,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            _abriendo
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : Icon(
                  widget.esArchivo
                      ? Icons.description_outlined
                      : Icons.open_in_new,
                  size: 20,
                  color: PaletaMenu.azulCorp,
                ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.enlace.texto,
                style: const TextStyle(
                  color: PaletaMenu.azulCorp,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Botones de opciones
// ---------------------------------------------------------------------------

class _Opciones extends StatelessWidget {
  const _Opciones({
    required this.respuesta,
    required this.habilitado,
    required this.alElegir,
    required this.alVolver,
    required this.alInicio,
  });

  final ChatbotRespuesta? respuesta;
  final bool habilitado;
  final ValueChanged<ChatbotOpcion> alElegir;

  /// `null` = el padre es el menú inicial.
  final ValueChanged<int?> alVolver;
  final VoidCallback alInicio;

  @override
  Widget build(BuildContext context) {
    final r = respuesta;
    if (r == null) return const SizedBox.shrink();
    final enSubmenu = r.opcion != null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          // Con muchas opciones, la conversación sigue a la vista.
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.35,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in r.opciones)
                  ActionChip(
                    avatar: Icon(
                      iconoChatbot(o.icono),
                      size: 18,
                      color: PaletaMenu.azulCorp,
                    ),
                    label: Text(o.titulo),
                    onPressed: habilitado ? () => alElegir(o) : null,
                    backgroundColor: const Color(0xFFE8F0FB),
                    side: BorderSide.none,
                  ),
                if (enSubmenu)
                  ActionChip(
                    avatar: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Volver'),
                    onPressed:
                        habilitado ? () => alVolver(r.opcion!.idPadre) : null,
                  ),
                if (enSubmenu)
                  ActionChip(
                    avatar: const Icon(Icons.home_outlined, size: 18),
                    label: const Text('Menú inicial'),
                    onPressed: habilitado ? alInicio : null,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Íconos de las opciones
// ---------------------------------------------------------------------------

/// Los nombres de ícono que se pueden escribir en el campo `icono` de una
/// opción desde la web de nutrisoft.
///
/// Se escriben en minúsculas y sin tildes; igual se toleran mayúsculas,
/// tildes, la ñ y espacios en vez de guion bajo. Un nombre que no esté acá
/// muestra una flecha.
const Map<String, IconData> iconosChatbot = {
  // Nómina y dinero
  'rol_pagos': Icons.receipt_long_outlined,
  'dinero': Icons.payments_outlined,
  'prestamo': Icons.account_balance_outlined,
  'anticipo': Icons.request_quote_outlined,
  'beneficios': Icons.card_giftcard_outlined,
  // Tiempo
  'vacaciones': Icons.beach_access_outlined,
  'calendario': Icons.calendar_month_outlined,
  'permiso': Icons.event_busy_outlined,
  'horario': Icons.schedule,
  'asistencia': Icons.fact_check_outlined,
  // Documentos
  'documento': Icons.description_outlined,
  'pdf': Icons.picture_as_pdf_outlined,
  'certificado': Icons.workspace_premium_outlined,
  'contrato': Icons.assignment_outlined,
  // Persona
  'perfil': Icons.person_outline,
  'familia': Icons.family_restroom_outlined,
  'salud': Icons.medical_services_outlined,
  'seguro': Icons.health_and_safety_outlined,
  'capacitacion': Icons.school_outlined,
  'evaluacion': Icons.assessment_outlined,
  // Empresa
  'noticias': Icons.campaign_outlined,
  'eventos': Icons.event_outlined,
  'cumpleanios': Icons.cake_outlined,
  'comedor': Icons.restaurant_outlined,
  'transporte': Icons.directions_bus_outlined,
  'uniforme': Icons.checkroom_outlined,
  'seguridad': Icons.shield_outlined,
  'ubicacion': Icons.location_on_outlined,
  'estadisticas': Icons.bar_chart,
  // Contacto y ayuda
  'contacto': Icons.contact_phone_outlined,
  'correo': Icons.mail_outline,
  'telefono': Icons.phone_outlined,
  'soporte': Icons.support_agent_outlined,
  'sugerencia': Icons.lightbulb_outline,
  'ayuda': Icons.help_outline,
  'info': Icons.info_outline,
  // Genéricos
  'lista': Icons.list_alt,
  'buscar': Icons.search,
  'link': Icons.link,
  'configuracion': Icons.settings_outlined,
};

/// Nombres en inglés que ya circularon (el ejemplo del contrato usa
/// `calendar`): siguen funcionando, pero en la web conviene usar los de
/// [iconosChatbot].
const Map<String, String> _aliasIconos = {
  'calendar': 'calendario',
  'money': 'dinero',
  'document': 'documento',
  'file': 'documento',
  'user': 'perfil',
  'person': 'perfil',
  'help': 'ayuda',
  'list': 'lista',
  'time': 'horario',
  'clock': 'horario',
  'hora': 'horario',
  'pago': 'dinero',
};

IconData iconoChatbot(String? nombre) {
  var clave = (nombre ?? '').trim().toLowerCase().replaceAll(' ', '_');
  const tildes = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u'};
  tildes.forEach((con, sin) => clave = clave.replaceAll(con, sin));
  clave = clave.replaceAll('ñ', 'ni');
  clave = _aliasIconos[clave] ?? clave;
  return iconosChatbot[clave] ?? Icons.chevron_right;
}
