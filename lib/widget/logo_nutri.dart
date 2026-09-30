import 'package:flutter/material.dart';

/// El logotipo de Nutri, en la versión que corresponde al fondo.
///
/// La marca tiene dos artes —una azul y una blanca— y usar la equivocada la
/// deja invisible: el logo blanco sobre fondo claro desaparece y el azul sobre
/// la cabecera corporativa se apaga. Esa regla vive acá y en ningún otro lado,
/// así que ninguna pantalla tiene que acordarse de cuál toca.
///
/// Es un logotipo horizontal (la palabra «nutri»), no un ícono cuadrado: se
/// dimensiona por [alto] y el ancho lo define la proporción del arte.
class LogoNutri extends StatelessWidget {
  const LogoNutri({super.key, required this.sobreFondoOscuro, this.alto = 48});

  /// Versión blanca para la cabecera azul y demás fondos oscuros.
  const LogoNutri.claro({super.key, this.alto = 48}) : sobreFondoOscuro = true;

  /// Versión azul para fondos blancos o claros.
  const LogoNutri.oscuro({super.key, this.alto = 48})
    : sobreFondoOscuro = false;

  /// Si el fondo sobre el que se dibuja es oscuro.
  final bool sobreFondoOscuro;

  final double alto;

  static const String assetClaro = 'assets/icono/logo_blanco.png';
  static const String assetOscuro = 'assets/icono/logo_azul.png';

  String get asset => sobreFondoOscuro ? assetClaro : assetOscuro;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      height: alto,
      fit: BoxFit.contain,
      // El logotipo es texto: si la imagen faltara, un cuadro roto en la
      // cabecera es peor que no mostrar nada.
      errorBuilder: (_, _, _) => SizedBox(height: alto),
    );
  }
}
