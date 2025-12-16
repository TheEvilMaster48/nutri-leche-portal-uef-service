import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
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

      setState(() {
        _checkingSession = false;
      });
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
            // Fondo blanco
            Container(
              color: Colors.white,
            ),
            
            // Fondo azul con curva ondulada sutil
            ClipPath(
              clipper: WaveClipper(),
              child: Container(
                height: MediaQuery.of(context).size.height,
                decoration: const BoxDecoration(
                  color: Color(0xFF0052A3),
                ),
              ),
            ),

            // Contenido
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),

                      // Logo desde assets (EN ZONA BLANCA)
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

                      // Texto Portal de Empleados (EN ZONA BLANCA)
                      const Text(
                        'PORTAL DE EMPLEADOS',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0052A3),
                          letterSpacing: 1.0,
                        ),
                      ),

                      const SizedBox(height: 80),

                      // Título Iniciar Sesión (EN ZONA AZUL)
                      const Text(
                        'Iniciar Sesión',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Contenedor blanco con formulario
                      Container(
                        constraints: const BoxConstraints(maxWidth: 380),
                        padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            // Campo Usuario
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8E8E8),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: TextField(
                                controller: _usernameController,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF333333),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Usuario',
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF888888),
                                    fontSize: 15,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.person_outline,
                                    color: Color(0xFF888888),
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
                                    borderSide: const BorderSide(
                                      color: Color(0xFF0052A3),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),

                            // Campo Contraseña
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8E8E8),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF333333),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Contraseña',
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF888888),
                                    fontSize: 15,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.lock_outline,
                                    color: Color(0xFF888888),
                                    size: 22,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: const Color(0xFF888888),
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
                                    borderSide: const BorderSide(
                                      color: Color(0xFF0052A3),
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
                                    activeColor: const Color(0xFF0052A3),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    side: const BorderSide(
                                      color: Color(0xFF999999),
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Recordar contraseña',
                                  style: TextStyle(
                                    color: Color(0xFF333333),
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
                                  final username = _usernameController.text.trim();
                                  final password = _passwordController.text.trim();

                                  if (username.isEmpty || password.isEmpty) {
                                    _mostrarMensaje(
                                      'Por favor, ingrese su usuario y contraseña.',
                                    );
                                    return;
                                  }

                                  final authService = context.read<AuthService>();

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("🔄 Iniciando sesión..."),
                                      backgroundColor: Colors.blueAccent,
                                      duration: Duration(seconds: 2),
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
                                      const SnackBar(
                                        content: Text("✅ Sesión iniciada"),
                                        backgroundColor: Colors.green,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );

                                    String? fcmToken;

                                    try {
                                      final messaging = FirebaseMessaging.instance;

                                      if (defaultTargetPlatform ==
                                          TargetPlatform.iOS) {
                                        final apnsToken =
                                            await messaging.getAPNSToken();
                                        debugPrint('🍏 APNS TOKEN = $apnsToken');

                                        if (apnsToken == null) {
                                          debugPrint('⏳ APNs token no listo.');
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
                                  backgroundColor: const Color(0xFF5BA3D5),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Ingresar',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
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

                      const SizedBox(height: 24),

                      // Link Olvidé mi contraseña
                      TextButton(
                        onPressed: () {
                          _mostrarMensaje(
                            "Por favor, contacte al administrador para recuperar su contraseña.",
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text(
                          'Olvidé mi contraseña',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),
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
    setState(() {
      _mensajeError = mensaje;
    });
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _mensajeError = '');
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _timer?.cancel();
    super.dispose();
  }
}

// Custom clipper para crear la curva ondulada MÁS SUTIL
class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    
    // Comenzar desde la esquina superior izquierda
    path.lineTo(0, 0);
    
    // Bajar hasta donde empieza la curva (más abajo)
    path.lineTo(0, 240);
    
    // Curva ondulada SUTIL en la parte superior
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
    
    // Continuar por el lado derecho
    path.lineTo(size.width, size.height);
    
    // Parte inferior
    path.lineTo(0, size.height);
    
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}