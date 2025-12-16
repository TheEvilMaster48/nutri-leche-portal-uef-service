import 'package:flutter/material.dart';

class ConfiguracionScreen extends StatelessWidget {
  const ConfiguracionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF3B82F6),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        children: [
          _buildSeccion('Cuenta'),
          _buildOpcion(Icons.person, 'Información personal', () {}),
          _buildOpcion(Icons.lock, 'Cambiar contraseña', () {}),
          _buildOpcion(Icons.security, 'Privacidad', () {}),
          const Divider(),
          _buildSeccion('Notificaciones'),
          _buildSwitchOpcion(Icons.notifications, 'Notificaciones push', true, (val) {}),
          _buildSwitchOpcion(Icons.email, 'Notificaciones por correo', false, (val) {}),
          const Divider(),
          _buildSeccion('Apariencia'),
          _buildOpcion(Icons.palette, 'Tema', () {}),
          _buildOpcion(Icons.language, 'Idioma', () {}),
          const Divider(),
          _buildSeccion('Otros'),
          _buildOpcion(Icons.help, 'Ayuda y soporte', () {}),
          _buildOpcion(Icons.info, 'Acerca de', () {}),
          _buildOpcion(Icons.logout, 'Cerrar sesión', () {}, color: Colors.red),
        ],
      ),
    );
  }

  Widget _buildSeccion(String titulo) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        titulo,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildOpcion(IconData icono, String titulo, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icono, color: color),
      title: Text(titulo, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildSwitchOpcion(IconData icono, String titulo, bool valor, Function(bool) onChanged) {
    return ListTile(
      leading: Icon(icono),
      title: Text(titulo),
      trailing: Switch(
        value: valor,
        onChanged: onChanged,
        activeTrackColor: const Color(0xFF3B82F6),
      ),
    );
  }
}
