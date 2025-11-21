import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

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
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      image: const DecorationImage(
                        image: AssetImage('assets/icono/nutrileche.png'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  const Text(
                    'Nutri',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ecuador - Portal de Empleados',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 48),

                  Container(
                    constraints: const BoxConstraints(maxWidth: 500),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Iniciar Sesión',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(height: 32),

                        TextField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'Usuario',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock),
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
                        const SizedBox(height: 10),

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
                            const Text(
                              'Recordar contraseña',
                              style: TextStyle(color: Colors.black87),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

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
                                const SnackBar(
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
                                  const SnackBar(
                                    content: Text("✅ Sesión iniciada"),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 2),
                                  ),
                                );

                                Navigator.pushReplacementNamed(
                                    context, '/menu');
                              } else {
                                _mostrarMensaje(
                                    'Usuario o contraseña incorrectos.');
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Iniciar Sesión',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        AnimatedOpacity(
                          opacity: _mensajeError.isNotEmpty ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 400),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              _mensajeError,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        TextButton(
                          onPressed: () {
                            _mostrarMensaje(
                                "Por favor, contacte al administrador para recuperar su contraseña.");
                          },
                          child: const Text(
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
