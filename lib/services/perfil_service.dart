import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../base/base.dart';
import '../models/usuario.dart';
import '../services/auth_service.dart';

/// Relee los datos del usuario conectado (los mismos que devuelve el login,
/// incluidos `codigoSap` y `departamento`) para refrescar la pantalla de Perfil.
///
///   POST $URL_APP/perfilAPPOficial   { idUsuario }
///        → { mensaje, correcto, data: { id, nombre, correo, telefono, cargo,
///            codigoSap, departamento, genero, modulos, centro, ... } }
///
/// Antes de consultar se comprueba que el servidor sea alcanzable: si el equipo
/// está sin red, NO se llama al WS y la pantalla sigue mostrando lo que quedó
/// guardado del último login. Lo mismo si la respuesta falla, así el perfil
/// nunca queda vacío.
///
/// Nota: verificado por curl el 2026-08-06 contra `servicioslsa.nutri.com.ec`,
/// `perfilAPPOficial` responde **404** (todavía no desplegado), mientras
/// `loginAPPOficial` en la misma base responde 200. Hasta que se publique, la
/// pantalla usa el fallback.
class PerfilService with ChangeNotifier {
  /// Ruta de lectura de los datos del usuario conectado.
  static const String rutaDatos = 'perfilAPPOficial';

  /// Ruta de actualización (PUT), como estaba.
  static const String rutaActualizar = 'perfil';

  final String _baseUrl = Base.URL_APP;
  final AuthService _authService;

  PerfilService(this._authService);

  Usuario? _perfil;
  bool _cargando = false;

  /// Datos frescos del servidor. `null` mientras no haya una respuesta válida:
  /// la pantalla debe caer en `AuthService.currentUser` en ese caso.
  Usuario? get perfil => _perfil;
  bool get cargando => _cargando;

  /// Desenvuelve la respuesta del WS. Igual que en el login, `data` puede venir
  /// como objeto o como String con el JSON adentro (incluso doble escapado).
  Map<String, dynamic>? _extraerDatos(String cuerpo) {
    try {
      dynamic decoded = json.decode(cuerpo);

      if (decoded is Map && decoded.containsKey('data')) {
        if (decoded['correcto'] == false) {
          debugPrint('PERFIL: WS respondió "${decoded['mensaje']}"');
          return null;
        }
        decoded = decoded['data'];
      }

      var intentos = 0;
      while (decoded is String && intentos < 3) {
        final texto = decoded.trim();
        if (!texto.startsWith('{')) break;
        decoded = json.decode(texto);
        intentos++;
      }

      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (e) {
      debugPrint('PERFIL: no se pudo interpretar la respuesta: $e');
      return null;
    }
  }

  /// `true` si el servidor de servicios es alcanzable.
  ///
  /// Se comprueba contra el host del WS (`Base.HOST_SERVICIOS`) y no contra un
  /// sitio público: el servidor vive en la red interna, así que "tener
  /// internet" no sirve de nada si no se llega a él. Un socket TCP con timeout
  /// corto evita que la pantalla se quede esperando cuando no hay red.
  Future<bool> hayConexion() async {
    // En web no existe Socket; se asume conectado y decide el propio request.
    if (kIsWeb) return true;

    final partes = Base.HOST_SERVICIOS.split(':');
    final host = partes.first;
    final puerto = partes.length > 1 ? int.tryParse(partes[1]) ?? 80 : 80;

    try {
      final socket = await Socket.connect(
        host,
        puerto,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      return true;
    } on SocketException catch (e) {
      debugPrint('PERFIL: sin conexión a $host:$puerto ($e)');
      return false;
    } catch (e) {
      debugPrint('PERFIL: no se pudo verificar la conexión: $e');
      return false;
    }
  }

  /// Vuelve a consultar los datos del usuario conectado.
  ///
  /// Se llama al entrar a Perfil y en el pull-to-refresh. Si no hay conexión, o
  /// si la consulta falla, no se borra nada: la pantalla sigue mostrando la
  /// sesión guardada del último login.
  Future<void> obtenerPerfil() async {
    final usuario = _authService.currentUser;
    if (usuario == null || usuario.id <= 0) return;

    if (!await hayConexion()) {
      debugPrint('PERFIL: sin conexión, se muestran los datos guardados');
      return;
    }

    _cargando = true;
    notifyListeners();

    final url = Uri.parse('$_baseUrl/$rutaDatos');
    debugPrint('PERFIL → POST $url  {idUsuario: ${usuario.id}}');

    try {
      // Se manda el id con los dos nombres que usa el API y además el usuario,
      // por si la ruta lo identifica por login (el WS tolera campos extra).
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'idUsuario': usuario.id,
              'id': usuario.id,
              'usuario': usuario.usuario,
            }),
          )
          .timeout(const Duration(seconds: 12));

      debugPrint('PERFIL ← HTTP ${response.statusCode} ${response.body}');

      if (response.statusCode == 404) {
        debugPrint('PERFIL: $rutaDatos no existe en el WS; '
            'se mantienen los datos del último login');
      } else if (response.statusCode == 200) {
        final data = _extraerDatos(response.body);

        if (data != null) {
          final fresco = Usuario.fromJson(data);
          _perfil = fresco;
          // Se propaga al resto de la app y se persiste, así el menú y las
          // demás pantallas ven los mismos datos.
          await _authService.actualizarUsuario(fresco);
        }
      }
    } catch (e) {
      debugPrint('PERFIL: error al consultar: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// Actualiza Perfil
  Future<bool> actualizarPerfil(Usuario perfilActualizado) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/$rutaActualizar/${perfilActualizado.id}'),
        headers: {"Content-Type": "application/json"},
        body: json.encode(perfilActualizado.toJson()),
      );

      if (response.statusCode == 200) {
        _perfil = perfilActualizado;
        _authService.actualizarUsuario(perfilActualizado);
        notifyListeners();
        return true;
      } else {
        if (kDebugMode) {
          print("⚠️ Error al actualizar perfil: ${response.statusCode}");
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error en actualizarPerfil(): $e");
      }
      return false;
    }
  }

  /// Recargar Perfil
  Future<void> recargarPerfil() async {
    await obtenerPerfil();
  }
}
