import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/usuario.dart';

class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final Usuario? usuario = auth.currentUser;

    if (usuario == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Perfil'),
          backgroundColor: const Color.fromARGB(255, 1, 121, 145),
        ),
        body: const Center(
          child: Text(
            'No hay información de usuario disponible.',
            style: TextStyle(fontSize: 18, color: Colors.black54),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: const Color.fromARGB(255, 1, 121, 145),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar del usuario
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey.shade300,
              child: const Icon(Icons.person_rounded,
                  size: 70, color: Colors.white),
            ),
            const SizedBox(height: 20),

            Text(
              usuario.nombre,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              usuario.cargo.isNotEmpty
                  ? usuario.cargo
                  : 'Empleado Nutri Leche',
              style: const TextStyle(fontSize: 18, color: Colors.black54),
            ),
            const Divider(height: 40, thickness: 1.2),

            // Información detallada del usuario
            _buildInfoRow(Icons.badge, 'ID', usuario.id.toString()),
            _buildInfoRow(Icons.email_rounded, 'Correo', usuario.correo),
            _buildInfoRow(Icons.phone_rounded, 'Teléfono', usuario.telefono),
            _buildInfoRow(Icons.apartment_rounded, 'Área', usuario.areaUsuario),
            _buildInfoRow(Icons.widgets_rounded, 'Módulos', usuario.modulos),

            const SizedBox(height: 40),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 1, 121, 145),
                padding:
                    const EdgeInsets.symmetric(horizontal: 35, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              label: const Text(
                'Volver al Menú',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget auxiliar para mostrar la información con ícono
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color.fromARGB(255, 1, 121, 145)),
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          value.isNotEmpty ? value : 'No registrado',
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
