import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/registro_logo.dart';

/// Almacenamiento local de los registros de Logo Nutri: la cola y sus fotos.
///
/// El módulo se usa en bodega y en planta, así que **el teléfono es la fuente
/// de verdad hasta que el servidor confirme**. Dos piezas:
///
/// - Los datos del registro, en `SharedPreferences`, segmentados por usuario:
///   la captura de un usuario no es de quien entre después en el mismo equipo.
/// - Las fotos, copiadas a una carpeta propia dentro del directorio de
///   documentos de la app. La cámara las deja en un temporal que el sistema
///   borra cuando quiere; una foto que se evapora antes de subir es trabajo
///   perdido que el usuario ya no puede rehacer (la escena ya no está).
class RegistroLogoStore {
  RegistroLogoStore._();

  static const String _carpeta = 'logo_nutri';

  static String _clave(int idUsuario) => 'logo_registros_$idUsuario';

  // ---------------------------------------------------------------------------
  // Cola
  // ---------------------------------------------------------------------------

  /// La cola en orden de captura: el más viejo primero.
  static Future<List<RegistroLogo>> leer(int idUsuario) async {
    if (idUsuario <= 0) return const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(_clave(idUsuario));
      if (crudo == null || crudo.isEmpty) return const [];

      final decodificado = json.decode(crudo);
      if (decodificado is! List) return const [];

      return decodificado
          .whereType<Map>()
          .map((e) => RegistroLogo.fromJson(e.cast<String, dynamic>()))
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));
    } catch (e) {
      debugPrint('⚠️ No se pudo leer la cola de registros: $e');
      return const [];
    }
  }

  static Future<void> guardar(
    int idUsuario,
    List<RegistroLogo> registros,
  ) async {
    if (idUsuario <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (registros.isEmpty) {
        await prefs.remove(_clave(idUsuario));
        return;
      }
      await prefs.setString(
        _clave(idUsuario),
        json.encode(registros.map((r) => r.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('⚠️ No se pudo guardar la cola de registros: $e');
    }
  }

  /// Agrega un registro al final y devuelve la cola resultante.
  static Future<List<RegistroLogo>> encolar(
    int idUsuario,
    RegistroLogo registro,
  ) async {
    final registros = [...await leer(idUsuario), registro];
    await guardar(idUsuario, registros);
    debugPrint('LOGO: encolado $registro (${registros.length} en cola)');
    return registros;
  }

  /// Reemplaza un registro por su id local — se usa para anotarle el estado,
  /// el intento fallido o los nombres de las fotos ya subidas.
  static Future<List<RegistroLogo>> reemplazar(
    int idUsuario,
    RegistroLogo registro,
  ) async {
    final registros = await leer(idUsuario);
    final indice = registros.indexWhere((r) => r.id == registro.id);
    if (indice < 0) return registros;
    registros[indice] = registro;
    await guardar(idUsuario, registros);
    return registros;
  }

  /// Saca un registro de la cola y borra sus fotos del teléfono.
  static Future<List<RegistroLogo>> quitar(
    int idUsuario,
    int idRegistro,
  ) async {
    final registros = await leer(idUsuario);
    final indice = registros.indexWhere((r) => r.id == idRegistro);
    if (indice < 0) return registros;

    final registro = registros.removeAt(indice);
    await guardar(idUsuario, registros);
    await borrarFotos(registro.fotos);
    return registros;
  }

  // ---------------------------------------------------------------------------
  // Fotos
  // ---------------------------------------------------------------------------

  /// Carpeta propia dentro de los documentos de la app. Se crea si no existe.
  static Future<Directory> carpetaFotos() async {
    final documentos = await getApplicationDocumentsDirectory();
    final carpeta = Directory('${documentos.path}/$_carpeta');
    if (!await carpeta.exists()) await carpeta.create(recursive: true);
    return carpeta;
  }

  /// Copia una foto recién tomada a la carpeta de la app y devuelve **el nombre
  /// del archivo**, no la ruta.
  ///
  /// Guardar el nombre y no la ruta es a propósito: ver [RegistroLogo.fotos].
  static Future<String?> guardarFoto(File origen, int idUsuario) async {
    try {
      final carpeta = await carpetaFotos();
      final extension = _extension(origen.path);
      final nombre =
          'logo_${idUsuario}_${DateTime.now().microsecondsSinceEpoch}$extension';
      await origen.copy('${carpeta.path}/$nombre');
      return nombre;
    } catch (e) {
      debugPrint('⚠️ No se pudo guardar la foto: $e');
      return null;
    }
  }

  /// Resuelve el archivo de una foto contra la carpeta del momento.
  static Future<File> archivoFoto(String nombre) async {
    final carpeta = await carpetaFotos();
    return File('${carpeta.path}/$nombre');
  }

  static Future<void> borrarFotos(List<String> nombres) async {
    for (final nombre in nombres) {
      try {
        final archivo = await archivoFoto(nombre);
        if (await archivo.exists()) await archivo.delete();
      } catch (e) {
        debugPrint('⚠️ No se pudo borrar la foto $nombre: $e');
      }
    }
  }

  static String _extension(String ruta) {
    final punto = ruta.lastIndexOf('.');
    if (punto < 0 || punto == ruta.length - 1) return '.jpg';
    final extension = ruta.substring(punto).toLowerCase();
    // La cámara puede devolver .heic en iOS; se respeta lo que llegue salvo que
    // venga algo que no parezca una extensión de imagen.
    return extension.length <= 5 ? extension : '.jpg';
  }
}
