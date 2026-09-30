import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/parametro.dart';
import '../models/registro_logo.dart';
import '../models/usuario.dart';
import '../services/auth_service.dart';
import '../services/parametro_service.dart';
import '../services/registro_logo_service.dart';
import '../services/registro_logo_store.dart';
import '../services/ubicacion_service.dart';

/// Módulo Logo Nutri: captura de material con evidencia fotográfica.
///
/// Dos pestañas, como pidió la operación:
///
/// - **Nuevo registro**: el formulario. Foto (1 a 3, solo cámara), tipo de
///   material, cantidad, entorno, acción requerida, ubicación del GPS, y el
///   usuario y la fecha puestos por la app.
/// - **Pendientes envío**: la cola de lo capturado que todavía no llegó al
///   servidor.
///
/// Todo funciona sin señal: guardar nunca toca la red, y los desplegables salen
/// de la caché del catálogo cuando el servidor no contesta.
class LogoNutriScreen extends StatefulWidget {
  const LogoNutriScreen({super.key});

  @override
  State<LogoNutriScreen> createState() => _LogoNutriScreenState();
}

class _LogoNutriScreenState extends State<LogoNutriScreen>
    with SingleTickerProviderStateMixin {
  static const Color _azul = Color(0xFF0052A3);

  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Lo guardado en el teléfono se muestra de inmediato; si hay conexión
      // se refresca, si no se trabaja con eso.
      context.read<ParametroService>().iniciar();

      final usuario = context.read<AuthService>().currentUser;
      if (usuario != null) {
        context.read<RegistroLogoService>().cargar(usuario.id);
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = context.watch<RegistroLogoService>().totalPendientes;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          'Rebranding',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _azul,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: [
            const Tab(
              icon: Icon(Icons.add_a_photo_outlined),
              text: 'Nuevo registro',
            ),
            Tab(
              icon: const Icon(Icons.cloud_upload_outlined),
              text:
                  pendientes > 0
                      ? 'Pendientes envío ($pendientes)'
                      : 'Pendientes envío',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _FormularioTab(alGuardar: () => _tabs.animateTo(1)),
          const _PendientesTab(),
        ],
      ),
    );
  }
}

// =============================================================================
// Pestaña 1 — Nuevo registro
// =============================================================================

class _FormularioTab extends StatefulWidget {
  const _FormularioTab({required this.alGuardar});

  /// Se llama después de encolar, para llevar al usuario a ver su registro.
  final VoidCallback alGuardar;

  @override
  State<_FormularioTab> createState() => _FormularioTabState();
}

class _FormularioTabState extends State<_FormularioTab> {
  static const Color _azul = Color(0xFF0052A3);
  static const Color _verde = Color(0xFF4A6D08);
  static const Color _rojo = Color(0xFFA8460F);

  /// Mínimo y máximo de fotos por registro.
  static const int _minFotos = 1;
  static const int _maxFotos = 3;

  final _formKey = GlobalKey<FormState>();
  final _cantidadCtrl = TextEditingController();
  final _ciudadCtrl = TextEditingController();
  final _establecimientoCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _referenciaCtrl = TextEditingController();

  final List<File> _fotos = [];

  /// Lo elegido en cada desplegable. El valor es el texto del catálogo
  /// —`ROTULO`, `INTERIOR`…—, que es lo que el WS entrega y espera: sus listas
  /// no traen ids.
  final Map<FamiliaParametro, String> _seleccion = {};

  ResultadoUbicacion? _ubicacion;
  bool _buscandoUbicacion = false;

  /// La ciudad se resuelve por red después de fijar la posición: mientras
  /// tanto el campo muestra que está trabajando, pero se puede escribir.
  bool _buscandoCiudad = false;

  bool _guardando = false;

  /// Solo para que el reloj de la tarjeta avance a la vista. La hora que queda
  /// en el registro es la del momento de guardar, no esta.
  Timer? _reloj;
  DateTime _ahora = DateTime.now();

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _ahora = DateTime.now());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _ubicar());
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _cantidadCtrl.dispose();
    _ciudadCtrl.dispose();
    _establecimientoCtrl.dispose();
    _descripcionCtrl.dispose();
    _referenciaCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------

  Future<void> _ubicar() async {
    if (_buscandoUbicacion) return;
    setState(() => _buscandoUbicacion = true);
    final resultado = await UbicacionService.obtener();
    if (!mounted) return;
    setState(() {
      _ubicacion = resultado;
      _buscandoUbicacion = false;
    });

    final posicion = resultado.posicion;
    if (posicion != null) _resolverCiudad(posicion);
  }

  /// Rellena «Ciudad» a partir de las coordenadas, si se puede.
  ///
  /// Va suelto y no encadenado a [_ubicar] a propósito: la ubicación queda
  /// fijada enseguida y la ciudad aparece después, si hay datos. Tampoco pisa
  /// lo que el usuario ya escribió —solo completa el campo vacío—, porque el
  /// geocoder devuelve el cantón y a veces la operación usa otro nombre.
  Future<void> _resolverCiudad(Position posicion) async {
    setState(() => _buscandoCiudad = true);

    final ciudad = await UbicacionService.ciudadDe(
      posicion.latitude,
      posicion.longitude,
    );

    if (!mounted) return;
    setState(() {
      _buscandoCiudad = false;
      if (ciudad != null && _ciudadCtrl.text.trim().isEmpty) {
        _ciudadCtrl.text = ciudad;
      }
    });
  }

  /// Toma una foto con la cámara.
  ///
  /// **No se abre la galería a propósito**: la evidencia tiene que ser del
  /// momento y del lugar, y una imagen elegida del carrete puede ser de
  /// cualquier día. Por eso [ImageSource.camera] es la única fuente.
  ///
  /// Se pide reducida (`imageQuality` y el lado máximo) porque es lo que más
  /// pesa en el envío: baja cada foto de varios MB a unos cientos de KB sin
  /// que se pierda el detalle que hay que ver.
  Future<void> _tomarFoto() async {
    if (_fotos.length >= _maxFotos) {
      _avisar('Máximo $_maxFotos fotos por registro.', _rojo);
      return;
    }

    try {
      final foto = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (foto == null || !mounted) return;
      setState(() => _fotos.add(File(foto.path)));
    } on PlatformException catch (e) {
      debugPrint('LOGO: no se pudo tomar la foto → $e');
      if (mounted) {
        _avisar('No se pudo abrir la cámara. Revisa los permisos.', _rojo);
      }
    }
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_fotos.length < _minFotos) {
      _avisar('Toma al menos $_minFotos foto.', _rojo);
      return;
    }

    final usuario = context.read<AuthService>().currentUser;
    if (usuario == null) {
      _avisar('La sesión se cerró. Vuelve a entrar.', _rojo);
      return;
    }

    // Se lee antes del diálogo: después del await el context ya no se toca.
    final servicio = context.read<RegistroLogoService>();

    // La ubicación es obligatoria: el WS rechaza el registro sin coordenadas
    // («Debe enviar la ubicacion»). Guardar igual dejaría en la cola algo que
    // nunca va a poder enviarse, y las coordenadas no se pueden recuperar
    // después: son las del momento de la captura.
    final posicion = _ubicacion?.posicion;
    if (posicion == null) {
      await _avisarSinUbicacion();
      return;
    }

    setState(() => _guardando = true);

    final registro = await servicio.guardarCaptura(
      idUsuario: usuario.id,
      usuarioCreacion: _loginUsuario(usuario),
      fotos: _fotos,
      tipoMaterial: _seleccion[FamiliaParametro.material] ?? '',
      cantidad: int.parse(_cantidadCtrl.text.trim()),
      entorno: _seleccion[FamiliaParametro.entorno] ?? '',
      estadoMaterial: _seleccion[FamiliaParametro.estado] ?? '',
      accion: _seleccion[FamiliaParametro.accion] ?? '',
      ciudad: _ciudadCtrl.text.trim(),
      establecimiento: _establecimientoCtrl.text.trim(),
      descripcion: _descripcionCtrl.text.trim(),
      referenciaUbicacion: _referenciaCtrl.text.trim(),
      latitud: posicion.latitude,
      longitud: posicion.longitude,
      precision: posicion.accuracy,
    );

    if (!mounted) return;
    setState(() => _guardando = false);

    if (registro == null) {
      _avisar('No se pudo guardar la evidencia. Intenta de nuevo.', _rojo);
      return;
    }

    _limpiar();
    widget.alGuardar();

    // Se intenta mandar enseguida; si no hay señal, se queda en la cola.
    final resultado = await servicio.enviar(registro);
    if (!mounted) return;
    _avisar(
      resultado.ok ? resultado.mensaje : 'Guardado. ${resultado.mensaje}',
      resultado.ok ? _verde : _azul,
    );
  }

  /// El registro no se puede guardar sin coordenadas. Se explica por qué y se
  /// ofrece lo único que lo resuelve: volver a intentar la lectura, o ir a los
  /// ajustes cuando el permiso o el GPS están cerrados desde el sistema.
  Future<void> _avisarSinUbicacion() async {
    final fallo = _ubicacion?.fallo;

    final accion = await showDialog<String>(
      context: context,
      builder:
          (dialogo) => AlertDialog(
            title: const Text('Falta la ubicación'),
            content: Text(
              '${_ubicacion?.mensaje ?? 'Todavía no se pudo obtener la ubicación '
                      'del teléfono.'}\n\n'
              'El registro necesita las coordenadas del sitio, así que no se puede '
              'guardar hasta tenerlas.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogo).pop('cerrar'),
                child: const Text('Cerrar'),
              ),
              if (fallo == FalloUbicacion.servicioApagado ||
                  fallo == FalloUbicacion.permisoNegadoParaSiempre)
                TextButton(
                  onPressed: () => Navigator.of(dialogo).pop('ajustes'),
                  child: const Text('Abrir ajustes'),
                ),
              TextButton(
                onPressed: () => Navigator.of(dialogo).pop('reintentar'),
                child: const Text('Reintentar'),
              ),
            ],
          ),
    );

    if (accion == 'reintentar') {
      await _ubicar();
    } else if (accion == 'ajustes' && fallo != null) {
      await UbicacionService.abrirAjustes(fallo);
    }
  }

  /// El login con el que el WS identifica al usuario (`usuarioCreacion`).
  /// Se cae al nombre si la sesión no lo trae.
  String _loginUsuario(Usuario usuario) {
    final login = usuario.usuario.trim();
    return login.isEmpty ? usuario.nombre : login;
  }

  void _elegir(FamiliaParametro familia, String? valor) {
    setState(() {
      if (valor == null) {
        _seleccion.remove(familia);
      } else {
        _seleccion[familia] = valor;
      }
    });
  }

  void _limpiar() {
    setState(() {
      _fotos.clear();
      _cantidadCtrl.clear();
      _ciudadCtrl.clear();
      _establecimientoCtrl.clear();
      _descripcionCtrl.clear();
      _referenciaCtrl.clear();
      _seleccion.clear();
    });
    _formKey.currentState?.reset();
  }

  void _avisar(String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final parametros = context.watch<ParametroService>();
    final usuario = context.watch<AuthService>().currentUser;

    return Form(
      key: _formKey,
      child: ListView(
        // Se suma la barra de navegación del sistema: en Android con botones
        // (y en los que dibujan de borde a borde) el botón Guardar quedaba
        // debajo de ella al llegar al final.
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          32 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          _Seccion(
            titulo: 'Evidencia fotográfica',
            subtitulo:
                'Entre $_minFotos y $_maxFotos fotos, tomadas con la cámara',
            hijo: _Fotos(
              fotos: _fotos,
              maximo: _maxFotos,
              alTomar: _tomarFoto,
              alQuitar: (indice) => setState(() => _fotos.removeAt(indice)),
            ),
          ),
          const SizedBox(height: 16),
          _Seccion(
            titulo: 'Detalle',
            hijo: Column(
              children: [
                _Desplegable(
                  familia: FamiliaParametro.material,
                  servicio: parametros,
                  valor: _seleccion[FamiliaParametro.material],
                  alCambiar:
                      (valor) => _elegir(FamiliaParametro.material, valor),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _cantidadCtrl,
                  keyboardType: TextInputType.number,
                  // Solo dígitos: ni signos, ni comas, ni espacios.
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Cantidad',
                    prefixIcon: Icon(Icons.numbers),
                    border: OutlineInputBorder(),
                  ),
                  validator: (valor) {
                    final texto = valor?.trim() ?? '';
                    if (texto.isEmpty) return 'Ingresa la cantidad';
                    final numero = int.tryParse(texto);
                    if (numero == null) return 'Solo números';
                    if (numero <= 0) return 'Debe ser mayor que cero';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _Desplegable(
                  familia: FamiliaParametro.entorno,
                  servicio: parametros,
                  valor: _seleccion[FamiliaParametro.entorno],
                  alCambiar:
                      (valor) => _elegir(FamiliaParametro.entorno, valor),
                ),
                const SizedBox(height: 14),
                _Desplegable(
                  familia: FamiliaParametro.estado,
                  servicio: parametros,
                  valor: _seleccion[FamiliaParametro.estado],
                  alCambiar: (valor) => _elegir(FamiliaParametro.estado, valor),
                ),
                const SizedBox(height: 14),
                _Desplegable(
                  familia: FamiliaParametro.accion,
                  servicio: parametros,
                  valor: _seleccion[FamiliaParametro.accion],
                  alCambiar: (valor) => _elegir(FamiliaParametro.accion, valor),
                ),
              ],
            ),
          ),
          if (parametros.sinConexion) ...[
            const SizedBox(height: 10),
            _Aviso(
              icono: Icons.cloud_off,
              texto:
                  parametros.vacio
                      ? 'Sin conexión y sin listas guardadas en el teléfono. '
                          'Conéctate una vez para descargarlas.'
                      : 'Sin conexión: listas guardadas en el teléfono'
                          '${_fechaCatalogo(parametros.sincronizado)}.',
              accion: parametros.cargando ? null : parametros.iniciar,
            ),
          ] else if (parametros.error != null) ...[
            const SizedBox(height: 10),
            _Aviso(
              icono: Icons.wifi_off,
              texto:
                  parametros.vacio
                      ? 'No hay listas disponibles: ${parametros.error}'
                      : 'Listas mostradas desde la última descarga '
                          '(${parametros.error}).',
              accion: parametros.cargando ? null : parametros.sincronizar,
            ),
          ],
          const SizedBox(height: 16),
          _Seccion(
            titulo: 'Sitio y observación',
            subtitulo: 'Solo la descripción es opcional',
            hijo: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Texto(
                        controlador: _ciudadCtrl,
                        etiqueta: 'Ciudad',
                        icono: Icons.location_city_outlined,
                        // El ERP guarda estos valores en mayúsculas; el teclado
                        // arranca así para que no queden mezclados.
                        capitalizacion: TextCapitalization.characters,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Texto(
                        controlador: _establecimientoCtrl,
                        etiqueta: 'Establecimiento',
                        icono: Icons.storefront_outlined,
                        capitalizacion: TextCapitalization.characters,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _Texto(
                  controlador: _referenciaCtrl,
                  etiqueta: 'Referencia de ubicación',
                  icono: Icons.signpost_outlined,
                  lineas: 2,
                ),
                const SizedBox(height: 14),
                _Texto(
                  controlador: _descripcionCtrl,
                  etiqueta: 'Descripción',
                  icono: Icons.notes_outlined,
                  lineas: 3,
                  ayuda: 'Opcional · qué se observó en el material',
                  obligatorio: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Seccion(
            titulo: 'Datos automáticos',
            subtitulo: 'Los toma la app, no se editan',
            hijo: Column(
              children: [
                _Ubicacion(
                  resultado: _ubicacion,
                  buscando: _buscandoUbicacion,
                  alReintentar: _ubicar,
                ),
                const Divider(height: 24),
                _DatoFijo(
                  icono: Icons.person_outline,
                  titulo: 'Usuario conectado',
                  valor: _descripcionUsuario(usuario),
                ),
                const SizedBox(height: 12),
                _DatoFijo(
                  icono: Icons.schedule,
                  titulo: 'Fecha y hora',
                  valor: DateFormat("dd/MM/yyyy HH:mm:ss").format(_ahora),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _guardando ? null : _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: _azul,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon:
                  _guardando
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.save_outlined),
              label: Text(
                _guardando ? 'Guardando…' : 'Guardar registro',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _descripcionUsuario(Usuario? usuario) {
    if (usuario == null) return 'Sin sesión';
    final cargo = usuario.cargo.trim();
    return cargo.isEmpty ? usuario.nombre : '${usuario.nombre}';
  }
}

// =============================================================================
// Pestaña 2 — Pendientes de envío
// =============================================================================

class _PendientesTab extends StatelessWidget {
  const _PendientesTab();

  static const Color _azul = Color(0xFF0052A3);

  @override
  Widget build(BuildContext context) {
    final servicio = context.watch<RegistroLogoService>();
    final pendientes = servicio.pendientes.reversed.toList();

    if (pendientes.isEmpty) {
      return const _Vacio();
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            itemCount: pendientes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder:
                (context, indice) => _TarjetaRegistro(
                  registro: pendientes[indice],
                  servicio: servicio,
                ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              height: 48,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    servicio.enviando
                        ? null
                        : () => _enviarTodos(context, servicio),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _azul,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon:
                    servicio.enviando
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  servicio.enviando
                      ? 'Enviando…'
                      : 'Enviar los ${pendientes.length} pendientes',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _enviarTodos(
    BuildContext context,
    RegistroLogoService servicio,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final total = servicio.totalPendientes;
    final enviados = await servicio.enviarPendientes();

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          enviados == 0
              ? 'No se pudo enviar. Quedan $total en el teléfono.'
              : 'Enviados $enviados de $total.',
        ),
        backgroundColor:
            enviados == 0 ? const Color(0xFFA8460F) : const Color(0xFF4A6D08),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _TarjetaRegistro extends StatelessWidget {
  const _TarjetaRegistro({required this.registro, required this.servicio});

  static const Color _azul = Color(0xFF0052A3);

  final RegistroLogo registro;
  final RegistroLogoService servicio;

  /// Establecimiento y ciudad en una línea, saltando el que esté vacío.
  String get _sitio => [
    registro.establecimiento,
    registro.ciudad,
  ].where((t) => t.trim().isNotEmpty).join(' · ');

  @override
  Widget build(BuildContext context) {
    final fecha = DateFormat('dd/MM/yyyy HH:mm').format(registro.fechaHora);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Miniatura(nombre: registro.fotos.first),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      registro.tipoMaterial.isEmpty
                          ? 'Material sin tipo'
                          : registro.tipoMaterial,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cantidad: ${registro.cantidad} · '
                      '${registro.totalFotos} foto(s)',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${registro.entorno} · ${registro.estadoMaterial} · '
                      '${registro.accion}',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                    if (_sitio.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _sitio,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      fecha,
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _ChipEstado(estado: registro.estado),
            ],
          ),
          if (registro.referenciaUbicacion.isNotEmpty)
            _LineaNota(
              icono: Icons.signpost_outlined,
              texto: registro.referenciaUbicacion,
            ),
          if (registro.descripcion.isNotEmpty)
            _LineaNota(
              icono: Icons.notes_outlined,
              texto: registro.descripcion,
            ),
          if (!registro.tieneUbicacion || registro.ultimoError != null) ...[
            const SizedBox(height: 10),
            if (!registro.tieneUbicacion)
              const _LineaNota(
                icono: Icons.location_off_outlined,
                texto: 'Guardado sin ubicación',
              ),
            if (registro.ultimoError != null)
              _LineaNota(
                icono: Icons.error_outline,
                texto:
                    registro.intentos > 0
                        ? '${registro.ultimoError} (${registro.intentos} intento(s))'
                        : registro.ultimoError!,
                color: const Color(0xFFA8460F),
              ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _confirmarEliminar(context),
                icon: const Icon(Icons.delete_outline, size: 18),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                label: const Text('Eliminar'),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed:
                    registro.estado == EstadoRegistro.enviando
                        ? null
                        : () => _enviar(context),
                style: FilledButton.styleFrom(backgroundColor: _azul),
                icon: const Icon(Icons.send_outlined, size: 18),
                label: const Text('Enviar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _enviar(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final resultado = await servicio.enviar(registro);
    messenger.showSnackBar(
      SnackBar(
        content: Text(resultado.mensaje),
        backgroundColor:
            resultado.ok ? const Color(0xFF4A6D08) : const Color(0xFFA8460F),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmarEliminar(BuildContext context) async {
    final borrar = await showDialog<bool>(
      context: context,
      builder:
          (dialogo) => AlertDialog(
            title: const Text('Eliminar registro'),
            content: const Text(
              'Se borrará del teléfono junto con sus fotos. Esto no se puede '
              'deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogo).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogo).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );

    if (borrar == true) await servicio.eliminar(registro.id);
  }
}

// =============================================================================
// Piezas de presentación
// =============================================================================

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.hijo, this.subtitulo});

  final String titulo;
  final String? subtitulo;
  final Widget hijo;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF0052A3),
            ),
          ),
          if (subtitulo != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitulo!,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
          const SizedBox(height: 14),
          hijo,
        ],
      ),
    );
  }
}

class _Fotos extends StatelessWidget {
  const _Fotos({
    required this.fotos,
    required this.maximo,
    required this.alTomar,
    required this.alQuitar,
  });

  final List<File> fotos;
  final int maximo;
  final VoidCallback alTomar;
  final void Function(int indice) alQuitar;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < fotos.length; i++)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  fotos[i],
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: GestureDetector(
                  onTap: () => alQuitar(i),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        if (fotos.length < maximo)
          InkWell(
            onTap: alTomar,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF0052A3), width: 1.4),
                color: const Color(0xFFEFF4FB),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_camera_outlined, color: Color(0xFF0052A3)),
                  SizedBox(height: 4),
                  Text(
                    'Tomar foto',
                    style: TextStyle(fontSize: 11, color: Color(0xFF0052A3)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Un desplegable alimentado por el catálogo de `/parametros`.
/// Un desplegable alimentado por una lista de `/parametros`.
class _Desplegable extends StatelessWidget {
  const _Desplegable({
    required this.familia,
    required this.servicio,
    required this.valor,
    required this.alCambiar,
  });

  final FamiliaParametro familia;
  final ParametroService servicio;
  final String? valor;
  final ValueChanged<String?> alCambiar;

  @override
  Widget build(BuildContext context) {
    final opciones = servicio.opciones(familia);

    // Si el catálogo se resincroniza y la opción elegida ya no está, el valor
    // se suelta: un `value` fuera de `items` es un error en tiempo de ejecución
    // del Dropdown, no un detalle visual.
    final seleccionado = opciones.contains(valor) ? valor : null;

    return DropdownButtonFormField<String>(
      initialValue: seleccionado,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: familia.etiqueta,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(switch (familia) {
          FamiliaParametro.material => Icons.category_outlined,
          FamiliaParametro.entorno => Icons.landscape_outlined,
          FamiliaParametro.estado => Icons.verified_outlined,
          FamiliaParametro.accion => Icons.build_outlined,
        }),
        helperText:
            opciones.isEmpty && !servicio.cargando
                ? 'Sin opciones activas en el catálogo'
                : null,
      ),
      items: [
        for (final opcion in opciones)
          DropdownMenuItem(value: opcion, child: Text(opcion)),
      ],
      onChanged: opciones.isEmpty ? null : alCambiar,
      // Los cuatro son obligatorios. Si una lista llegó vacía no hay qué
      // elegir: se pide descargar el catálogo en vez de dejar pasar el campo.
      validator: (v) {
        if (opciones.isEmpty) {
          return 'No hay opciones de ${familia.etiqueta.toLowerCase()}: '
              'descarga las listas con conexión';
        }
        return v == null
            ? 'Selecciona ${familia.etiqueta.toLowerCase()}'
            : null;
      },
    );
  }
}

/// Campo de texto libre del formulario. Obligatorio salvo que se indique lo
/// contrario: hoy solo la descripción es opcional.
class _Texto extends StatelessWidget {
  const _Texto({
    required this.controlador,
    required this.etiqueta,
    required this.icono,
    this.lineas = 1,
    this.ayuda,
    this.capitalizacion = TextCapitalization.sentences,
    this.obligatorio = true,
  });

  final TextEditingController controlador;
  final String etiqueta;
  final IconData icono;
  final int lineas;
  final String? ayuda;
  final TextCapitalization capitalizacion;
  final bool obligatorio;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controlador,
      validator:
          obligatorio
              ? (valor) =>
                  (valor ?? '').trim().isEmpty
                      ? 'Ingresa ${etiqueta.toLowerCase()}'
                      : null
              : null,
      maxLines: lineas,
      textCapitalization: capitalizacion,
      keyboardType: lineas > 1 ? TextInputType.multiline : TextInputType.text,
      decoration: InputDecoration(
        labelText: etiqueta,
        helperText: obligatorio ? ayuda : (ayuda ?? 'Opcional'),
        helperMaxLines: 2,
        prefixIcon: Icon(icono),
        border: const OutlineInputBorder(),
        alignLabelWithHint: lineas > 1,
      ),
    );
  }
}

class _Ubicacion extends StatelessWidget {
  const _Ubicacion({
    required this.resultado,
    required this.buscando,
    required this.alReintentar,
  });

  final ResultadoUbicacion? resultado;
  final bool buscando;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    final posicion = resultado?.posicion;

    final String valor;
    if (buscando) {
      valor = 'Buscando señal del GPS…';
    } else if (posicion != null) {
      valor =
          '${posicion.latitude.toStringAsFixed(6)}, '
          '${posicion.longitude.toStringAsFixed(6)}'
          '  (±${posicion.accuracy.toStringAsFixed(0)} m)';
    } else {
      valor = resultado?.mensaje ?? 'Sin ubicación todavía';
    }

    return Row(
      children: [
        Expanded(
          child: _DatoFijo(
            icono:
                posicion != null
                    ? Icons.location_on_outlined
                    : Icons.location_off_outlined,
            titulo: 'Ubicación actual (obligatoria)',
            valor: valor,
            alerta: posicion == null && !buscando,
            nota:
                resultado?.precisionDudosa == true
                    ? 'Precisión baja: la lectura puede estar corrida.'
                    : null,
          ),
        ),
        IconButton(
          onPressed: buscando ? null : alReintentar,
          icon:
              buscando
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.my_location),
          tooltip: 'Actualizar ubicación',
          color: const Color(0xFF0052A3),
        ),
      ],
    );
  }
}

class _DatoFijo extends StatelessWidget {
  const _DatoFijo({
    required this.icono,
    required this.titulo,
    required this.valor,
    this.alerta = false,
    this.nota,
  });

  final IconData icono;
  final String titulo;
  final String valor;
  final bool alerta;
  final String? nota;

  @override
  Widget build(BuildContext context) {
    final color = alerta ? const Color(0xFFA8460F) : Colors.black87;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (nota != null) ...[
                const SizedBox(height: 2),
                Text(
                  nota!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8A6300),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// « del 23/09 10:15» para el aviso sin conexión, o nada si no hay fecha.
String _fechaCatalogo(DateTime? fecha) {
  if (fecha == null) return '';
  String dos(int n) => n.toString().padLeft(2, '0');
  return ' del ${dos(fecha.day)}/${dos(fecha.month)} '
      '${dos(fecha.hour)}:${dos(fecha.minute)}';
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icono, required this.texto, this.accion});

  final IconData icono;
  final String texto;
  final VoidCallback? accion;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8C877)),
      ),
      child: Row(
        children: [
          Icon(icono, size: 18, color: const Color(0xFF8A6300)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B4E00)),
            ),
          ),
          if (accion != null)
            TextButton(onPressed: accion, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

class _LineaNota extends StatelessWidget {
  const _LineaNota({
    required this.icono,
    required this.texto,
    this.color = Colors.black54,
  });

  final IconData icono;
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(texto, style: TextStyle(fontSize: 12, color: color)),
          ),
        ],
      ),
    );
  }
}

class _ChipEstado extends StatelessWidget {
  const _ChipEstado({required this.estado});

  final EstadoRegistro estado;

  @override
  Widget build(BuildContext context) {
    final color = switch (estado) {
      EstadoRegistro.pendiente => const Color(0xFF0052A3),
      EstadoRegistro.enviando => const Color(0xFF8A6300),
      EstadoRegistro.enviado => const Color(0xFF4A6D08),
      EstadoRegistro.error => const Color(0xFFA8460F),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        estado.etiqueta,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Miniatura de una foto de la cola, resuelta contra la carpeta del momento.
class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.nombre});

  final String nombre;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File>(
      future: RegistroLogoStore.archivoFoto(nombre),
      builder: (context, snapshot) {
        final archivo = snapshot.data;
        if (archivo == null || !archivo.existsSync()) {
          return Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFEDF1F7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.image_not_supported_outlined,
              color: Colors.black38,
            ),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(archivo, width: 64, height: 64, fit: BoxFit.cover),
        );
      },
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 56, color: Colors.black26),
            SizedBox(height: 12),
            Text(
              'No hay registros pendientes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Lo que captures se guarda acá hasta que llegue al servidor.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}
