import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../firebase_options.dart';
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
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  SizedBox(height: 50),

                  Container(
                    width: 150,
                    height: 150,
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.rectangle,
                      boxShadow: [],
                      image: DecorationImage(
                        image: AssetImage('assets/icono/nutri.png'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  SizedBox(height: 32),

                  Text(
                    'Nutri',
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Ecuador - Portal de Empleados',
                    style: TextStyle(
                      fontSize: 17,
                      color: Colors.black54,
                    ),
                  ),
                  SizedBox(height: 48),

                  Container(
                    constraints: BoxConstraints(maxWidth: 500),
                    padding: EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 30,
                          offset: Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Iniciar Sesión',
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        SizedBox(height: 32),

                        TextField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'Usuario',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),

                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        SizedBox(height: 10),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _rememberPassword,
                              onChanged: (value) {
                                setState(() {
                                  _rememberPassword = value ?? false;
                                });
                              },
                            ),
                            Text(
                              'Recordar contraseña',
                              style: TextStyle(color: Colors.black87),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          height: 56,
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
                                SnackBar(
                                  content: Text("🔄 Iniciando sesión..."),
                                  backgroundColor: Colors.blueAccent,
                                  duration: Duration(seconds: 2),
                                ),
                              );

                              final success =
                                  await authService.login(username, password);

                              if (!mounted) return;

                              if (success) {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                if (_rememberPassword) {
                                  await prefs.setString(
                                      'saved_username', username);
                                  await prefs.setString(
                                      'saved_password', password);
                                  await prefs.setBool(
                                      'remember_password', true);
                                } else {
                                  await prefs.remove('saved_username');
                                  await prefs.remove('saved_password');
                                  await prefs.remove('remember_password');
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("✅ Sesión iniciada"),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 2),
                                  ),
                                );

                                String? fcmToken;

                                try {
                                  final messaging = FirebaseMessaging.instance;

                                  if (defaultTargetPlatform == TargetPlatform.iOS) {
                                    final apnsToken = await messaging.getAPNSToken();
                                    debugPrint('🍏 APNS TOKEN = $apnsToken');

                                    if (apnsToken == null) {
                                      debugPrint('⏳ APNs token no listo.');
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

                                if (fcmToken != null &&
                                    authService.currentUser != null) {
                                  await authService.EnviarToken(
                                      fcmToken, authService.currentUser!.id);
                                }

                                Navigator.pushReplacementNamed(context, '/menu');
                              } else {
                                _mostrarMensaje('Usuario o contraseña incorrectos.');
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF3B82F6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Iniciar Sesión',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 12),

                        AnimatedOpacity(
                          opacity: _mensajeError.isNotEmpty ? 1.0 : 0.0,
                          duration: Duration(milliseconds: 400),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              _mensajeError,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 8),

                        TextButton(
                          onPressed: () {
                            _mostrarMensaje(
                                "Por favor, contacte al administrador para recuperar su contraseña.");
                          },
                          child: Text(
                            '¿Olvidó su contraseña?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarMensaje(String mensaje) {
    setState(() {
      _mensajeError = mensaje;
    });
    _timer?.cancel();
    _timer = Timer(Duration(seconds: 8), () {
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