import 'package:flutter/material.dart';

import '../base/base.dart';

/// Diálogo de confirmación para quitar una notificación de la lista.
///
/// Se pide confirmación porque el borrado no tiene "deshacer": el backend marca
/// el registro como eliminado para ese usuario.
Future<bool> confirmarEliminacion(
  BuildContext context, {
  required String titulo,
  required String mensaje,
}) async {
  final resultado = await showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          backgroundColor: Base().COLOR_BLANCO,
          title: Text(titulo, style: TextStyle(color: Base().COLOR_AZUL_CORP)),
          content: Text(mensaje),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancelar',
                style: TextStyle(color: Base().COLOR_AZUL_CORP),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Eliminar'),
            ),
          ],
        ),
  );

  return resultado == true;
}

/// Aviso cuando se intenta eliminar algo que el usuario todavía no vio.
///
/// Solo se elimina lo visto: así nadie borra un comunicado sin haberlo
/// abierto. Devuelve `true` si el usuario eligió marcarlo como visto; la
/// eliminación queda para después, con la confirmación de siempre.
///
/// [cantidad] es cuántos de los elegidos faltan por ver (1 para una tarjeta
/// suelta).
Future<bool> avisarNoVisto(BuildContext context, {int cantidad = 1}) async {
  final varias = cantidad > 1;
  final resultado = await showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          backgroundColor: Base().COLOR_BLANCO,
          title: Text(
            varias ? 'Hay $cantidad sin ver' : 'Aún no la has visto',
            style: TextStyle(color: Base().COLOR_AZUL_CORP),
          ),
          content: Text(
            varias
                ? 'Solo puedes eliminar notificaciones que ya viste. Márcalas como '
                    'vistas y luego elimínalas.'
                : 'Solo puedes eliminar notificaciones que ya viste. Ábrela o '
                    'márcala como vista y luego elimínala.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancelar',
                style: TextStyle(color: Base().COLOR_AZUL_CORP),
              ),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Base().COLOR_AZUL_CORP,
              ),
              icon: const Icon(Icons.done_all, size: 18),
              label: Text(varias ? 'Marcar como vistas' : 'Marcar como vista'),
            ),
          ],
        ),
  );

  return resultado == true;
}

/// Fondo rojo que aparece al deslizar la tarjeta hacia la izquierda.
class FondoEliminar extends StatelessWidget {
  const FondoEliminar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: Colors.red.shade400,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline, color: Colors.white),
          SizedBox(width: 8),
          Text(
            'Eliminar',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
