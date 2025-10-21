import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/usuario.dart';

class UsuarioService extends ChangeNotifier {
  Usuario? _usuarioActual;

  Usuario? get usuarioActual => _usuarioActual;

  // Cargar Usuario por ID
  Future<void> cargarUsuarioActual(String idUsuario) async {
    final prefs = await SharedPreferences.getInstance();
    final String? usuariosJson = prefs.getString('usuarios');

    if (usuariosJson != null) {
      final List<dynamic> decoded = json.decode(usuariosJson);
      final usuarios = decoded.map((e) => Usuario.fromJson(e)).toList();

      try {
        _usuarioActual = usuarios.firstWhere(
          (u) => u.id == idUsuario,
          orElse: () => usuarios.first,
        );
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ No se encontró el usuario con ID $idUsuario');
        }
        _usuarioActual = null;
      }

      notifyListeners();
    }
  }

  // Actualizar los Datos del Usuario
  Future<void> actualizarUsuario(Usuario usuarioActualizado) async {
    final prefs = await SharedPreferences.getInstance();
    final String? usuariosJson = prefs.getString('usuarios');

    if (usuariosJson != null) {
      final List<dynamic> decoded = json.decode(usuariosJson);
      List<Usuario> usuarios =
          decoded.map((e) => Usuario.fromJson(e)).toList();

      final index = usuarios.indexWhere(
          (u) => u.id == usuarioActualizado.id);

      if (index != -1) {
        usuarios[index] = usuarioActualizado;

        /*final String encoded =
            json.encode(usuarios.map((e) => e.toJson()).toList());
        await prefs.setString('usuarios', encoded);
*/
        _usuarioActual = usuarioActualizado;
        notifyListeners();
      } else {
        if (kDebugMode) {
          print('⚠️ Usuario no encontrado en la lista para actualizar');
        }
      }
    }
  }

  // Cerrar Sesión 
  void cerrarSesion() {
    _usuarioActual = null;
    notifyListeners();
  }
}
