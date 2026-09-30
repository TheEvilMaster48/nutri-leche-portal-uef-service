import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/cierre_sesion.dart';
import '../services/perfil_service.dart';
import '../models/usuario.dart';
import '../widget/barra_inferior.dart';
import '../widget/tarjeta_menu.dart';
import '../widget/logo_nutri.dart';
import '../widget/saludo_usuario.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  @override
  void initState() {
    super.initState();
    // Al entrar a Perfil se releen los datos del usuario desde el WS. Si la
    // consulta falla, la pantalla sigue mostrando la sesión guardada.
    WidgetsBinding.instance.addPostFrameCallback((_) => _recargar());
  }

  Future<void> _recargar() async {
    if (!mounted) return;
    final activo = await context.read<PerfilService>().obtenerPerfil();
    if (!activo && mounted) {
      await cerrarSesion(context, motivo: PerfilService.mensajeInactivo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final perfilService = context.watch<PerfilService>();

    // Se prefieren los datos frescos del WS; si todavía no llegaron (o la ruta
    // no existe), se usa la sesión guardada del último login.
    final Usuario? usuario = perfilService.perfil ?? auth.currentUser;

    if (usuario == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Perfil'),
          backgroundColor: PaletaMenu.cabecera,
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
      // Todo el fondo azul, como el inicio y utilitarios: antes la onda partía
      // la pantalla y la tarjeta de datos quedaba sobre blanco.
      backgroundColor: PaletaMenu.cabecera,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  // Arrastrar hacia abajo vuelve a consultar los datos.
                  child: RefreshIndicator(
                    onRefresh: _recargar,
                    color: const Color(0xFF0052A3),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                      child: Column(
                        children: [
                          // El logotipo, igual que en el menú, en lugar de la
                          // foto de archivo por género: no decía nada del
                          // usuario que su propio nombre no diga mejor. Sobre el
                          // azul de la cabecera va la versión blanca.
                          const LogoNutri.claro(alto: 72),

                          const SizedBox(height: 16),

                          // Mismo saludo que en Inicio.
                          SaludoUsuario(nombre: usuario.nombre),

                          const SizedBox(height: 28),

                          // CARD CONTENEDOR DE TODA LA INFORMACIÓN
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              // Blanca, como las tarjetas del menú: el gris
                              // sobre el azul se veía apagado y desentonaba
                              // con el resto de la app.
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // CÓDIGO SAP (con imagen)
                                // Se muestra el código SAP en vez del id interno;
                                // el id se sigue usando en toda la funcionalidad.
                                _buildInfoItemWithImage(
                                  imagePath: 'assets/icono/id.jpg',
                                  label: 'Código SAP',
                                  value:
                                      usuario.codigoSap.isNotEmpty
                                          ? usuario.codigoSap
                                          : 'No registrado',
                                ),

                                const Divider(
                                  height: 32,
                                  thickness: 1,
                                  color: Color(0xFFE6E9EF),
                                ),

                                // CORREO (con imagen)
                                _buildInfoItemWithImage(
                                  imagePath: 'assets/icono/correo.jpg',
                                  label: 'Correo',
                                  value: usuario.correo,
                                ),

                                const Divider(
                                  height: 32,
                                  thickness: 1,
                                  color: Color(0xFFE6E9EF),
                                ),

                                // TELÉFONO (con imagen)
                                _buildInfoItemWithImage(
                                  imagePath: 'assets/icono/telefono.jpg',
                                  label: 'Teléfono',
                                  value: usuario.telefono,
                                ),

                                const Divider(
                                  height: 32,
                                  thickness: 1,
                                  color: Color(0xFFE6E9EF),
                                ),

                                // DEPARTAMENTO (con imagen)
                                _buildInfoItemWithImage(
                                  imagePath: 'assets/icono/area.jpg',
                                  label: 'Departamento',
                                  value:
                                      usuario.departamento.isNotEmpty
                                          ? usuario.departamento
                                          : 'No registrado',
                                ),

                                const Divider(
                                  height: 32,
                                  thickness: 1,
                                  color: Color(0xFFE6E9EF),
                                ),

                                // GÉNERO (con icono)
                                _buildInfoItemWithIcon(
                                  icon: Icons.wc,
                                  label: 'Género',
                                  value:
                                      usuario.genero == 'femenino'
                                          ? 'Femenino'
                                          : 'Masculino',
                                ),

                                const Divider(
                                  height: 32,
                                  thickness: 1,
                                  color: Color(0xFFE6E9EF),
                                ),

                                // MÓDULOS (con imagen)
                                _buildInfoItemWithImage(
                                  imagePath: 'assets/icono/modulos.jpg',
                                  label: 'Módulos',
                                  value:
                                      usuario.modulos.isNotEmpty
                                          ? usuario.modulos
                                          : 'Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat. Ut wisi enim ad minim veniam, quis nostrudliquip ex ea',
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // CERRAR SESIÓN
                          //
                          // Vive solo acá: antes estaba en un ícono de la
                          // esquina del menú, donde se tocaba sin querer y no
                          // se entendía qué hacía.
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: () => cerrarSesion(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                  color: Colors.white70,
                                  width: 1.4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.exit_to_app),
                              label: const Text(
                                'Cerrar Sesión',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BarraInferior(activa: PestanaInferior.perfil),
          ),
        ],
      ),
    );
  }

  // ITEM DE INFORMACIÓN CON IMAGEN DESDE ASSETS
  Widget _buildInfoItemWithImage({
    required String imagePath,
    required String label,
    required String value,
  }) {
    // DETERMINAR TAMAÑO DEL ICONO SEGÚN EL TIPO
    double iconWidth = 60;
    double iconHeight = 60;
    BoxFit iconFit = BoxFit.contain;

    // ICONO DE ID: 60 X 60
    if (imagePath.contains('id.jpg')) {
      iconWidth = 60;
      iconHeight = 60;
      iconFit = BoxFit.contain;
    }
    // ICONO DE CORREO: 40 X 40
    else if (imagePath.contains('correo.jpg')) {
      iconWidth = 40;
      iconHeight = 40;
      iconFit = BoxFit.scaleDown;
    }
    // ICONO DE TELÉFONO: 60 X 60
    else if (imagePath.contains('telefono.jpg')) {
      iconWidth = 60;
      iconHeight = 60;
      iconFit = BoxFit.contain;
    }
    // ICONO DE ÁREA: 60 X 60
    else if (imagePath.contains('area.jpg')) {
      iconWidth = 60;
      iconHeight = 60;
      iconFit = BoxFit.contain;
    }
    // ICONO DE MÓDULOS: 40 X 40
    else if (imagePath.contains('modulos.jpg')) {
      iconWidth = 40;
      iconHeight = 40;
      iconFit = BoxFit.scaleDown;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // IMAGENES DESDE ASSETS
        Container(
          width: 60,
          height: 60,
          alignment: Alignment.center,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.asset(
              imagePath,
              width: iconWidth,
              height: iconHeight,
              fit: iconFit,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 20,
                  height: 20,
                  color: const Color(0xFFE0E0E0),
                  child: const Icon(
                    Icons.image_not_supported,
                    color: Color(0xFF0052A3),
                    size: 20,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 16),
        // CONTENIDO
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0052A3),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value.isNotEmpty ? value : 'No registrado',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ITEM DE INFORMACIÓN CON ICONO (GÉNERO)
  Widget _buildInfoItemWithIcon({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ICONO GENERO
        Container(
          width: 60,
          height: 40,
          alignment: Alignment.center,
          child: Icon(icon, color: const Color(0xFF0052A3), size: 30),
        ),
        const SizedBox(width: 16),
        // CONTENIDO
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0052A3),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value.isNotEmpty ? value : 'No registrado',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
