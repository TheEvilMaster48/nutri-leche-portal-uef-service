import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/entrega.dart';
import '../models/evento_marcado.dart';
import '../models/evento_ruta.dart';
import '../models/viaje_chofer.dart';
import '../services/auth_service.dart';
import '../services/catalogo_evento_service.dart';
import '../services/recordatorio_evento_service.dart';
import '../services/viaje_chofer_service.dart';
import '../widget/contador_evento.dart';

/// Los viajes vigentes del chofer: la pantalla principal del módulo Rutas.
///
/// Muestra lo que devuelve `/mis_viajes` — hoy y los dos días anteriores, margen
/// que pone el servidor a propósito para que un viaje de madrugada no
/// desaparezca. Los que tienen un evento abierto van primero: son los que
/// tienen el cronómetro corriendo.
///
/// **El chofer marca eventos del viaje, no de la entrega.** Abre uno del
/// catálogo (`/eventos`) y después lo cierra; las entregas se listan solo para
/// que sepa a quién lleva el producto.
class ViajesPendientesScreen extends StatefulWidget {
  const ViajesPendientesScreen({super.key});

  @override
  State<ViajesPendientesScreen> createState() => _ViajesPendientesScreenState();
}

class _ViajesPendientesScreenState extends State<ViajesPendientesScreen>
    with WidgetsBindingObserver {
  static const Color _azul = Color(0xFF0052A3);

  int get _idUsuario => context.read<AuthService>().currentUser?.id ?? 0;

  /// Qué se está mandando ahora mismo, o `null` si no hay nada en vuelo.
  ///
  /// Tapa la pantalla mientras dura. No es solo cortesía: entre pedir la
  /// posición al GPS y la respuesta del servidor pueden pasar varios segundos,
  /// y sin aviso el chofer cree que no pasó nada y vuelve a tocar.
  String? _enviando;

  /// Manda algo y avisa en qué quedó, con la pantalla tapada mientras tanto.
  ///
  /// Un segundo toque durante el envío se ignora: el servidor es idempotente,
  /// pero una segunda marca con otra hora sí sería un registro distinto.
  ///
  /// Devuelve en qué quedó, o `null` si el toque se ignoró por eso.
  Future<ResultadoMarca?> _enviar(
    String queSeManda,
    Future<ResultadoMarca> Function() accion,
  ) async {
    if (_enviando != null) return null;

    setState(() => _enviando = queSeManda);
    try {
      final resultado = await accion();
      if (mounted) _avisarResultado(resultado);
      return resultado;
    } finally {
      if (mounted) setState(() => _enviando = null);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ViajeChoferService>().iniciar(_idUsuario);
      // El catálogo se lee de disco y se refresca detrás. Va junto con los
      // viajes, no cuando el chofer va a marcar: ver [_pedirEvento].
      context.read<CatalogoEventoService>().iniciar();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed) return;
    if (!mounted) return;

    // Al volver a primer plano se usa el refresco ligero: drena lo que quedó
    // sin enviar y pide solo el delta. Bajar todos los viajes cada vez que el
    // chofer mira el teléfono es gasto de sus datos, y en ruta eso importa.
    context.read<ViajeChoferService>().refrescarLigero(_idUsuario);

    // El catálogo aprovecha el mismo momento. Son 12 filas: cuesta menos que
    // descubrir en la vía, sin señal, que la copia local nunca se bajó.
    context.read<CatalogoEventoService>().sincronizar();
  }

  /// Refresco explícito: baja todo.
  ///
  /// Cuando el chofer tira de la lista quiere la verdad completa, no un delta —
  /// y es el único momento en que puede notar que le falta un viaje asignado
  /// recién. El delta queda para el refresco automático al volver a la app.
  Future<void> _refrescar() async {
    final servicio = context.read<ViajeChoferService>();
    if (servicio.cuantasPendientesEnvio > 0) {
      await servicio.drenar(_idUsuario);
    }
    if (!mounted) return;
    await servicio.cargarViajes(_idUsuario);
    if (!mounted) return;

    // El catálogo también: si bodega agregó un evento, aparece sin publicar una
    // versión nueva de la app.
    await context.read<CatalogoEventoService>().sincronizar();
    if (!mounted) return;

    if (servicio.error == null) return;

    // Solo se avisa el fallo. Cuando sale bien, la lista misma es el aviso.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(servicio.error!),
        backgroundColor: const Color(0xFFA8460F),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Marcar y cerrar
  // ---------------------------------------------------------------------------

  /// Marca la salida de planta: el primer gesto del viaje.
  ///
  /// Hasta que no conste, es lo único que la tarjeta ofrece. El servidor exige
  /// lo mismo —«Primero marque la salida de planta»— así que adelantarlo acá
  /// solo ahorra el viaje de ida y vuelta.
  Future<void> _marcarSalida(ViajeChofer viaje) async {
    if (!viaje.despachado) {
      _avisar(
        'El viaje todavía no está despachado: está en ${viaje.etapa}.',
        const Color(0xFFA8460F),
      );
      return;
    }

    await _enviar(
      'Salida de planta',
      () => context.read<ViajeChoferService>().marcarSalida(
            _idUsuario,
            viajeId: viaje.id,
          ),
    );
  }

  /// Abre un evento del catálogo en [viaje].
  ///
  /// Elegir el evento es todo lo que se le pide al chofer: en cuanto lo toca, la
  /// marca sale con su ubicación y la hora del teléfono, y queda abierta para
  /// cerrarla después. Nada de formularios con el camión parado.
  Future<void> _marcarEvento(ViajeChofer viaje) async {
    final problema = _problemaPara(viaje);
    if (problema != null) {
      _avisar(problema, const Color(0xFFA8460F));
      return;
    }

    final elegido = await _pedirEvento();
    if (elegido == null || !mounted) return;

    final resultado = await _enviar(
      elegido.nombre,
      () => context.read<ViajeChoferService>().marcarEvento(
            _idUsuario,
            viajeId: viaje.id,
            eventoId: elegido.id,
            nombre: elegido.nombre,
          ),
    );

    if (!mounted) return;

    // El aviso de «se te pasó el tiempo» se programa con el id de la marca, que
    // solo existe cuando el servidor la aceptó. Sin señal no se programa: el
    // recordatorio es una cortesía y el dato operativo ya está a salvo en la
    // cola.
    if (resultado?.estado == EstadoMarca.enviada && elegido.tiempoEstimado > 0) {
      final registroId =
          context.read<ViajeChoferService>().porId(viaje.id)?.eventoAbiertoId;
      if (registroId != null) {
        await RecordatorioEventoService.programar(
          idRegistro: registroId,
          nombreEvento: elegido.nombre,
          vencimiento: DateTime.now().add(elegido.duracionEstimada),
        );
      }
    }
  }

  /// Marca el regreso a planta, que es lo que cierra el recorrido del chofer.
  ///
  /// Va por `POST /retorno`, que es del viaje. No es un evento del catálogo a
  /// propósito: el regreso no compite con «Almuerzo» ni con «Falla mecánica»,
  /// y tenerlo en esa lista lo dejaría a un toque de distancia de cualquier otra
  /// cosa.
  ///
  /// Se pregunta antes porque es el gesto que cierra el día.
  Future<void> _finalizarViaje(ViajeChofer viaje) async {
    final servicio = context.read<ViajeChoferService>();
    final problema = viaje.problemaParaFinalizar(
      salidaEnCola: servicio.salidaPendiente(viaje.id),
      retornoEnCola: servicio.retornoPendiente(viaje.id),
    );
    if (problema != null) {
      _avisar(problema, const Color(0xFFA8460F));
      return;
    }

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('¿Regresaste a planta?'),
        content: Text(
          viaje.tieneEventoAbierto
              ? 'Se registra el regreso con la hora y el lugar en que estás '
                  'ahora. Ojo: te queda «${viaje.nombreEventoAbierto}» sin '
                  'cerrar.'
              : 'Se registra el regreso con la hora y el lugar en que estás '
                  'ahora. Es lo que cierra tu ruta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo, false),
            child: const Text('Todavía no'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogo, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4A6D08),
            ),
            child: const Text('Sí, finalizar'),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;

    await _enviar(
      'Regreso a planta',
      () => context.read<ViajeChoferService>().marcarRetorno(
            _idUsuario,
            viajeId: viaje.id,
          ),
    );
  }

  /// Marca lo que pasó con una entrega: llegué, se la dejé, o no se pudo.
  ///
  /// El no entregado pide el motivo antes de salir: el servidor lo exige, y
  /// preguntarlo acá evita un viaje de ida y vuelta con el camión en la puerta
  /// del cliente.
  Future<void> _marcarEntrega(
    ViajeChofer viaje,
    Entrega entrega,
    EstadoRutaEntrega hito,
  ) async {
    final problema = _problemaPara(viaje);
    if (problema != null) {
      _avisar(problema, const Color(0xFFA8460F));
      return;
    }

    var motivo = '';
    if (hito.requiereMotivo) {
      final respondido = await _pedirMotivo();
      // Cancelar no es marcar: se sale sin tocar nada.
      if (respondido == null || !mounted) return;
      motivo = respondido;
    }

    await _enviar(
      entrega.cliente.isEmpty
          ? hito.etiqueta
          : '${entrega.cliente} · ${hito.etiqueta}',
      () => context.read<ViajeChoferService>().marcarEntrega(
            _idUsuario,
            viajeId: viaje.id,
            entregaId: entrega.id,
            hito: hito,
            motivo: motivo,
            cliente: entrega.cliente,
          ),
    );
  }

  /// Pide el motivo de una entrega fallida. `null` si el chofer cancela.
  Future<String?> _pedirMotivo() async {
    final controlador = TextEditingController();

    final motivo = await showDialog<String>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('¿Por qué no se pudo entregar?'),
        content: TextField(
          controller: controlador,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          maxLength: 200,
          decoration: const InputDecoration(
            hintText: 'Local cerrado, rechazo, devolución…',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (valor) => Navigator.pop(dialogo, valor.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogo, controlador.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    controlador.dispose();

    // Un motivo vacío lo rechazaría el servidor: se trata como cancelar en
    // lugar de mandarlo y volver con un error.
    if (motivo == null || motivo.isEmpty) return null;
    return motivo;
  }

  /// Cierra el evento abierto del viaje.
  ///
  /// Manda el `registro_id` que vino en `eventoAbiertoId` — el id de la marca,
  /// no el del catálogo. Si el servidor no lo mandó va en `null` y él cierra el
  /// único abierto, que es la salida para un teléfono que perdió el id.
  Future<void> _cerrarEvento(ViajeChofer viaje) async {
    final registroId = viaje.eventoAbiertoId ?? viaje.marcaAbierta?.id;

    await _enviar(
      'Cierre de ${viaje.nombreEventoAbierto}',
      () => context.read<ViajeChoferService>().cerrarEvento(
            _idUsuario,
            viajeId: viaje.id,
            registroId: registroId,
            nombre: viaje.nombreEventoAbierto,
          ),
    );

    if (!mounted) return;

    // Se cancela el aviso programado aunque el cierre haya quedado en cola: el
    // evento terminó de verdad, y dejar sonando «se te pasó el tiempo» por algo
    // que el chofer ya cerró es peor que no avisar.
    if (registroId != null) {
      await RecordatorioEventoService.cancelar(registroId);
    }
  }

  /// Lo que impide marcar ahora, contando lo que está esperando señal.
  String? _problemaPara(ViajeChofer viaje) {
    final servicio = context.read<ViajeChoferService>();
    return viaje.problemaParaMarcar(
      salidaEnCola: servicio.salidaPendiente(viaje.id),
      retornoEnCola: servicio.retornoPendiente(viaje.id),
    );
  }

  void _avisarResultado(ResultadoMarca resultado) {
    final color = switch (resultado.estado) {
      EstadoMarca.enviada => const Color(0xFF4A6D08),
      // Ámbar y no rojo: guardar sin señal es el comportamiento esperado en
      // ruta, no una falla.
      EstadoMarca.encolada => const Color(0xFF8A6300),
      EstadoMarca.sinRed => const Color(0xFF8A6300),
      EstadoMarca.rechazada => const Color(0xFFA8460F),
    };

    _avisar(resultado.mensaje, color);
  }

  void _avisar(String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Pide qué evento se está marcando. `null` si el chofer cancela.
  ///
  /// **Nunca sale a la red.** El catálogo se baja al abrir la pantalla y con
  /// cada actualización de los viajes, y queda guardado en el teléfono; acá solo
  /// se lee. Es deliberado: marcar pasa en la vía, casi siempre sin cobertura, y
  /// una llamada en este punto dejaría al chofer esperando un timeout con el
  /// camión detenido para al final no ofrecerle nada.
  ///
  /// Si aun así estuviera vacío se relee el disco —por si la pantalla se abrió
  /// antes de que terminara la primera carga— y, si tampoco hay, se le dice que
  /// tiene que conectarse una vez.
  Future<EventoRuta?> _pedirEvento() async {
    final catalogo = context.read<CatalogoEventoService>();

    if (catalogo.vacio) {
      await catalogo.cargarCache();
      if (!mounted) return null;
    }

    final eventos = context.read<CatalogoEventoService>().eventos;

    if (eventos.isEmpty) {
      if (!mounted) return null;

      // Se dice qué falló, no solo que falló: «no se pudo cargar» sin más deja
      // sin saber si es el servidor, la red o que el catálogo vino vacío.
      final detalle = context.read<CatalogoEventoService>().error;
      _avisar(
        detalle == null
            ? 'Todavía no tienes la lista de eventos en el teléfono. '
                'Conéctate una vez para descargarla.'
            : 'No hay lista de eventos guardada. Último intento: $detalle',
        const Color(0xFFA8460F),
      );
      return null;
    }

    return showDialog<EventoRuta>(
      context: context,
      builder: (dialogo) => SimpleDialog(
        title: const Text('¿Qué estás haciendo?'),
        children: [
          for (final evento in eventos)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogo, evento),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Icon(
                      evento.exigeEvidencia
                          ? Icons.photo_camera_outlined
                          : Icons.play_circle_outline,
                      size: 18,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            evento.nombre,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          // El catálogo tiene dos «ALIMENTACION» que solo se
                          // distinguen acá: uno es desayuno y el otro almuerzo.
                          if (evento.detalle.isNotEmpty)
                            Text(
                              evento.detalle,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (evento.tiempoEstimado > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${evento.tiempoEstimado} min',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextButton(
              onPressed: () => Navigator.pop(dialogo),
              child: const Text('Cancelar'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final servicio = context.watch<ViajeChoferService>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          'Mis viajes',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _azul,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
          onRefresh: _refrescar,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _Encabezado(servicio: servicio)),
              if (servicio.visibles.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _Vacio(
                    cargando: servicio.cargando,
                    error: servicio.error,
                    todoFinalizado: servicio.todoFinalizado,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverList.separated(
                    itemCount: servicio.visibles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _TarjetaViaje(
                      viaje: servicio.visibles[i],
                      // Lo encolado cuenta igual que lo confirmado: si no, la
                      // pantalla pediría de nuevo lo que el chofer ya marcó,
                      // hasta que hubiera señal.
                      salioDePlanta: servicio.visibles[i].salioDePlanta ||
                          servicio.salidaPendiente(servicio.visibles[i].id),
                      finalizado: servicio.visibles[i].volvioAPlanta ||
                          servicio.retornoPendiente(servicio.visibles[i].id),
                      marcarSalida: () => _marcarSalida(servicio.visibles[i]),
                      marcarEvento: () => _marcarEvento(servicio.visibles[i]),
                      marcarEntrega: (entrega, hito) => _marcarEntrega(
                        servicio.visibles[i],
                        entrega,
                        hito,
                      ),
                      cerrarEvento: () => _cerrarEvento(servicio.visibles[i]),
                      finalizarViaje: () =>
                          _finalizarViaje(servicio.visibles[i]),
                    ),
                  ),
                ),
                ],
              ),
            ),
          ),
          // Va encima de todo y traga los toques: mientras algo está en vuelo,
          // un segundo toque crearía una marca con otra hora.
          if (_enviando != null) _CapaEnviando(queSeManda: _enviando!),
        ],
      ),
    );
  }
}

/// Lo que se ve mientras una marca va camino al servidor.
///
/// Entre pedirle la posición al GPS y la respuesta pueden pasar varios
/// segundos, y en ruta bastantes más. Sin esto el chofer no sabe si su toque
/// hizo algo.
class _CapaEnviando extends StatelessWidget {
  const _CapaEnviando({required this.queSeManda});

  final String queSeManda;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x99101A24),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 16),
                Text(
                  'Enviando…',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  queSeManda,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 10),
                Text(
                  // Se dice antes de que pase: así, si tarda, el chofer ya sabe
                  // que no va a perder lo que marcó.
                  'Si no hay señal se guarda en el teléfono y se envía después.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.servicio});

  final ViajeChoferService servicio;

  String get _textoSincronizado {
    final fecha = servicio.sincronizado;
    if (fecha == null) return 'Todavía sin sincronizar';

    final t = DateTime.now().difference(fecha);
    if (t.inMinutes < 1) return 'Actualizado hace instantes';
    if (t.inMinutes < 60) return 'Actualizado hace ${t.inMinutes} min';
    if (t.inHours < 24) {
      return 'Actualizado hace ${t.inHours} ${t.inHours == 1 ? "hora" : "horas"}';
    }
    return 'Actualizado hace ${t.inDays} ${t.inDays == 1 ? "día" : "días"}';
  }

  @override
  Widget build(BuildContext context) {
    final hayError = servicio.error != null;
    final abiertos = servicio.conEventoAbierto.length;
    final enCurso = servicio.visibles.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                enCurso == 0
                    ? (servicio.todoFinalizado
                        ? 'Viajes terminados'
                        : 'Viajes vigentes')
                    : abiertos == 0
                        ? '$enCurso ${enCurso == 1 ? "viaje" : "viajes"}'
                        : abiertos == 1
                            ? '1 evento sin cerrar'
                            : '$abiertos eventos sin cerrar',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
              ),
              const Spacer(),
              if (servicio.cargando)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tus viajes de hoy y de los dos días anteriores.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          if (servicio.cuantasPendientesEnvio > 0) ...[
            const SizedBox(height: 10),
            _AvisoCola(cantidad: servicio.cuantasPendientesEnvio),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                hayError ? Icons.cloud_off : Icons.cloud_done_outlined,
                size: 15,
                color:
                    hayError ? const Color(0xFFA8460F) : Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  // El msg del WS está redactado para el chofer: se muestra
                  // tal cual, junto con la antigüedad de lo que está viendo.
                  hayError
                      ? '${servicio.error}  ·  $_textoSincronizado'
                      : _textoSincronizado,
                  style: TextStyle(
                    fontSize: 12,
                    color: hayError
                        ? const Color(0xFFA8460F)
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TarjetaViaje extends StatefulWidget {
  const _TarjetaViaje({
    required this.viaje,
    required this.salioDePlanta,
    required this.finalizado,
    required this.marcarSalida,
    required this.marcarEvento,
    required this.marcarEntrega,
    required this.cerrarEvento,
    required this.finalizarViaje,
  });

  final ViajeChofer viaje;

  /// El camión ya salió: consta en el servidor, o la salida está en la cola.
  final bool salioDePlanta;

  /// El viaje ya cerró: regresó a planta, o el regreso está en la cola.
  final bool finalizado;

  /// Se delegan a la pantalla: es la que tiene el contexto para el selector del
  /// catálogo y para el aviso del resultado.
  final Future<void> Function() marcarSalida;
  final Future<void> Function() marcarEvento;

  /// Lo que se marca por cliente: llegada y las dos salidas.
  final Future<void> Function(Entrega entrega, EstadoRutaEntrega hito)
      marcarEntrega;
  final Future<void> Function() cerrarEvento;
  final Future<void> Function() finalizarViaje;

  @override
  State<_TarjetaViaje> createState() => _TarjetaViajeState();
}

class _TarjetaViajeState extends State<_TarjetaViaje> {
  bool _abierta = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.viaje;
    // **Las entregas no se despliegan: se ven siempre.** Son el trabajo del
    // chofer —a quién llegar y qué marcarle—, y tenerlas detrás de un toque las
    // escondía justo cuando llevan los botones.
    //
    // Lo que sí se despliega es el historial de eventos ya cerrados, que se
    // consulta de vez en cuando y ocupa sitio.
    //
    // El avance por bodega (`v.eventos`) NO se pinta: al chofer le sirve saber
    // si su entrega ya está generada —eso va en la pastilla de arriba—, no cada
    // paso interno de planta con su responsable.
    final hayHistorial = v.eventosCerrados.isNotEmpty;

    // Solo se marca lo que el viaje admite: en el patio, o después del regreso,
    // las filas quedan informativas.
    final puedeMarcar =
        v.problemaParaMarcar(salidaEnCola: widget.salioDePlanta) == null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          // Ámbar mientras hay un evento corriendo: es lo que el chofer está
          // haciendo ahora y manda sobre lo demás. Verde cuando la entrega al
          // cliente ya está generada, o sea cuando el viaje está completo de
          // ese lado. Azul mientras todavía falta.
          color: v.tieneEventoAbierto
              ? const Color(0xFFE8D9A8)
              : v.entregaGenerada == true
                  ? const Color(0xFFCBDDA6)
                  : const Color(0xFFCBD9EC),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap:
                hayHistorial ? () => setState(() => _abierta = !_abierta) : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Viaje ${v.numero}',
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        v.fecha,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const Spacer(),
                      if (v.urgencia != Urgencia.baja)
                        _ChipUrgencia(urgencia: v.urgencia),
                    ],
                  ),
                  if (v.resumenDestino.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      v.resumenDestino,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (v.etapaVisible.isNotEmpty)
                        _Pastilla(texto: v.etapaVisible),
                      // Lo que el chofer no podía ver: si el ERP ya generó la
                      // entrega al cliente. Se omite cuando no se sabe, en vez
                      // de afirmar «sin generar» a la ligera.
                      if (v.entregaGenerada == true)
                        _Pastilla(
                          texto: v.entregaGeneradaEn.isEmpty
                              ? 'Entrega generada'
                              : 'Entrega generada · ${v.entregaGeneradaEn}',
                          icono: Icons.check_circle_outline,
                          resaltado: true,
                        )
                      else if (v.entregaGenerada == false)
                        _Pastilla(
                          texto: 'Entrega sin generar',
                          icono: Icons.receipt_long_outlined,
                          alerta: true,
                        ),
                      if (v.placa.isNotEmpty)
                        _Pastilla(texto: v.placa, icono: Icons.local_shipping),
                      if (v.totalEntregas > 0)
                        _Pastilla(
                          // El avance, no solo el total: es lo que el chofer
                          // mira para saber cuánto le queda del día.
                          texto: v.entregas.isEmpty
                              ? '${v.totalEntregas} '
                                  '${v.totalEntregas == 1 ? "entrega" : "entregas"}'
                              : '${v.entregasCerradas} de '
                                  '${v.entregas.length} entregas',
                          icono: Icons.inventory_2_outlined,
                          resaltado:
                              v.entregas.isNotEmpty && v.entregasCompletas,
                        ),
                      if (v.eventosRuta.isNotEmpty)
                        _Pastilla(
                          texto: '${v.eventosRuta.length} '
                              '${v.eventosRuta.length == 1 ? "evento" : "eventos"}',
                          icono: Icons.timelapse_outlined,
                        ),
                    ],
                  ),
                  if (hayHistorial)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _abierta
                                ? 'Ocultar eventos'
                                : 'Ver ${v.eventosCerrados.length} '
                                    '${v.eventosCerrados.length == 1 ? "evento" : "eventos"}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Icon(
                            _abierta ? Icons.expand_less : Icons.expand_more,
                            size: 20,
                            color: Colors.grey.shade500,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  // El evento abierto manda: mientras haya uno, lo único que se
                  // ofrece es cerrarlo. Es lo que el chofer está haciendo, y el
                  // ERP lo tiene contando minutos.
                  if (!widget.salioDePlanta)
                    // Antes de salir no se ofrece nada más. El viaje empieza con
                    // un solo gesto y el servidor exige lo mismo: un evento con
                    // el camión en el patio descuadra los tiempos de despacho.
                    _BotonSalida(
                      problema: v.despachado
                          ? null
                          : 'El viaje todavía no está despachado: '
                              'está en ${v.etapa}.',
                      marcar: widget.marcarSalida,
                    )
                  else if (v.tieneEventoAbierto)
                    _EventoAbierto(
                      marca: v.marcaAbierta,
                      nombre: v.nombreEventoAbierto,
                      cerrar: widget.cerrarEvento,
                    )
                  else if (widget.finalizado)
                    // Ya volvió: el viaje se cierra ahí. No se ofrece marcar
                    // nada más porque el servidor tampoco lo acepta, y un botón
                    // que solo sirve para recibir un rechazo no es un botón.
                    _ViajeFinalizado(retornoEn: v.retornoEn)
                  else
                    _BotonMarcar(
                      problema: null,
                      // El regreso espera a los clientes; el botón se dibuja
                      // igual, apagado y con el motivo, para que el chofer sepa
                      // qué le falta.
                      problemaFinalizar: v.problemaParaFinalizar(
                        salidaEnCola: widget.salioDePlanta,
                      ),
                      marcar: widget.marcarEvento,
                      finalizar: widget.finalizarViaje,
                    ),
                ],
              ),
            ),
          ),
          if (v.entregas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _Rotulo(texto: 'Entregas a bordo'),
                      const Spacer(),
                      Text(
                        '${v.entregasCerradas} de ${v.entregas.length}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: v.entregasCompletas
                              ? const Color(0xFF4A6D08)
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  for (final entrega in v.entregas)
                    _FilaEntrega(
                      entrega: entrega,
                      marcar: puedeMarcar
                          ? (hito) => widget.marcarEntrega(entrega, hito)
                          : null,
                    ),
                ],
              ),
            ),
          if (_abierta && hayHistorial)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                children: [
                  if (v.entregas.isEmpty) ...[
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                  ],
                  _EventosCerrados(eventos: v.eventosCerrados),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// El primer botón del viaje: la salida de planta.
///
/// Mientras no conste, es lo único que la tarjeta ofrece. Ni eventos ni
/// finalizar: un camión que no ha salido no puede haber vuelto, y ofrecerlo solo
/// invita a marcarlo por error.
class _BotonSalida extends StatelessWidget {
  const _BotonSalida({required this.problema, required this.marcar});

  final String? problema;
  final Future<void> Function() marcar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: problema == null ? () => marcar() : null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0052A3),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Marcar salida de planta'),
          ),
        ),
        if (problema != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2, right: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 13, color: Colors.grey.shade600),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    problema!,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.3,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// El botón de marcar, apagado con su motivo cuando el viaje no lo admite.
class _BotonMarcar extends StatelessWidget {
  const _BotonMarcar({
    required this.problema,
    required this.problemaFinalizar,
    required this.marcar,
    required this.finalizar,
  });

  /// Por qué no se puede marcar ahora, o `null` si sí se puede.
  ///
  /// El botón se dibuja igual, apagado y con el motivo debajo: esconderlo
  /// dejaría al chofer sin saber por qué no puede registrar lo que le pasa.
  final String? problema;

  /// Por qué no se puede cerrar el viaje todavía. Suele ser un cliente sin
  /// confirmar.
  final String? problemaFinalizar;

  final Future<void> Function() marcar;

  final Future<void> Function() finalizar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: problema == null ? () => marcar() : null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0052A3),
            ),
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Marcar evento'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: problemaFinalizar == null ? () => finalizar() : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4A6D08),
              side: const BorderSide(color: Color(0xFFCBDDA6)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.home_outlined, size: 18),
            label: const Text('Finalizar viaje · regreso a planta'),
          ),
        ),
        if (problemaFinalizar != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2, right: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 13, color: Colors.grey.shade600),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    problemaFinalizar!,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.3,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (problema != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2, right: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 13, color: Colors.grey.shade600),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    problema!,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.3,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// El evento en curso, con su cronómetro y el botón para cerrarlo.
class _EventoAbierto extends StatelessWidget {
  const _EventoAbierto({
    required this.marca,
    required this.nombre,
    required this.cerrar,
  });

  /// La marca abierta. Puede faltar si el servidor mandó `eventoAbiertoId` sin
  /// la lista: entonces se pinta el aviso simple, sin contador.
  final EventoMarcado? marca;

  final String nombre;

  final Future<void> Function() cerrar;

  @override
  Widget build(BuildContext context) {
    final inicio = marca?.inicioInstante;
    final titulo = nombre.isNotEmpty ? nombre : (marca?.titulo ?? 'Evento');

    return Column(
      children: [
        const SizedBox(height: 6),
        if (inicio != null)
          // El catálogo sí trae tiempo estimado, así que el contador puede
          // avisar cuando se pasa. Con minutosEstimados en 0, Cronometro
          // muestra «Abierto hace X» y no vence.
          ContadorEvento(
            inicio: inicio,
            minutosEstimados: marca?.minutosEstimados ?? 0,
            nombreEvento: titulo,
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF6E3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8D9A8)),
            ),
            child: Text(
              'Evento abierto: $titulo',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8A6300),
              ),
            ),
          ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => cerrar(),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF8A6300),
            ),
            icon: const Icon(Icons.stop_circle_outlined, size: 18),
            label: Text('Terminar $titulo'),
          ),
        ),
      ],
    );
  }
}

/// El viaje ya cerró: el chofer marcó el regreso a planta.
class _ViajeFinalizado extends StatelessWidget {
  const _ViajeFinalizado({required this.retornoEn});

  /// `dd/MM/yyyy HH:mm` del regreso, tal como lo manda el servidor. Vacío
  /// mientras el regreso espera señal en la cola.
  final String retornoEn;

  @override
  Widget build(BuildContext context) {
    final cuando = retornoEn.trim();

    return Column(
      children: [
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF4E4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBDDA6)),
          ),
          child: Row(
            children: [
              const Icon(Icons.flag, size: 16, color: Color(0xFF4A6D08)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cuando.isEmpty
                      ? 'Viaje finalizado · regreso a planta guardado'
                      : 'Viaje finalizado · regresaste a planta $cuando',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A6D08),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Una entrega del viaje. Informativa: el chofer no la marca.
class _FilaEntrega extends StatelessWidget {
  const _FilaEntrega({required this.entrega, required this.marcar});

  final Entrega entrega;

  /// `null` cuando el viaje no admite marcar —en el patio, o ya de vuelta—: la
  /// fila queda informativa en vez de ofrecer un botón que el servidor rechaza.
  final Future<void> Function(EstadoRutaEntrega hito)? marcar;

  /// Un color por estado. Lo resuelve el servidor; acá solo se le pone color
  /// para que el chofer lo lea de un vistazo.
  (Color, Color, IconData) get _pinta => switch (entrega.estadoRuta) {
        EstadoRutaEntrega.pendiente => (
            const Color(0xFFF5F7FB),
            const Color(0xFF5A6674),
            Icons.radio_button_unchecked,
          ),
        EstadoRutaEntrega.enCliente => (
            const Color(0xFFE8EEF8),
            const Color(0xFF0A4697),
            Icons.pin_drop_outlined,
          ),
        EstadoRutaEntrega.entregado => (
            const Color(0xFFEFF4E4),
            const Color(0xFF4A6D08),
            Icons.check_circle,
          ),
        EstadoRutaEntrega.noEntregado => (
            const Color(0xFFFBF0EA),
            const Color(0xFFA8460F),
            Icons.cancel_outlined,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final (fondo, tinta, icono) = _pinta;
    final marcar = this.marcar;
    final siguiente = entrega.siguienteAccion;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, size: 16, color: tinta),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entrega.destino.isEmpty
                          ? entrega.numero
                          : entrega.destino,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (entrega.numero.isNotEmpty && entrega.destino.isNotEmpty)
                      Text(
                        'Entrega ${entrega.numero}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    if (entrega.motivo.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          entrega.motivo,
                          style: TextStyle(fontSize: 11.5, color: tinta),
                        ),
                      )
                    else if (entrega.referencia.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          entrega.referencia,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                entrega.estadoTexto,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: tinta,
                ),
              ),
            ],
          ),
          // Los botones salen de siguienteAccion, que resuelve el servidor. La
          // app no deduce qué se puede marcar: si dedujera, al cambiar una regla
          // habría dos versiones de la verdad.
          if (marcar != null && siguiente != null) ...[
            const SizedBox(height: 9),
            _BotonesEntrega(siguiente: siguiente, marcar: marcar),
          ],
        ],
      ),
    );
  }
}

/// Los botones que corresponden al estado que el servidor habilitó.
///
/// Cuando toca cerrar se ofrecen **las dos salidas juntas** —entregado y no
/// entregado— porque son el mismo momento para el chofer: está frente al cliente
/// y una de las dos cosas pasó.
class _BotonesEntrega extends StatelessWidget {
  const _BotonesEntrega({required this.siguiente, required this.marcar});

  final EstadoRutaEntrega siguiente;
  final Future<void> Function(EstadoRutaEntrega hito) marcar;

  @override
  Widget build(BuildContext context) {
    if (siguiente == EstadoRutaEntrega.enCliente) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => marcar(EstadoRutaEntrega.enCliente),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0A4697),
            side: const BorderSide(color: Color(0xFF9EBCE4)),
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
          icon: const Icon(Icons.pin_drop_outlined, size: 17),
          label: const Text('Llegué al cliente'),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => marcar(EstadoRutaEntrega.entregado),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4A6D08),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            icon: const Icon(Icons.check, size: 17),
            label: const Text('Entregado'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => marcar(EstadoRutaEntrega.noEntregado),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFA8460F),
              side: const BorderSide(color: Color(0xFFE8C3AF)),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            icon: const Icon(Icons.close, size: 17),
            label: const Text('No entregado'),
          ),
        ),
      ],
    );
  }
}

/// Los eventos ya cerrados: cuánto duró cada uno.
class _EventosCerrados extends StatelessWidget {
  const _EventosCerrados({required this.eventos});

  final List<EventoMarcado> eventos;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        _Rotulo(texto: 'Eventos del viaje'),
        const SizedBox(height: 7),
        for (final e in eventos)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                // Lo que se resalta es haberse pasado del tiempo estimado, que
                // es lo que el servidor calcula y lo que mira la operación.
                Icon(
                  e.excedido
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                  size: 14,
                  color: e.excedido
                      ? const Color(0xFFA8460F)
                      : Colors.grey.shade500,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    e.titulo,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight:
                          e.excedido ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (e.inicioEn.isNotEmpty) ...[
                  Text(
                    e.inicioEn,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  '${e.minutos} min',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: e.excedido
                        ? const Color(0xFFA8460F)
                        : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Rotulo extends StatelessWidget {
  const _Rotulo({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }
}

/// Aviso de que hay marcas esperando señal.
class _AvisoCola extends StatelessWidget {
  const _AvisoCola({required this.cantidad});

  final int cantidad;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF6E3),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFE8D9A8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_upload_outlined,
              size: 16, color: Color(0xFF8A6300)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              cantidad == 1
                  ? '1 marca guardada, esperando señal.'
                  : '$cantidad marcas guardadas, esperando señal.',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF8A6300)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipUrgencia extends StatelessWidget {
  const _ChipUrgencia({required this.urgencia});

  final Urgencia urgencia;

  @override
  Widget build(BuildContext context) {
    final (fondo, tinta) = urgencia == Urgencia.alta
        ? (const Color(0xFFFBF0EA), const Color(0xFFA8460F))
        : (const Color(0xFFFDF6E3), const Color(0xFF8A6300));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        urgencia.codigo,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: tinta,
        ),
      ),
    );
  }
}

class _Pastilla extends StatelessWidget {
  const _Pastilla({
    required this.texto,
    this.icono,
    this.resaltado = false,
    this.alerta = false,
  });

  final String texto;
  final IconData? icono;

  /// Verde: algo que ya está hecho.
  final bool resaltado;

  /// Ámbar: algo que todavía falta. No es rojo — que la entrega no esté
  /// generada es normal temprano en el día, no una falla.
  final bool alerta;

  @override
  Widget build(BuildContext context) {
    final tinta = alerta
        ? const Color(0xFF8A6300)
        : resaltado
            ? const Color(0xFF4A6D08)
            : Colors.grey.shade800;

    final fondo = alerta
        ? const Color(0xFFFDF6E3)
        : resaltado
            ? const Color(0xFFEFF4E4)
            : const Color(0xFFF5F7FB);

    final borde = alerta
        ? const Color(0xFFE8D9A8)
        : resaltado
            ? const Color(0xFFCBDDA6)
            : const Color(0xFFE0E0E0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: borde),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 12, color: tinta),
            const SizedBox(width: 4),
          ],
          Text(
            texto,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: tinta,
            ),
          ),
        ],
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({
    required this.cargando,
    required this.error,
    this.todoFinalizado = false,
  });

  final bool cargando;
  final String? error;

  /// Había viajes y el chofer los cerró todos. Es distinto de no tener ninguno,
  /// y decirle «no tienes viajes asignados» después de trabajar todo el día
  /// parecería que se perdió lo que marcó.
  final bool todoFinalizado;

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              error != null
                  ? Icons.cloud_off
                  : todoFinalizado
                      ? Icons.check_circle_outline
                      : Icons.local_shipping_outlined,
              size: 46,
              color: todoFinalizado && error == null
                  ? const Color(0xFF7FA33C)
                  : Colors.grey.shade400,
            ),
            const SizedBox(height: 14),
            Text(
              // Sin error, una lista vacía significa de verdad que no hay
              // viajes: no hay que hacerlo parecer una falla.
              error ??
                  (todoFinalizado
                      ? 'Terminaste todos tus viajes. Buen trabajo.'
                      : 'No tienes viajes asignados en estos días.'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 6),
            Text(
              todoFinalizado && error == null
                  ? 'Si te asignan otro, aparecerá al actualizar.'
                  : 'Desliza hacia abajo para volver a consultar.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}
