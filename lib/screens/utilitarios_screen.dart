import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/usuario.dart';
import '../services/auth_service.dart';
import '../services/cierre_sesion.dart';
import '../services/perfil_service.dart';
import '../widget/barra_inferior.dart';
import '../widget/logo_nutri.dart';
import '../widget/tarjeta_menu.dart';

/// Los módulos de uso ocasional, fuera de la pantalla de inicio.
///
/// Existe para que el inicio no crezca cada vez que aparece un módulo nuevo:
/// ahí quedan los cuatro del día a día y acá los que se abren de vez en
/// cuando. Usa las mismas tarjetas y los mismos colores, así que el usuario no
/// tiene que aprender otra pantalla.
class UtilitariosScreen extends StatefulWidget {
  const UtilitariosScreen({super.key});

  /// Si el usuario ve el módulo Rutas (permiso `APP-VIAJES`).
  @visibleForTesting
  static bool tieneModuloRutas(Usuario? usuario) =>
      tieneAcceso(usuario, 'APP-VIAJES');

  /// Si el usuario ve el módulo Rebranding (permiso `APP-REBRANDING`).
  @visibleForTesting
  static bool tieneModuloRebranding(Usuario? usuario) =>
      tieneAcceso(usuario, 'APP-REBRANDING');

  @override
  State<UtilitariosScreen> createState() => _UtilitariosScreenState();

  /// Si [codigo] está entre los permisos del usuario, **escrito exactamente
  /// igual**.
  ///
  /// `accesos` llega como lista en texto separada por comas —«Vehiculos,
  /// APPKM, SGD SGSI, APP-VIAJES»—, a veces entre corchetes. Se separa **solo
  /// por comas** (los códigos llevan guiones y espacios) y cada permiso tiene
  /// que ser idéntico al buscado, mayúsculas incluidas: no basta con que
  /// contenga `APP`, ni sirve `app-viajes` o `APP-VIAJES2`. Solo se quitan los
  /// espacios que rodean a cada permiso, que son parte del separador.
  @visibleForTesting
  static bool tieneAcceso(Usuario? usuario, String codigo) {
    final accesos = usuario?.accesos ?? '';
    return accesos
        .replaceAll(RegExp(r'[\[\]]'), '')
        .split(',')
        .any((permiso) => permiso.trim() == codigo);
  }
}

class _UtilitariosScreenState extends State<UtilitariosScreen> {
  @override
  void initState() {
    super.initState();
    // Cada vez que se entra se releen los permisos del servidor: si a alguien
    // le acaban de dar acceso a Rutas o Rebranding, lo ve sin cerrar sesión.
    // Mientras tanto se muestra lo que ya había; sin conexión se queda así.
    // Si el WS dice que el usuario está inactivo, se cierra la sesión.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final activo = await context.read<PerfilService>().obtenerPerfil();
      if (!activo && mounted) {
        await cerrarSesion(context, motivo: PerfilService.mensajeInactivo);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthService>().currentUser;
    final menus = _menus(usuario);

    return Scaffold(
      // Mismo azul del inicio: las tarjetas blancas resaltan sobre él.
      backgroundColor: PaletaMenu.cabecera,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // La misma cabecera de las otras dos pestañas: el logotipo y,
                // debajo, de qué va la pantalla.
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    children: [
                      LogoNutri.claro(alto: 72),
                      SizedBox(height: 18),
                      Text(
                        'UTILITARIOS',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Módulos de uso ocasional',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.85,
                        ),
                    itemCount: menus.length,
                    itemBuilder: (context, i) {
                      final menu = menus[i];
                      return TarjetaMenu(
                        titulo: menu['titulo'] as String,
                        subtitulo: menu['subtitulo'] as String,
                        icono: menu['icono'] as IconData,
                        color: menu['color'] as Color,
                        alTocar:
                            () => Navigator.pushNamed(
                              context,
                              menu['ruta'] as String,
                            ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BarraInferior(activa: PestanaInferior.utilitarios),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _menus(Usuario? usuario) {
    return [
      {
        'titulo': 'Buzón de Sugerencias',
        'subtitulo': 'Nueva sugerencia',
        'icono': Icons.mark_email_unread_outlined,
        'color': PaletaMenu.verde,
        'ruta': '/buzon',
      },
      // Solo para choferes: ver [tieneModuloRutas].
      if (UtilitariosScreen.tieneModuloRutas(usuario))
        {
          'titulo': 'Rutas',
          'subtitulo': 'Viajes y registro de eventos',
          'icono': Icons.local_shipping_outlined,
          'color': PaletaMenu.verde,
          'ruta': '/rutas',
        },
      if (UtilitariosScreen.tieneModuloRebranding(usuario))
        {
          'titulo': 'Rebranding',
          'subtitulo': 'Material de marca en puntos de venta',
          'icono': Icons.storefront_outlined,
          'color': PaletaMenu.verde,
          'ruta': '/logo_nutri',
        },
    ];
  }
}
