import 'package:flutter/material.dart';

class AyudaScreen extends StatelessWidget {
  const AyudaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayuda y Soporte', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF4ADE80),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSeccion('Preguntas Frecuentes'),
          _buildPregunta(
            '¿Cómo cambio mi contraseña?',
            'Ve a Configuración > Cambiar contraseña e ingresa tu contraseña actual y la nueva.',
          ),
          _buildPregunta(
            '¿Cómo creo un nuevo evento?',
            'En la sección Eventos, presiona el botón "Nuevo Evento" y completa la información requerida.',
          ),
          _buildPregunta(
            '¿Cómo inicio un chat?',
            'Ve a la sección Chat, presiona el botón + y selecciona el contacto con quien deseas chatear.',
          ),
          const SizedBox(height: 20),
          _buildSeccion('Contacto'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.email, color: Color(0xFF3B82F6)),
              title: const Text('Correo de soporte'),
              subtitle: const Text('soporte@nutrileche.com.ec'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.phone, color: Color(0xFF4ADE80)),
              title: const Text('Teléfono'),
              subtitle: const Text('+593 99 999 9999'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccion(String titulo) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        titulo,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPregunta(String pregunta, String respuesta) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          pregunta,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(respuesta),
          ),
        ],
      ),
    );
  }
}
