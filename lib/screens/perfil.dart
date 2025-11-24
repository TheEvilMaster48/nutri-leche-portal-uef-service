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
            // FOTO DE PERFIL USUARIO
            Container(
              width: 130,
              height: 130,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: ClipOval(
                child: Builder(
                  builder: (context) {
                    final cedula = usuario.cedula?.trim() ?? '';

                    // URL dinámica basada en la cédula del usuario
                    final imageUrl = (cedula.isNotEmpty)
                        ? 'https://servicioslsaq.nutri.com.ec/alimentacion/$cedula.jpeg'
                        : 'https://servicioslsaq.nutri.com.ec/alimentacion/default.jpeg';

                    return Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // 🔸 No mostrar nada si falla la carga
                        return const SizedBox.shrink();
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        // 🔸 Mantener espacio mientras carga
                        return const SizedBox.shrink();
                      },
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 🔹 Nombre del usuario
            Text(
              usuario.nombre,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 8),

            // 🔹 Cargo o área
            Text(
              usuario.cargo.isNotEmpty ? usuario.cargo : 'Empleado Nutri',
              style: const TextStyle(fontSize: 18, color: Colors.black54),
            ),

            const Divider(height: 40, thickness: 1.2),

            //  Información detallada
            _buildInfoRow(Icons.badge, 'ID', usuario.id.toString()),
            _buildInfoRow(Icons.email_rounded, 'Correo', usuario.correo),
            _buildInfoRow(Icons.phone_rounded, 'Teléfono', usuario.telefono),
            _buildInfoRow(Icons.apartment_rounded, 'Área', usuario.areaUsuario),
            _buildInfoRow(Icons.widgets_rounded, 'Módulos', usuario.modulos),

            const SizedBox(height: 40),

            // Botón Regresar al Menú
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
