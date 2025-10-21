import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/usuario.dart';
import '../models/pais.dart';
import '../services/validators/empleado_validator.dart';
import '../services/validators/telefono_validator.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nombreController = TextEditingController();
  final _correoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _cargoController = TextEditingController();
  final _areaController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _paisSeleccionado;
  final List<Pais> _paises = Pais.getPaises();

  @override
  void initState() {
    super.initState();
    _paisSeleccionado = _paises.first.nombre;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    'Crear Cuenta',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Contenedor blanco
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        // Usuario
                        _buildTextField(
                          controller: _usernameController,
                          label: 'Usuario',
                          icon: Icons.person,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'El usuario es requerido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Contraseña
                        _buildTextField(
                          controller: _passwordController,
                          label: 'Contraseña',
                          icon: Icons.lock,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.length < 6) {
                              return 'Debe tener al menos 6 caracteres';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Confirmar contraseña
                        _buildTextField(
                          controller: _confirmPasswordController,
                          label: 'Confirmar Contraseña',
                          icon: Icons.lock_outline,
                          obscureText: _obscureConfirmPassword,
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                          validator: (value) {
                            if (value != _passwordController.text) {
                              return 'Las contraseñas no coinciden';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Nombre completo
                        _buildTextField(
                          controller: _nombreController,
                          label: 'Nombre completo',
                          icon: Icons.badge,
                          validator: (value) =>
                              EmpleadoValidator.validarNombreCompleto(
                                  value ?? ''),
                        ),
                        const SizedBox(height: 16),

                        // Correo
                        _buildTextField(
                          controller: _correoController,
                          label: 'Correo electrónico',
                          icon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) =>
                              EmpleadoValidator.validarCorreo(value ?? ''),
                        ),
                        const SizedBox(height: 16),

                        // País y Teléfono
                        Row(
                          children: [
                            DropdownButton<String>(
                              value: _paisSeleccionado,
                              items: _paises.map((pais) {
                                return DropdownMenuItem<String>(
                                  value: pais.nombre,
                                  child: Text(
                                      '${pais.bandera} ${pais.prefijo} ${pais.nombre}'),
                                );
                              }).toList(),
                              onChanged: (nuevo) {
                                setState(() {
                                  _paisSeleccionado = nuevo!;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _telefonoController,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.phone),
                                  labelText: 'Teléfono',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) {
                                  final pais = _paises.firstWhere(
                                      (p) => p.nombre == _paisSeleccionado);
                                  if (pais.prefijo == '+593' &&
                                      value.startsWith('0')) {
                                    final corregido = value.substring(1);
                                    _telefonoController.text = corregido;
                                    _telefonoController.selection =
                                        TextSelection.fromPosition(
                                      TextPosition(offset: corregido.length),
                                    );
                                  }
                                },
                                validator: (value) {
                                  final pais = _paises.firstWhere(
                                      (p) => p.nombre == _paisSeleccionado);
                                  return TelefonoValidator.validarTelefono(
                                      value ?? '', pais.prefijo);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Cargo
                        _buildTextField(
                          controller: _cargoController,
                          label: 'Cargo o Puesto',
                          icon: Icons.work,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'El cargo es requerido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Área o Planta
                        _buildTextField(
                          controller: _areaController,
                          label: 'Área o Planta',
                          icon: Icons.location_on,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'El área o planta es requerida';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Botón de registro
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                final paisSeleccionado = _paises.firstWhere(
                                    (p) => p.nombre == _paisSeleccionado);

                                // Crear objeto usuario real
                                final nuevoUsuario = Usuario(
                                  id: 0, // el backend asignará el ID real
                                  nombre: _nombreController.text.trim(),
                                  correo: _correoController.text.trim(),
                                  telefono:
                                      '${paisSeleccionado.prefijo} ${_telefonoController.text.trim()}',
                                  cargo: _cargoController.text.trim(),
                                  areaUsuario: _areaController.text.trim(),
                                  modulos: '',
                                  cedula:
                                      '', // temporalmente vacío (el backend o formulario la llenará luego)
                                );

                                final authService = context.read<AuthService>();
                                final success =
                                    await authService.register(
                                    nuevoUsuario);

                                if (!mounted) return;

                                if (success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Registro exitoso. Ahora puede iniciar sesión.'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  Navigator.pushReplacementNamed(
                                      context, '/');
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Error al registrar. Intente nuevamente.'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Registrarse',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Volver a inicio
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            '¿Ya tienes cuenta? Inicia sesión',
                            style: TextStyle(color: Color(0xFF1E3A8A)),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      validator: validator,
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nombreController.dispose();
    _correoController.dispose();
    _telefonoController.dispose();
    _cargoController.dispose();
    _areaController.dispose();
    super.dispose();
  }
}
