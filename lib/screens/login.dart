import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';
import '../base/base.dart';
import '../widget/logo_nutri.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Colores corporativos (Base.dart)
  // Ajusta el nombre de la clase según tu Base.dart:
  // Ej: final base = Base(); o BaseColors(); etc.
  final base = Base();

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  final _cedulaRecController = TextEditingController();
  final _cedulaRecUsuarioController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberPassword = false;
  String _mensajeError = '';
  Timer? _timer;

  bool _checkingSession = true;

  /// Hay un login en curso: bloquea el formulario y muestra el progreso en
  /// el botón.
  bool _cargando = false;

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      final auth = context.read<AuthService>();
      final prefs = await SharedPreferences.getInstance();

      await auth.cargarUsuarioGuardado();

      if (!mounted) return;

      if (auth.currentUser != null) {
        Navigator.pushReplacementNamed(context, '/menu');
        return;
      }

      final savedUser = prefs.getString('saved_username');
      final savedPass = prefs.getString('saved_password');
      final remember = prefs.getBool('remember_password') ?? false;

      if (savedUser != null && remember) {
        _usernameController.text = savedUser;
        _passwordController.text = savedPass ?? '';
        _rememberPassword = true;
      }

      setState(() => _checkingSession = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      // Mientras se revisa si hay sesión guardada: el mismo azul de la onda
      // con la marca, para que el paso al login o al menú no sea un destello
      // blanco con un spinner suelto.
      return Scaffold(
        backgroundColor: base.COLOR_AZUL_CORP,
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LogoNutri.claro(alto: 64),
              SizedBox(height: 28),
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      // Toda la pantalla en el azul corporativo, sin onda: el logo y el
      // formulario quedan centrados como un solo bloque.
      backgroundColor: base.COLOR_AZUL_CORP,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            SafeArea(
              child: LayoutBuilder(
                builder:
                    (context, constraints) => SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            children: [
                              const Spacer(),
                              const SizedBox(height: 24),

                              // Sobre el azul corresponde el arte blanco.
                              const LogoNutri.claro(alto: 100),
                              const SizedBox(height: 12),
                              Text(
                                'NUTRI NOTIFICACIONES',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withOpacity(0.8),
                                  letterSpacing: 2.2,
                                ),
                              ),

                              const SizedBox(height: 40),

                              // Tarjeta del formulario, en blanco puro y con sombra.
                              Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 400,
                                ),
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  28,
                                  24,
                                  24,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.18),
                                      blurRadius: 24,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: AutofillGroup(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Iniciar sesión',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                          color: base.COLOR_AZUL_CORP,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Ingresa con tu usuario de Nutrisoft',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.black54,
                                        ),
                                      ),

                                      const SizedBox(height: 24),

                                      _campo(
                                        controller: _usernameController,
                                        hint: 'Usuario',
                                        icono: Icons.person_outline,
                                        accion: TextInputAction.next,
                                        autofill: const [
                                          AutofillHints.username,
                                        ],
                                      ),

                                      const SizedBox(height: 14),

                                      _campo(
                                        controller: _passwordController,
                                        hint: 'Contraseña',
                                        icono: Icons.lock_outline,
                                        oculto: _obscurePassword,
                                        accion: TextInputAction.done,
                                        autofill: const [
                                          AutofillHints.password,
                                        ],
                                        alEnviar: (_) => _iniciarSesion(),
                                        sufijo: IconButton(
                                          tooltip:
                                              _obscurePassword
                                                  ? 'Mostrar contraseña'
                                                  : 'Ocultar contraseña',
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            color: Colors.black45,
                                            size: 22,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                        ),
                                      ),

                                      const SizedBox(height: 6),

                                      // Toda la fila responde al toque, no solo el
                                      // cuadrito de 20 px.
                                      InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap:
                                            _cargando
                                                ? null
                                                : () => setState(
                                                  () =>
                                                      _rememberPassword =
                                                          !_rememberPassword,
                                                ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: Checkbox(
                                                  value: _rememberPassword,
                                                  onChanged:
                                                      _cargando
                                                          ? null
                                                          : (value) => setState(
                                                            () =>
                                                                _rememberPassword =
                                                                    value ??
                                                                    false,
                                                          ),
                                                  activeColor:
                                                      base.COLOR_AZUL_CORP,
                                                  materialTapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                  side: const BorderSide(
                                                    color: Colors.black38,
                                                    width: 1.5,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              const Text(
                                                'Recordar contraseña',
                                                style: TextStyle(
                                                  color: Colors.black87,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Mensaje de error: solo ocupa lugar cuando hay
                                      // algo que decir.
                                      AnimatedSize(
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                        child:
                                            _mensajeError.isEmpty
                                                ? const SizedBox(
                                                  width: double.infinity,
                                                )
                                                : Container(
                                                  margin: const EdgeInsets.only(
                                                    top: 4,
                                                    bottom: 4,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 10,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red
                                                        .withOpacity(0.08),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.error_outline,
                                                        color: Colors.redAccent,
                                                        size: 20,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          _mensajeError,
                                                          style:
                                                              const TextStyle(
                                                                color: Color(
                                                                  0xFFC62828,
                                                                ),
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                      ),

                                      const SizedBox(height: 14),

                                      // Botón Ingresar. Mientras se valida muestra el
                                      // progreso adentro y no admite otro toque: antes
                                      // un doble toque disparaba dos logins.
                                      SizedBox(
                                        height: 52,
                                        child: ElevatedButton(
                                          onPressed:
                                              _cargando ? null : _iniciarSesion,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                base.COLOR_AZUL_CORP,
                                            foregroundColor: Colors.white,
                                            disabledBackgroundColor: base
                                                .COLOR_AZUL_CORP
                                                .withOpacity(0.7),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child:
                                              _cargando
                                                  ? const SizedBox(
                                                    width: 22,
                                                    height: 22,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2.5,
                                                          color: Colors.white,
                                                        ),
                                                  )
                                                  : const Text(
                                                    'Ingresar',
                                                    style: TextStyle(
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Botones Recuperar Usuario / Recuperar Contraseña
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _enlace(
                                    'Recuperar usuario',
                                    _mostrarDialogRecuperarUsuario,
                                  ),
                                  Text(
                                    '·',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                  ),
                                  _enlace(
                                    'Recuperar contraseña',
                                    _mostrarDialogRecuperarClave,
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),
                              const Spacer(),
                            ],
                          ),
                        ),
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Campo del formulario: fondo gris muy claro, sin borde en reposo y azul
  /// al enfocar.
  Widget _campo({
    required TextEditingController controller,
    required String hint,
    required IconData icono,
    required TextInputAction accion,
    required List<String> autofill,
    bool oculto = false,
    Widget? sufijo,
    ValueChanged<String>? alEnviar,
  }) {
    final borde = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
    );

    return TextField(
      controller: controller,
      obscureText: oculto,
      enabled: !_cargando,
      textInputAction: accion,
      autofillHints: autofill,
      autocorrect: false,
      enableSuggestions: !oculto,
      onSubmitted: alEnviar,
      style: const TextStyle(fontSize: 15, color: Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black38, fontSize: 15),
        prefixIcon: Icon(icono, color: Colors.black45, size: 22),
        suffixIcon: sufijo,
        filled: true,
        fillColor: const Color(0xFFF4F6FA),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: borde,
        enabledBorder: borde,
        disabledBorder: borde,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: base.COLOR_AZUL_CORP, width: 1.6),
        ),
      ),
    );
  }

  Widget _enlace(String texto, VoidCallback alTocar) {
    return TextButton(
      onPressed: _cargando ? null : alTocar,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Future<void> _iniciarSesion() async {
    if (_cargando) return;
    FocusScope.of(context).unfocus();

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _mostrarMensaje('Por favor, ingrese su usuario y contraseña.');
      return;
    }

    final authService = context.read<AuthService>();

    setState(() {
      _cargando = true;
      _mensajeError = '';
    });

    try {
      final success = await authService.login(username, password);

      if (!mounted) return;

      if (!success) {
        _mostrarMensaje(
          authService.motivoRechazo ?? 'Usuario o contraseña incorrectos.',
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      if (_rememberPassword) {
        await prefs.setString('saved_username', username);
        await prefs.setString('saved_password', password);
        await prefs.setBool('remember_password', true);
      } else {
        await prefs.remove('saved_username');
        await prefs.remove('saved_password');
        await prefs.remove('remember_password');
      }

      String? fcmToken;

      try {
        final messaging = FirebaseMessaging.instance;

        if (defaultTargetPlatform == TargetPlatform.iOS) {
          // Asegura el permiso antes de pedir el APNs token.
          await messaging.requestPermission(
            alert: true,
            badge: true,
            sound: true,
          );

          // El APNs token puede tardar unos segundos
          // en estar disponible tras conceder permisos.
          // Reintentamos hasta 5 veces (~5s).
          String? apnsToken;
          for (int intento = 1; intento <= 5; intento++) {
            apnsToken = await messaging.getAPNSToken();
            if (apnsToken != null) break;
            debugPrint('⏳ APNs token no listo (intento $intento/5)...');
            await Future.delayed(const Duration(seconds: 1));
          }
          debugPrint('🍏 APNS TOKEN = $apnsToken');

          if (apnsToken == null) {
            debugPrint('⚠️ APNs token no disponible tras 5 intentos.');
          } else {
            fcmToken = await messaging.getToken();
            debugPrint('📲 FCM TOKEN (iOS) = $fcmToken');
          }
        } else {
          fcmToken = await messaging.getToken();
          debugPrint('📲 FCM TOKEN = $fcmToken');
        }
      } catch (e) {
        debugPrint('⚠️ Error obteniendo FCM token: $e');
      }

      if (fcmToken != null && authService.currentUser != null) {
        await authService.EnviarToken(fcmToken, authService.currentUser!.id);
      }

      if (!mounted) return;

      Navigator.pushReplacementNamed(context, '/menu');
    } catch (e) {
      debugPrint('Error al iniciar sesión: $e');
      if (mounted) {
        _mostrarMensaje('No se pudo iniciar sesión. Revise su conexión.');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarMensaje(String mensaje) {
    setState(() => _mensajeError = mensaje);

    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _mensajeError = '');
    });
  }

  // =========================
  //  RECUPERAR USUARIO / CLAVE
  // =========================
  Future<void> _mostrarDialogRecuperarClave() => _mostrarDialogRecuperacion(
    titulo: 'Recuperar contraseña',
    descripcion:
        'Ingrese su número de cédula. Le enviaremos las instrucciones al '
        'correo registrado.',
    controller: _cedulaRecController,
    endpoint: 'cambiar_contraseña',
    exito:
        (correo) =>
            correo == null
                ? 'Se enviaron las instrucciones a su correo registrado.'
                : 'Se enviaron las instrucciones a su correo '
                    '${_enmascararCorreo(correo)}',
  );

  Future<void> _mostrarDialogRecuperarUsuario() => _mostrarDialogRecuperacion(
    titulo: 'Recuperar usuario',
    descripcion:
        'Ingrese su número de cédula. Le enviaremos su usuario al correo '
        'registrado.',
    controller: _cedulaRecUsuarioController,
    endpoint: 'recuperar_usuario',
    exito:
        (correo) =>
            correo == null
                ? 'Se envió su usuario a su correo registrado.'
                : 'Se envió su usuario al correo ${_enmascararCorreo(correo)}',
  );

  /// Diálogo común de recuperación por cédula.
  ///
  /// Los errores se muestran dentro del diálogo, con el mensaje que devuelve
  /// el servidor («No se ha encontrado el usuario», etc.). Antes salían en un
  /// SnackBar detrás de la capa oscura del diálogo y siempre con el mismo
  /// «No se pudo enviar la solicitud», así que parecía que el botón no hacía
  /// nada.
  Future<void> _mostrarDialogRecuperacion({
    required String titulo,
    required String descripcion,
    required TextEditingController controller,
    required String endpoint,
    required String Function(String? correo) exito,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    controller.clear();

    bool enviando = false;
    String error = '';

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            Future<void> enviar() async {
              final cedula = controller.text.trim();
              if (cedula.isEmpty) {
                setStateDialog(() => error = 'Ingrese su número de cédula.');
                return;
              }

              setStateDialog(() {
                enviando = true;
                error = '';
              });

              final resultado = await _solicitarRecuperacion(
                endpoint: endpoint,
                cedula: cedula,
              );

              if (!dialogContext.mounted) return;

              if (!resultado.correcto) {
                setStateDialog(() {
                  enviando = false;
                  error = resultado.mensaje;
                });
                return;
              }

              Navigator.of(dialogContext).pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(exito(resultado.correo)),
                  backgroundColor: base.COLOR_AZUL_VERDE,
                  duration: const Duration(seconds: 5),
                ),
              );
            }

            return PopScope(
              // Mientras se envía no se cierra ni con atrás ni tocando afuera.
              canPop: !enviando,
              child: AlertDialog(
                scrollable: true,
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Text(
                  titulo,
                  style: TextStyle(
                    color: base.COLOR_AZUL_CORP,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      descripcion,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      enabled: !enviando,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => enviar(),
                      decoration: InputDecoration(
                        labelText: 'Cédula',
                        labelStyle: TextStyle(color: base.COLOR_AZUL_CORP),
                        prefixIcon: Icon(
                          Icons.badge_outlined,
                          color: base.COLOR_AZUL_CORP,
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: base.COLOR_AZUL_CORP),
                        ),
                      ),
                    ),
                    if (error.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              error,
                              style: const TextStyle(
                                color: Color(0xFFC62828),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed:
                        enviando
                            ? null
                            : () => Navigator.of(dialogContext).pop(),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: base.COLOR_AZUL_CORP,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: base.COLOR_AZUL_CORP.withOpacity(
                        0.7,
                      ),
                    ),
                    onPressed: enviando ? null : enviar,
                    child:
                        enviando
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Text('Enviar'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Llama a `appOficial/<endpoint>` con la cédula.
  ///
  /// Respuesta esperada: {"correcto": bool, "mensaje": "...", "correo": "..."}.
  /// Se respeta el `mensaje` del servidor cuando falla, y un `correcto: true`
  /// sin correo sigue siendo un éxito (antes se tomaba como error).
  Future<({bool correcto, String mensaje, String? correo})>
  _solicitarRecuperacion({
    required String endpoint,
    required String cedula,
  }) async {
    const fallaGenerica = 'No se pudo enviar la solicitud. Intente de nuevo.';

    try {
      final resp = await http
          .post(
            Uri.parse('${Base.URL_APPOFICIAL}/$endpoint'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'cedula': cedula}),
          )
          .timeout(const Duration(seconds: 20));

      debugPrint('🔑 $endpoint status=${resp.statusCode} body=${resp.body}');

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        return (correcto: false, mensaje: fallaGenerica, correo: null);
      }

      final data = jsonDecode(utf8.decode(resp.bodyBytes));
      if (data is! Map) {
        return (correcto: false, mensaje: fallaGenerica, correo: null);
      }

      final mensaje = (data['mensaje'] as String?)?.trim() ?? '';
      final correo = (data['correo'] as String?)?.trim();

      if (data['correcto'] != true) {
        return (
          correcto: false,
          mensaje: mensaje.isNotEmpty ? mensaje : fallaGenerica,
          correo: null,
        );
      }

      return (
        correcto: true,
        mensaje: mensaje,
        correo: correo != null && correo.isNotEmpty ? correo : null,
      );
    } on TimeoutException {
      return (
        correcto: false,
        mensaje: 'El servidor no respondió. Revise su conexión.',
        correo: null,
      );
    } catch (e) {
      debugPrint('⚠️ Error en $endpoint: $e');
      return (
        correcto: false,
        mensaje: 'No hay conexión con el servidor. Revise su red.',
        correo: null,
      );
    }
  }

  /// Enmascara un correo: pruebaenvio@gmail.com -> pru*****o@gmail.com
  String _enmascararCorreo(String correo) {
    final at = correo.indexOf('@');
    if (at <= 0) return correo;

    final usuario = correo.substring(0, at);
    final dominio = correo.substring(at); // incluye la @

    if (usuario.length <= 2) {
      return '${usuario[0]}*****$dominio';
    }

    final inicio = usuario.substring(0, 3);
    final fin = usuario.substring(usuario.length - 1);
    return '$inicio*****$fin$dominio';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();

    _cedulaRecController.dispose();
    _cedulaRecUsuarioController.dispose();

    _timer?.cancel();
    super.dispose();
  }
}
