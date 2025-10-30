import 'package:flutter/material.dart';
import 'package:nutri_leche/screens/cumpleanios_screen.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/celebracion_service.dart';
import '../core/notification_banner.dart';
import '../models/celebracion.dart';

class CelebracionesScreen extends StatefulWidget {
  const CelebracionesScreen({super.key});

  @override
  State<CelebracionesScreen> createState() => _CelebracionesScreenState();
}

class _CelebracionesScreenState extends State<CelebracionesScreen> {
  bool _cargando = true;
  List<Celebracion> _celebraciones = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cargando) {
      final service = Provider.of<CelebracionService>(context, listen: false);
      _cargarCelebraciones(service);
    }
  }

  Future<void> _cargarCelebraciones(CelebracionService service) async {
    try {
      final data = await service.listarCelebraciones();
      if (mounted) {
        setState(() {
          _celebraciones = data;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        NotificationBanner.show(
          context,
          'Error al cargar celebraciones: $e',
          NotificationType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final usuario = auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.teal.shade700,
        title: const Text(
          'Celebraciones y Eventos',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.celebration_rounded,
                    color: Colors.teal,
                    size: 90,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Bienvenido al módulo de Celebraciones y Eventos',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // REGISTRAR CUMPLEAÑOS
                  _buildMenuButton(
                    context,
                    icon: Icons.cake,
                    color: Colors.pinkAccent,
                    title: 'Registrar Cumpleaños',
                    subtitle:
                        'Agrega Empleados para Celebrar su Día Especial.',
                    onTap: () {
                      Navigator.pushNamed(context, '/cumpleanios');
                    },
                  ),

                  // REGISTRAR EVENTOS
                  _buildMenuButton(
                    context,
                    icon: Icons.event_note,
                    color: Colors.blue.shade600,
                    title: 'Registrar Eventos',
                    subtitle:
                        'Agrega Actividades Programadas Corporativas.',
                    onTap: () {
                      Navigator.pushNamed(context, '/eventos');
                    },
                  ),

                  const SizedBox(height: 30),
                  const Divider(thickness: 1.2),
                  const SizedBox(height: 15),
                  _buildMiniLeyenda(),
                ],
              ),
            ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: color, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color,
              child: Icon(icon, color: Colors.white),
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniLeyenda() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.event_note, color: Colors.blue, size: 20),
        SizedBox(width: 6),
        Text('Eventos',
            style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black87)),
        SizedBox(width: 20),
        Icon(Icons.cake, color: Colors.pinkAccent, size: 20),
        SizedBox(width: 6),
        Text('Cumpleaños',
            style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black87)),
      ],
    );
  }
}
