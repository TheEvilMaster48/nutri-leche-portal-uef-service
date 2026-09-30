import 'package:flutter/material.dart';

import 'tarjeta_menu.dart';

/// Las tres pestañas de la app.
enum PestanaInferior { inicio, utilitarios, perfil }

/// La barra de abajo, igual en Inicio, Utilitarios y Perfil.
///
/// Vive en un solo lugar porque antes cada pantalla dibujaba la suya: Perfil
/// tenía dos ítems y el menú otros dos con distinta navegación, así que entrar
/// a un módulo hacía desaparecer la barra y el usuario perdía el camino de
/// vuelta.
///
/// **Cómo navega.** El menú es la primera ruta del stack —el login se
/// reemplaza al entrar, no se apila—, así que volver a Inicio es desapilar
/// hasta la base. Las otras dos pestañas se abren siempre desde ahí, de modo
/// que el botón atrás del teléfono lleva al inicio y nunca encadena Perfil
/// sobre Utilitarios sobre Perfil.
class BarraInferior extends StatelessWidget {
  const BarraInferior({super.key, required this.activa});

  final PestanaInferior activa;

  static const double alto = 65;

  @override
  Widget build(BuildContext context) {
    // Inset inferior (home indicator de iPhone): sin reservarlo, la barra se
    // desborda en iOS.
    final double bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      height: alto + bottomInset,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Pestana(
              icono: Icons.home_outlined,
              etiqueta: 'Inicio',
              activa: activa == PestanaInferior.inicio,
              alTocar: () => _ir(context, PestanaInferior.inicio),
            ),
            _Pestana(
              icono: Icons.apps_rounded,
              etiqueta: 'Utilitarios',
              activa: activa == PestanaInferior.utilitarios,
              // Chip lleno: es el acceso a los módulos de uso ocasional y se
              // destaca a propósito del resto de la barra.
              destacada: true,
              alTocar: () => _ir(context, PestanaInferior.utilitarios),
            ),
            _Pestana(
              icono: Icons.person_outline,
              etiqueta: 'Perfil',
              activa: activa == PestanaInferior.perfil,
              alTocar: () => _ir(context, PestanaInferior.perfil),
            ),
          ],
        ),
      ),
    );
  }

  void _ir(BuildContext context, PestanaInferior destino) {
    if (destino == activa) return;

    // Se toma el Navigator antes de desapilar: después del pop, el context de
    // esta barra ya no sirve para navegar.
    final navegador = Navigator.of(context);
    navegador.popUntil((ruta) => ruta.isFirst);

    switch (destino) {
      case PestanaInferior.inicio:
        break;
      case PestanaInferior.utilitarios:
        navegador.pushNamed('/utilitarios');
      case PestanaInferior.perfil:
        navegador.pushNamed('/perfil');
    }
  }
}

class _Pestana extends StatelessWidget {
  const _Pestana({
    required this.icono,
    required this.etiqueta,
    required this.activa,
    required this.alTocar,
    this.destacada = false,
  });

  final IconData icono;
  final String etiqueta;
  final bool activa;
  final bool destacada;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final Color color = activa || destacada ? PaletaMenu.cabecera : Colors.grey;

    return Expanded(
      child: InkWell(
        onTap: alTocar,
        child: SizedBox(
          height: BarraInferior.alto,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (destacada)
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: PaletaMenu.cabecera,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icono, color: Colors.white, size: 21),
                )
              else
                Icon(icono, color: color, size: 24),
              const SizedBox(height: 3),
              Text(
                etiqueta,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: activa ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: activa ? PaletaMenu.cabecera : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
