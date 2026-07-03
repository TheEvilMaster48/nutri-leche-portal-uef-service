import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';
import '../base/Base.dart'; // <-- AJUSTA la ruta según tu proyecto

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

  final _usuarioRecController = TextEditingController();
  final _correoRecController = TextEditingController();


  bool _obscurePassword = true;
  bool _rememberPassword = false;
  String _mensajeError = '';
  Timer? _timer;

  bool _checkingSession = true;

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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            // Fondo
            Container(color: base.COLOR_BLANCO),

            // Fondo azul con curva
            ClipPath(
              clipper: WaveClipper(),
              child: Container(
                height: MediaQuery.of(context).size.height,
                decoration: BoxDecoration(color: base.COLOR_AZUL_CORP),
              ),
            ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),

                      // Logo
                      Container(
                        width: 200,
                        height: 110,
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('assets/icono/nutri.png'),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Texto Portal de Empleados
                      Text(
                        'PORTAL DE EMPLEADOS',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: base.COLOR_AZUL_CORP,
                          letterSpacing: 1.0,
                        ),
                      ),

                      const SizedBox(height: 60),

                      // Título
                      Text(
                        'Iniciar Sesión',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: base.COLOR_BLANCO,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Contenedor blanco con formulario
                      Container(
                        constraints: const BoxConstraints(maxWidth: 380),
                        padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
                        decoration: BoxDecoration(
                          color: base.COLOR_BLANCO,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            // Usuario
                            Container(
                              decoration: BoxDecoration(
                                color: base.COLOR_BLANCO,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: base.COLOR_GRIS.withOpacity(0.35),
                                ),
                              ),
                              child: TextField(
                                controller: _usernameController,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: base.COLOR_NEGRO_OSCURO,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Usuario',
                                  hintStyle: TextStyle(
                                    color: base.COLOR_GRIS,
                                    fontSize: 15,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.person_outline,
                                    color: base.COLOR_GRIS,
                                    size: 22,
                                  ),
                                  filled: true,
                                  fillColor: Colors.transparent,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: base.COLOR_AZUL_CORP,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),

                            // Contraseña
                            Container(
                              decoration: BoxDecoration(
                                color: base.COLOR_BLANCO,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: base.COLOR_GRIS.withOpacity(0.35),
                                ),
                              ),
                              child: TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: base.COLOR_NEGRO_OSCURO,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Contraseña',
                                  hintStyle: TextStyle(
                                    color: base.COLOR_GRIS,
                                    fontSize: 15,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.lock_outline,
                                    color: base.COLOR_GRIS,
                                    size: 22,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: base.COLOR_GRIS,
                                      size: 22,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  filled: true,
                                  fillColor: Colors.transparent,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: base.COLOR_AZUL_CORP,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Checkbox Recordar contraseña
                            Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Checkbox(
                                    value: _rememberPassword,
                                    onChanged: (value) {
                                      setState(() {
                                        _rememberPassword = value ?? false;
                                      });
                                    },
                                    activeColor: base.COLOR_AZUL_CORP,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    side: BorderSide(
                                      color: base.COLOR_GRIS.withOpacity(0.7),
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Recordar contraseña',
                                  style: TextStyle(
                                    color: base.COLOR_NEGRO_OSCURO,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Botón Ingresar
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () async {
                                  final username =
                                      _usernameController.text.trim();
                                  final password =
                                      _passwordController.text.trim();

                                  if (username.isEmpty || password.isEmpty) {
                                    _mostrarMensaje(
                                      'Por favor, ingrese su usuario y contraseña.',
                                    );
                                    return;
                                  }

                                  final authService =
                                      context.read<AuthService>();

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        "🔄 Iniciando sesión...",
                                      ),
                                      backgroundColor: base.COLOR_AZUL_CLARO,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );

                                  final success = await authService.login(
                                    username,
                                    password,
                                  );

                                  if (!mounted) return;

                                  if (success) {
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    if (_rememberPassword) {
                                      await prefs.setString(
                                        'saved_username',
                                        username,
                                      );
                                      await prefs.setString(
                                        'saved_password',
                                        password,
                                      );
                                      await prefs.setBool(
                                        'remember_password',
                                        true,
                                      );
                                    } else {
                                      await prefs.remove('saved_username');
                                      await prefs.remove('saved_password');
                                      await prefs.remove('remember_password');
                                    }

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                          "✅ Sesión iniciada",
                                        ),
                                        backgroundColor: base.COLOR_AZUL_VERDE,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );

                                    String? fcmToken;

                                    try {
                                      final messaging =
                                          FirebaseMessaging.instance;

                                      if (defaultTargetPlatform ==
                                          TargetPlatform.iOS) {
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
                                        for (int intento = 1;
                                            intento <= 5;
                                            intento++) {
                                          apnsToken =
                                              await messaging.getAPNSToken();
                                          if (apnsToken != null) break;
                                          debugPrint(
                                            '⏳ APNs token no listo (intento $intento/5)...',
                                          );
                                          await Future.delayed(
                                            const Duration(seconds: 1),
                                          );
                                        }
                                        debugPrint(
                                          '🍏 APNS TOKEN = $apnsToken',
                                        );

                                        if (apnsToken == null) {
                                          debugPrint(
                                            '⚠️ APNs token no disponible tras 5 intentos.',
                                          );
                                        } else {
                                          fcmToken = await messaging.getToken();
                                          debugPrint(
                                            '📲 FCM TOKEN (iOS) = $fcmToken',
                                          );
                                        }
                                      } else {
                                        fcmToken = await messaging.getToken();
                                        debugPrint('📲 FCM TOKEN = $fcmToken');
                                      }
                                    } catch (e) {
                                      debugPrint(
                                        '⚠️ Error obteniendo FCM token: $e',
                                      );
                                    }

                                    if (fcmToken != null &&
                                        authService.currentUser != null) {
                                      await authService.EnviarToken(
                                        fcmToken,
                                        authService.currentUser!.id,
                                      );
                                    }

                                    Navigator.pushReplacementNamed(
                                      context,
                                      '/menu',
                                    );
                                  } else {
                                    _mostrarMensaje(
                                      'Usuario o contraseña incorrectos.',
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: base.COLOR_AZUL_CORP,
                                  foregroundColor: base.COLOR_BLANCO,
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  'Ingresar',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: base.COLOR_BLANCO,
                                  ),
                                ),
                              ),
                            ),

                            // Mensaje de error
                            AnimatedOpacity(
                              opacity: _mensajeError.isNotEmpty ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 400),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  _mensajeError,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 2),

                      // Botón Recuperar Contraseña (NUEVO)
                      TextButton(
                        onPressed: _mostrarDialogRecuperarClave,
                        style: TextButton.styleFrom(
                          foregroundColor: base.COLOR_BLANCO,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: Text(
                          'Recuperar contraseña',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: base.COLOR_BLANCO,
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarMensaje(String mensaje) {
    setState(() => _mensajeError = mensaje);

    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _mensajeError = '');
    });
  }

  // =========================
  //  DIALOG RECUPERAR CLAVE
  // =========================
  Future<void> _mostrarDialogRecuperarClave() async {
    final parentContext = context;

    // Limpia campos cada vez que abras el dialog (opcional)
    _usuarioRecController.clear();
    _correoRecController.clear();

    bool enviando = false;

    await showDialog(
      context: parentContext,
      barrierDismissible: !enviando,
      builder: (dialogContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (dialogContext, setStateDialog) {
              return AlertDialog(
                backgroundColor: base.COLOR_BLANCO,
                title: Text(
                  'Recuperar contraseña',
                  style: TextStyle(color: base.COLOR_AZUL_CORP),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _usuarioRecController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Usuario',
                          labelStyle: TextStyle(color: base.COLOR_AZUL_CORP),
                          prefixIcon: Icon(Icons.person, color: base.COLOR_AZUL_CORP),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: base.COLOR_AZUL_CORP),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _correoRecController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Correo electrónico',
                          labelStyle: TextStyle(color: base.COLOR_AZUL_CORP),
                          prefixIcon: Icon(Icons.email_outlined, color: base.COLOR_AZUL_CORP),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: base.COLOR_AZUL_CORP),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: enviando
                        ? null
                        : () {
                      FocusScope.of(dialogContext).unfocus();
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: base.COLOR_AZUL_CORP,
                      foregroundColor: base.COLOR_BLANCO,
                    ),
                    onPressed: enviando
                        ? null
                        : () async {
                      final usuario = _usuarioRecController.text.trim();
                      final correo = _correoRecController.text.trim();

                      if (usuario.isEmpty || correo.isEmpty) {
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          const SnackBar(
                            content: Text('Ingrese su usuario y correo.'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return;
                      }

                      setStateDialog(() => enviando = true);

                      final ok = await _enviarRecuperacionClave(
                        usuario: usuario,
                        correo: correo,
                      );

                      if (!mounted) return;

                      setStateDialog(() => enviando = false);

                      if (ok) {
                        FocusScope.of(dialogContext).unfocus();
                        Navigator.of(dialogContext).pop();

                        // Solo el mensaje que pediste
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          SnackBar(
                            content: const Text('Se han enviado  las instrucciones a su correo.'),
                            backgroundColor: base.COLOR_AZUL_VERDE,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          const SnackBar(
                            content: Text('⚠️ No se pudo enviar la solicitud.'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    },
                    child: enviando
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : Text('Enviar', style: TextStyle(color: base.COLOR_BLANCO)),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }



  Future<bool> _enviarRecuperacionClave({
    required String usuario,
    required String correo,
  }) async {
    const url =
        'https://servicioslsa.nutri.com.ec/nutrisoft/rest/service/api/request_password_reset';

    try {
      final resp = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'usuario': usuario, 'correo': correo}),
      );

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return true;
      }

      debugPrint(
        '❌ recuperarClave status=${resp.statusCode} body=${resp.body}',
      );
      return false;
    } catch (e) {
      debugPrint('⚠️ Error llamar recuperarClave: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();

    _usuarioRecController.dispose();
    _correoRecController.dispose();

    _timer?.cancel();
    super.dispose();
  }

}

// Curva ondulada
class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();

    path.lineTo(0, 0);
    path.lineTo(0, 240);

    var firstControlPoint = Offset(size.width * 0.25, 220);
    var firstEndPoint = Offset(size.width * 0.5, 240);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    var secondControlPoint = Offset(size.width * 0.75, 260);
    var secondEndPoint = Offset(size.width, 240);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
