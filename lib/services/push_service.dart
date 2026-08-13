import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

import '../firebase_options.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

import '../models/cumpleanios.dart';
import '../models/evento.dart';
import '../models/nutrisoft.dart';
import '../models/sorteo.dart';
import '../screens/detalle_cumpleanios_screen.dart';
import '../screens/detalle_evento_screen.dart';
import '../screens/detalle_nutrisoft_screen.dart';
import '../screens/detalle_sorteo_screen.dart';
import 'auth_service.dart';
import 'cumpleanios_service.dart';
import 'evento_service.dart';
import 'notification_bus.dart';
import 'nutrisoft_service.dart';
import 'sorteo_service.dart';

final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();

/// Navegador global: permite abrir pantallas desde fuera del árbol de widgets
/// (al tocar una notificación). Se conecta en `MaterialApp(navigatorKey: ...)`.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  print('NOTIFICACIÓN en BACKGROUND');
  print('Título: ${message.notification?.title}');
  print('Body: ${message.notification?.body}');
  print('Data: ${message.data}');

  await _dibujarEnBackground(message);
}

/// Dibuja la notificación desde el isolate de background para que el tap siga
/// el MISMO camino que en primer plano.
///
/// En primer plano el deep-link funciona porque la notificación la pinta
/// `flutter_local_notifications` con el `data` en el `payload`, y el tap entra
/// por `onDidReceiveNotificationResponse`. Cuando la dibuja FCM (app cerrada o
/// en segundo plano) el tap depende del intent nativo, que es otro camino y
/// mucho más frágil. Pintándola nosotros, los tres estados convergen.
///
/// Dos condiciones:
///
///  * Solo Android. En iOS un push sin bloque `notification` es un silent push:
///    no muestra alerta y el handler ni siquiera corre de forma garantizada, así
///    que allá conviene que el back siga mandando `notification`.
///  * Solo si el push NO trae bloque `notification`. Si lo trae, el sistema ya
///    dibujó la suya y pintar otra la duplicaría.
///
/// Es decir: para que esto entre en juego, el back debe mandar el push de
/// Android como **data-only**.
@pragma('vm:entry-point')
Future<void> _dibujarEnBackground(RemoteMessage message) async {
  if (!Platform.isAndroid) return;

  if (message.notification != null) {
    print('PUSH BG: el push trae bloque "notification", la dibuja el sistema. '
        'Para que el tap use el camino de la notificación local, el back debe '
        'mandar el push de Android como data-only.');
    return;
  }

  if (message.data.isEmpty) return;

  final data = message.data;
  final titulo = (data['title'] ?? data['titulo'] ?? '').toString();
  final cuerpo = (data['body'] ?? data['mensaje'] ?? data['cuerpo'] ?? '')
      .toString();

  if (titulo.isEmpty && cuerpo.isEmpty) {
    print('PUSH BG: data-only sin title/body, no hay nada que mostrar.');
    return;
  }

  // Isolate distinto al de la app: el plugin y el canal se preparan de nuevo.
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(highImportanceChannel);

  await plugin.show(
    message.hashCode,
    titulo.isEmpty ? null : titulo,
    cuerpo.isEmpty ? null : cuerpo,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'high_importance_channel',
        'Notificaciones importantes',
        channelDescription: 'Canal para notificaciones importantes',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      ),
    ),
    // Mismo payload que en primer plano: es lo que lee el tap para navegar.
    payload: json.encode(data),
  );
}

const AndroidNotificationChannel highImportanceChannel =
    AndroidNotificationChannel(
  'high_importance_channel',
  'Notificaciones importantes',
  description: 'Canal para notificaciones importantes',
  importance: Importance.max,
);

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  /// Si ya se revisó `getNotificationAppLaunchDetails()` en este proceso.
  ///
  /// Estática y deliberadamente NO se resetea en [stopCompletely]: ese dato
  /// sobrevive al logout y releerlo reabriría la notificación vieja al volver a
  /// iniciar sesión.
  static bool _lanzamientoLocalRevisado = false;

  /// Registra lo que DEBE quedar listo antes de `runApp()`.
  ///
  /// El handler de background tiene que engancharse en el arranque del proceso:
  /// si se registra más tarde (por ejemplo desde el menú, ya con sesión), el
  /// isolate de background no queda configurado en un arranque en frío. El canal
  /// de Android se crea aquí también, porque las notificaciones que dibuja FCM
  /// con la app cerrada lo necesitan existente para respetar su importancia.
  static Future<void> registrarHandlersTempranos() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    if (Platform.isAndroid) {
      try {
        await localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(highImportanceChannel);
      } catch (e) {
        debugPrint('PUSH: no se pudo crear el canal en el arranque: $e');
      }
    }

    // Si la app arrancó por el tap de una notificación, el mensaje se lee aquí
    // y no en init(): en Android el intent que lo trae se consume una sola vez,
    // y init() corre bastante después (recién al montarse el menú).
    try {
      final inicial = await FirebaseMessaging.instance.getInitialMessage();
      if (inicial != null) {
        debugPrint('PUSH: arranque desde notificación. Data: ${inicial.data}');
        instance._pendiente = Map<String, dynamic>.from(inicial.data);
      }
    } catch (e) {
      debugPrint('PUSH: no se pudo leer getInitialMessage en el arranque: $e');
    }
  }

  bool _initialized = false;
  StreamSubscription<RemoteMessage>? _listener;
  StreamSubscription<RemoteMessage>? _listenerTap;

  /// Notificación tocada que todavía no se pudo abrir (app arrancando, o sin
  /// sesión iniciada). Se consume desde [procesarPendiente].
  Map<String, dynamic>? _pendiente;

  Future<void> dispose() async {
    await _listener?.cancel();
    await _listenerTap?.cancel();
  }

  Future<void> stopCompletely() async {
    await _listener?.cancel();
    await _listenerTap?.cancel();
    _listener = null;
    _listenerTap = null;
    _pendiente = null;
    _initialized = false;
    print("🔴 PushService Detenido COMPLETAMENTE");
  }

  Future<void> init() async {
    // El guard va PRIMERO: antes se cancelaban los listeners y después se
    // retornaba por estar ya inicializado, así que una segunda llamada a init()
    // los dejaba cancelados y los taps de notificación no volvían a funcionar.
    if (_initialized) {
      debugPrint('PUSH: ya inicializado, se conservan los listeners');
      return;
    }
    _initialized = true;

    await _listener?.cancel();
    await _listenerTap?.cancel();
    _listener = null;
    _listenerTap = null;

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    // `onBackgroundMessage` ya quedó registrado en `main()`
    // (ver [registrarHandlersTempranos]).

    const AndroidInitializationSettings initSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: initSettingsAndroid,
      iOS: initSettingsIOS,
    );

    // El tap sobre la notificación local (la que se dibuja cuando el push llega
    // con la app abierta) trae en `payload` el `data` original serializado.
    await localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse respuesta) {
        final payload = respuesta.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final decoded = json.decode(payload);
          if (decoded is Map) {
            abrirDesdeNotificacion(Map<String, dynamic>.from(decoded));
          }
        } catch (e) {
          debugPrint('PUSH: payload de notificación local inválido: $e');
        }
      },
    );

    if (Platform.isAndroid) {
      await localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(highImportanceChannel);
    }

    // Caso aparte: la notificación se dibujó con la app en primer plano, luego
    // la app se cerró y recién ahí el usuario la tocó. Ese tap NO pasa por
    // `onDidReceiveNotificationResponse` ni por `getInitialMessage`; solo queda
    // aquí.
    //
    // Se lee UNA SOLA VEZ por proceso: a diferencia de `getInitialMessage()`,
    // esto no se consume, devuelve los datos del lanzamiento mientras el proceso
    // viva. Como `stopCompletely()` (logout) baja `_initialized`, al volver a
    // entrar `init()` corre otra vez y sin esta guarda reabría el mismo registro
    // de la notificación vieja. Por eso la bandera es estática y no se resetea
    // al cerrar sesión.
    if (!_lanzamientoLocalRevisado) {
      _lanzamientoLocalRevisado = true;
      try {
        final lanzamiento =
            await localNotifications.getNotificationAppLaunchDetails();
        final payload = lanzamiento?.notificationResponse?.payload;
        if (lanzamiento?.didNotificationLaunchApp == true &&
            payload != null &&
            payload.isNotEmpty) {
          final decoded = json.decode(payload);
          if (decoded is Map) {
            debugPrint(
                'PUSH: arranque desde notificación local. Data: $decoded');
            _pendiente ??= Map<String, dynamic>.from(decoded);
          }
        }
      } catch (e) {
        debugPrint('PUSH: no se pudo leer getNotificationAppLaunchDetails: $e');
      }
    }

    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // iOS no muestra nada en primer plano salvo que se le pida explícitamente.
    //
    // Acá NO sirve dibujar una notificación local como en Android: Firebase se
    // queda con el `UNUserNotificationCenter.delegate` (method swizzling), así
    // que la local de flutter_local_notifications nunca llega a presentarse.
    // Con esto la presenta el propio iOS, y el tap sigue entrando por
    // `onMessageOpenedApp`.
    if (Platform.isIOS) {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    String? token;

    if (kIsWeb || Platform.isAndroid) {
      try {
        token = await messaging.getToken();
        print('FCM TOKEN (Android/Web) = $token');
      } catch (e) {
        print('Error obteniendo token: $e');
      }
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      print('TOKEN REFRESH = $newToken');
    });

    _listener =
        FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('NOTIFICACIÓN EN FOREGROUND - 1 SOLO LISTENER');
      debugPrint('Data: ${message.data}');

      // Avisa a la UI (badges del menú) que llegó algo nuevo.
      FirebaseNotificationBus.add(Map<String, dynamic>.from(message.data));

      // El `data` viaja en el payload para poder navegar cuando se toque.
      final payload = json.encode(message.data);

      final notification = message.notification;

      // Con el back mandando data-only (ver [_dibujarEnBackground]) no hay
      // bloque `notification`: el título y el cuerpo se leen del `data`.
      final titulo = notification?.title ??
          (message.data['title'] ?? message.data['titulo'])?.toString();
      final cuerpo = notification?.body ??
          (message.data['body'] ??
                  message.data['mensaje'] ??
                  message.data['cuerpo'])
              ?.toString();
      final hayAlgoQueMostrar =
          (titulo != null && titulo.isNotEmpty) ||
              (cuerpo != null && cuerpo.isNotEmpty);
      final idNotificacion = notification?.hashCode ?? message.hashCode;

      if (hayAlgoQueMostrar && Platform.isAndroid) {
        await localNotifications.show(
          idNotificacion,
          titulo,
          cuerpo,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'Notificaciones importantes',
              channelDescription: 'Canal para notificaciones importantes',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              icon: '@mipmap/ic_launcher',
            ),
          ),
          payload: payload,
        );
      }
      // En iOS no se dibuja nada: la presenta el sistema por
      // `setForegroundNotificationPresentationOptions`. Dibujar además la local
      // duplicaría el aviso apenas el delegate quedara del lado del plugin.
    });

    // App en segundo plano y el usuario toca la notificación del sistema.
    _listenerTap = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('NOTIFICACIÓN ABIERTA (background) Data: ${message.data}');
      abrirDesdeNotificacion(Map<String, dynamic>.from(message.data));
    });

    // El caso "app cerrada por completo" ya se resolvió en
    // [registrarHandlersTempranos], que corre una sola vez por proceso desde
    // `main()`. Releer `getInitialMessage()` acá reabriría la notificación vieja
    // cada vez que se vuelve a iniciar sesión.
  }

  // ---------------------------------------------------------------------------
  // Navegación al contenido de la notificación
  // ---------------------------------------------------------------------------

  static int _aInt(dynamic v) =>
      v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

  /// Aplana el `data` del push.
  ///
  /// FCM entrega el data payload con TODOS los valores como String, y este
  /// backend suele meter JSON escapado dentro de un campo (igual que hace con
  /// `data` en el login y en las reacciones). Así que cualquier valor que sea un
  /// JSON `{...}` se decodifica y sus llaves se suben al nivel principal, para
  /// que `tipo` e `idEvento` se encuentren estén donde estén.
  static Map<String, dynamic> _normalizarData(Map<String, dynamic> original) {
    final plano = <String, dynamic>{};

    void volcar(Map<dynamic, dynamic> m, int profundidad) {
      m.forEach((k, v) {
        final clave = k.toString();

        if (v is Map) {
          if (profundidad < 3) volcar(v, profundidad + 1);
          return;
        }

        if (v is String) {
          final texto = v.trim();
          if (texto.startsWith('{') && profundidad < 3) {
            try {
              final decoded = json.decode(texto);
              if (decoded is Map) {
                volcar(decoded, profundidad + 1);
                return;
              }
            } catch (_) {
              // No era JSON: se guarda tal cual.
            }
          }
        }

        // El nivel más externo gana: no se sobreescribe lo ya puesto.
        plano.putIfAbsent(clave, () => v);
      });
    }

    volcar(original, 0);
    return plano;
  }

  /// Módulo al que apunta la notificación.
  ///
  /// Contrato del backend (2026-08-06):
  ///
  ///   Eventos / cumpleaños / sorteos — `EstrategiaEventoBase.mensajePara`:
  ///     { tipo: EVENTO|NOTIFICACION|CUMPLEANOS|SORTEO,
  ///       pantalla: eventos|cumpleanos|sorteos,
  ///       idCabecera: "15", click_action: FLUTTER_NOTIFICATION_CLICK }
  ///
  ///   Mensajes — `EnvioMensajeService`:
  ///     { tipo: MENSAJE, pantalla: mensajes, idMensaje: "482", ... }
  ///
  /// `pantalla` ya viene resuelta por el back, así que manda sobre `tipo`. Se
  /// mantiene `tipo` como respaldo, y por último se deduce por la llave del id.
  static String _tipoDe(Map<String, dynamic> data) {
    String limpiar(dynamic v) => (v ?? '').toString().trim().toLowerCase();

    // 1) `pantalla`: el backend ya hizo el mapeo.
    final pantalla = limpiar(data['pantalla'] ?? data['screen']);
    final porPantalla = _porNombre(pantalla);
    if (porPantalla.isNotEmpty) return porPantalla;

    // 2) `tipo` (tipoevento de la cabecera) u otros alias.
    final tipo = limpiar(data['tipo'] ??
        data['modulo'] ??
        data['origen'] ??
        data['type'] ??
        data['categoria'] ??
        data['seccion']);
    final porTipo = _porNombre(tipo);
    if (porTipo.isNotEmpty) return porTipo;

    // 3) Sin nada usable: se deduce por el id que venga.
    if (_buscar(data, const ['idCumpleanios', 'id_cumpleanios']) != null) {
      return 'cumpleanios';
    }
    if (_buscar(data, const ['idMensaje', 'id_mensaje']) != null) {
      return 'nutrisoft';
    }
    if (_buscar(data, const ['idSorteo', 'id_sorteo']) != null) return 'sorteo';
    if (_buscar(data, const ['idEvento', 'id_evento']) != null) return 'evento';

    return '';
  }

  /// Traduce un nombre del backend al módulo interno.
  ///
  /// Cubre `pantalla` (`eventos`, `cumpleanos`, `sorteos`, `mensajes`) y `tipo`
  /// (`EVENTO`, `NOTIFICACION`, `CUMPLEANOS`, `SORTEO`, `MENSAJE`). Ojo:
  /// `cumpleanos` viene sin "i" ni "ñ", por eso se busca por "cumplea".
  static String _porNombre(String valor) {
    if (valor.isEmpty) return '';

    if (valor.contains('cumplea')) return 'cumpleanios';
    if (valor.contains('sorteo')) return 'sorteo';
    if (valor.contains('mensaje') || valor.contains('nutrisoft')) {
      return 'nutrisoft';
    }
    if (valor.contains('calendario')) return 'calendario';
    // `NOTIFICACION` también son eventos: comparten la tabla de cabeceras.
    if (valor.contains('evento') || valor.contains('notificacion')) {
      return 'evento';
    }

    return '';
  }

  /// Primer valor no vacío de [claves], comparando sin distinguir mayúsculas ni
  /// guiones bajos (FCM y el back no siempre coinciden en el estilo).
  static dynamic _buscar(Map<String, dynamic> data, List<String> claves) {
    String limpiar(String s) => s.toLowerCase().replaceAll('_', '');

    for (final clave in claves) {
      final objetivo = limpiar(clave);
      for (final entrada in data.entries) {
        if (limpiar(entrada.key) != objetivo) continue;
        final v = entrada.value;
        if (v == null) continue;
        if (v is String && v.trim().isEmpty) continue;
        return v;
      }
    }
    return null;
  }

  /// Id del contenido dentro del módulo.
  ///
  /// Eventos, cumpleaños y sorteos comparten la tabla de cabeceras, y hoy el
  /// push manda el id en `idCabecera`. Los mensajes traen `idMensaje`.
  ///
  /// El id propio del módulo (`idEvento`, `idCumpleanios`, `idSorteo`) va
  /// PRIMERO y `idCabecera` queda de respaldo: `idCabecera` es una secuencia
  /// distinta que los listados no devuelven, así que cuando el push traiga los
  /// dos hay que quedarse con el que sí existe en la lista.
  static int _idDe(Map<String, dynamic> data, String tipo) {
    switch (tipo) {
      case 'cumpleanios':
        return _aInt(_buscar(data, const [
          'idCumpleanios',
          'id_cumpleanios',
          'idCabecera',
          'id_cabecera',
          'idEvento',
          'id_evento',
          'id',
        ]));
      case 'sorteo':
        return _aInt(_buscar(data, const [
          'idSorteo',
          'id_sorteo',
          'idCabecera',
          'id_cabecera',
          'id',
        ]));
      case 'nutrisoft':
        return _aInt(_buscar(data, const [
          'idMensaje',
          'id_mensaje',
          'idNutrisoft',
          'idCabecera',
          'id',
        ]));
      default:
        return _aInt(_buscar(data, const [
          'idEvento',
          'id_evento',
          'idCabecera',
          'id_cabecera',
          'id',
        ]));
    }
  }

  /// Abre la pantalla que corresponde a la notificación tocada.
  ///
  /// Si todavía no hay navegador o no hay sesión iniciada, la guarda como
  /// pendiente y se resuelve en [procesarPendiente] (lo llama `MenuScreen`).
  Future<void> abrirDesdeNotificacion(Map<String, dynamic> crudo) async {
    final data = _normalizarData(crudo);

    debugPrint('════════ PUSH TAP ════════');
    debugPrint('PUSH TAP: data cruda      = $crudo');
    debugPrint('PUSH TAP: data aplanada   = $data');
    debugPrint('PUSH TAP: llaves          = ${data.keys.toList()}');

    final tipo = _tipoDe(data);
    final id = _idDe(data, tipo);

    debugPrint('PUSH TAP: tipo="$tipo"  id=$id');

    if (tipo.isEmpty) {
      debugPrint('PUSH TAP: ❌ el push no trae "pantalla" ni "tipo" ni un id '
          'reconocible. Se espera pantalla=eventos|cumpleanos|sorteos|mensajes '
          'con idCabecera, o pantalla=mensajes con idMensaje.');
      return;
    }

    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('PUSH TAP: navegador aún no listo, queda pendiente');
      _pendiente = data;
      return;
    }

    final usuario = context.read<AuthService>().currentUser;
    if (usuario == null) {
      debugPrint('PUSH TAP: sin sesión, queda pendiente hasta el login');
      _pendiente = data;
      return;
    }

    // El calendario no tiene detalle por id: se abre la agenda.
    if (tipo == 'calendario') {
      await navigatorKey.currentState
          ?.pushNamed('/calendario_eventos');
      return;
    }

    // Estrategia de búsqueda, en tres pasos, de menos a más invasivo:
    //
    //   1. buscar en lo que ya está cargado;
    //   2. recargar el listado desde el WS y reintentar (la notificación puede
    //      llegar antes de que el registro aparezca);
    //   3. abrir la pestaña del módulo, dejar que termine de actualizarse y
    //      reintentar; si aparece, el detalle se abre ENCIMA del listado, así
    //      que al cerrarlo el usuario queda en la lista correcta.
    //
    // Si después de eso sigue sin aparecer, queda abierta la pestaña del
    // módulo, que es lo más cerca del contenido que se puede llegar.
    Future<T?> localizar<T>(
      String ruta,
      Future<void> Function() recargar,
      T? Function() buscar,
    ) async {
      var encontrado = buscar();
      if (encontrado != null) return encontrado;

      debugPrint('PUSH TAP: id=$id no apareció; se recarga el listado');
      await Future.delayed(const Duration(milliseconds: 1200));
      await recargar();
      encontrado = buscar();
      if (encontrado != null) return encontrado;

      // Paso 3: se abre la pestaña sin await (pushNamed no resuelve hasta que
      // se cierre la ruta) y se le da tiempo a que cargue.
      debugPrint('PUSH TAP: se abre $ruta y se espera a que se actualice');
      navigatorKey.currentState?.pushNamed(ruta);
      await Future.delayed(const Duration(milliseconds: 1800));
      await recargar();
      await Future.delayed(const Duration(milliseconds: 400));

      encontrado = buscar();
      if (encontrado != null) {
        debugPrint('PUSH TAP: apareció tras abrir $ruta, se abre el detalle');
      }
      return encontrado;
    }

    try {
      switch (tipo) {
        case 'evento':
          final servicio = context.read<EventoService>();
          await servicio.obtenerEventos(idUsuario: usuario.id);

          final Evento? evento = await localizar<Evento>(
            '/eventos_page',
            () => servicio.obtenerEventos(idUsuario: usuario.id),
            () => servicio.eventos.cast<Evento?>().firstWhere(
                (e) => e?.idEvento == id || e?.idCabecera == id,
                orElse: () => null),
          );

          if (evento != null) {
            final estabaPendiente = evento.estado == 0;

            await navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => DetalleEventoScreen(evento: evento),
              ),
            );

            // Al volver se marca visto, igual que al abrirlo desde el listado;
            // si no, el badge quedaría contándolo como pendiente.
            if (estabaPendiente) {
              await servicio.marcarEventoComoVisto(
                idUsuario: usuario.id,
                idEvento: evento.idEvento,
              );
              await servicio.obtenerEventos(idUsuario: usuario.id);
            }
          } else {
            debugPrint('PUSH TAP: ⚠️ evento id=$id NO está en la lista ni tras '
                'abrir la pestaña. ids disponibles (idEvento/idCabecera) = '
                '${servicio.eventos.map((e) => "${e.idEvento}/${e.idCabecera}").toList()}');
            debugPrint('PUSH TAP: el push manda idCabecera, que es otra '
                'secuencia distinta de idEvento y que ObtenerEventos no '
                'devuelve. Queda abierto el listado.');
          }
          break;

        case 'cumpleanios':
          final servicio = context.read<CumpleaniosService>();
          await servicio.obtenerCumpleanios(idUsuario: usuario.id);

          final Cumpleanios? cumple = await localizar<Cumpleanios>(
            '/cumpleanios',
            () => servicio.obtenerCumpleanios(idUsuario: usuario.id),
            () => servicio.cumpleanios.cast<Cumpleanios?>().firstWhere(
                (c) => c?.idCumpleanios == id || c?.idCabecera == id,
                orElse: () => null),
          );

          if (cumple != null) {
            final estabaPendiente = cumple.estado == 0;

            await navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => DetalleCumpleaniosScreen(cumple: cumple),
              ),
            );

            if (estabaPendiente) {
              await servicio.marcarCumpleaniosComoVisto(
                idUsuario: usuario.id,
                idCumpleanios: cumple.idCumpleanios,
              );
              await servicio.obtenerCumpleanios(idUsuario: usuario.id);
            }
          } else {
            debugPrint('PUSH TAP: ⚠️ cumpleaños id=$id NO está en la lista ni '
                'tras abrir la pestaña. ids (idCumpleanios/idCabecera) = '
                '${servicio.cumpleanios.map((c) => "${c.idCumpleanios}/${c.idCabecera}").toList()}');
          }
          break;

        case 'nutrisoft':
          final servicio = context.read<NutrisoftService>();
          await servicio.obtenerNutrisoft(idUsuario: usuario.id);

          final Nutrisoft? item = await localizar<Nutrisoft>(
            '/nutrisoft',
            () => servicio.obtenerNutrisoft(idUsuario: usuario.id),
            () => servicio.items
                .cast<Nutrisoft?>()
                .firstWhere((n) => n?.idMensaje == id, orElse: () => null),
          );

          if (item != null) {
            final estabaPendiente = item.pendiente;

            await navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => DetalleNutrisoftScreen(item: item),
              ),
            );

            if (estabaPendiente) {
              await servicio.marcarComoVisto(
                idUsuario: usuario.id,
                idMensaje: item.idMensaje,
              );
              await servicio.obtenerNutrisoft(idUsuario: usuario.id);
            }
          } else {
            debugPrint('PUSH TAP: ⚠️ mensaje id=$id NO está en la lista ni tras '
                'abrir la pestaña. ids disponibles = '
                '${servicio.items.map((n) => n.idMensaje).toList()}');
          }
          break;

        case 'sorteo':
          final servicio = context.read<SorteoService>();
          await servicio.obtenerSorteos(idUsuario: usuario.id);

          final Sorteo? sorteo = await localizar<Sorteo>(
            '/sorteos',
            () => servicio.obtenerSorteos(idUsuario: usuario.id),
            () => servicio.sorteos.cast<Sorteo?>().firstWhere(
                (s) => s?.id == id || s?.idCabecera == id,
                orElse: () => null),
          );

          if (sorteo != null) {
            await navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => DetalleSorteoScreen(sorteo: sorteo),
              ),
            );
          } else {
            debugPrint('PUSH TAP: ⚠️ sorteo id=$id NO está en la lista ni tras '
                'abrir la pestaña. ids (id/idCabecera) = '
                '${servicio.sorteos.map((s) => "${s.id}/${s.idCabecera}").toList()}');
          }
          break;
      }
    } catch (e) {
      debugPrint('PUSH TAP: error al abrir el contenido: $e');
    }
  }

  /// Abre la notificación que quedó pendiente, si hay alguna.
  ///
  /// `MenuScreen` la llama al montarse: cubre el arranque en frío desde una
  /// notificación y el caso de haberla tocado sin sesión iniciada.
  Future<void> procesarPendiente() async {
    final data = _pendiente;
    if (data == null) return;
    _pendiente = null;
    debugPrint('PUSH: abriendo notificación pendiente $data');
    await abrirDesdeNotificacion(data);
  }

  Future<void> stop() async {
    await _listener?.cancel();
    _listener = null;
  }
}
