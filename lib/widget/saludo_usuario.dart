import 'package:flutter/material.dart';

/// «Hola, Nombre Apellido» bajo el logo, igual en Inicio y en Perfil.
///
/// El WS entrega el nombre en mayúsculas; en un saludo eso se lee como un
/// grito, así que se pasa a tipo título. Va sobre la cabecera azul.
class SaludoUsuario extends StatelessWidget {
  const SaludoUsuario({super.key, required this.nombre});

  final String nombre;

  @override
  Widget build(BuildContext context) {
    final String nombreLegible = _tipoTitulo(nombre);

    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(
            text: 'Hola, ',
            style: TextStyle(fontWeight: FontWeight.w400),
          ),
          TextSpan(
            text: nombreLegible.isNotEmpty ? nombreLegible : 'bienvenido',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 16,
        height: 1.3,
        color: Colors.white,
        letterSpacing: 0.2,
      ),
    );
  }

  static String _tipoTitulo(String texto) {
    return texto
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase() + p.substring(1).toLowerCase())
        .join(' ');
  }
}
