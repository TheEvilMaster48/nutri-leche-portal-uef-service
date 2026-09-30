import 'package:flutter/material.dart';

/// Paleta de los módulos del menú.
///
/// Son los azules corporativos de [Base] y el verde que ya usa el módulo de
/// rutas, elegidos para que el ícono blanco encima se lea: el verde claro de
/// la marca (#86B918) sobre blanco queda por debajo del contraste mínimo y en
/// un chip lleno se vuelve ilegible.
class PaletaMenu {
  PaletaMenu._();

  static const Color azulCorp = Color(0xFF0B4697);
  static const Color azulOscuro = Color(0xFF005EA8);
  static const Color verde = Color(0xFF93CB4A);

  /// El azul de la cabecera, el mismo de la onda.
  static const Color cabecera = Color(0xFF0052A3);
}

/// Una tarjeta del menú.
///
/// Todos los módulos se dibujan igual: chip de color con el ícono en blanco,
/// título y subtítulo debajo. El color es lo único que cambia entre uno y otro,
/// y sale de la paleta corporativa, así que la cuadrícula se lee como un juego
/// y no como recortes de orígenes distintos.
class TarjetaMenu extends StatelessWidget {
  const TarjetaMenu({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.color,
    required this.alTocar,
    this.badge = 0,
  });

  final String titulo;
  final String subtitulo;
  final IconData icono;
  final Color color;
  final VoidCallback alTocar;

  /// Pendientes del módulo. 0 oculta el globo.
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 1.5,
      shadowColor: Colors.black.withOpacity(0.18),
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(icono, size: 30, color: Colors.white),
                  ),
                  if (badge > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Text(
                          badge > 99 ? '99+' : badge.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Flexible y no Text a secas: con la letra del sistema agrandada
              // el contenido no entra en la tarjeta, y preferimos que el texto
              // se recorte a que Flutter pinte la franja de desbordamiento.
              Flexible(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    color: PaletaMenu.azulCorp,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    height: 1.15,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  subtitulo,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 11,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
