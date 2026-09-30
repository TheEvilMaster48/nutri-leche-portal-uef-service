import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../base/base.dart';
import 'auth_service.dart';
import 'badge_service.dart';
import 'calendario_evento_service.dart';
import 'cumpleanios_service.dart';
import 'evento_service.dart';
import 'nutrisoft_service.dart';
import 'push_service.dart';
import 'reaccion_service.dart';
import 'registro_logo_service.dart';
import 'sorteo_service.dart';
import 'sugerencia_service.dart';
import 'usuario_service.dart';

/// Cierra la sesión: confirma, limpia todo lo del usuario y vuelve al login.
///
/// Vive suelto y no dentro de una pantalla porque el botón está solo en Perfil,
/// pero la limpieza es de la aplicación entera: los providers cuelgan por
/// encima de `MaterialApp` y **sobreviven al logout**, así que hay que vaciarlos
/// a mano o el siguiente usuario que entre ve por un instante los datos del
/// anterior.
///
/// Con [motivo] el cierre es forzado (por ejemplo, el WS dice que el usuario
/// está inactivo): en lugar de preguntar se muestra [motivo] y, al aceptar, se
/// cierra la sesión sin opción de cancelar.
///
/// No lanza: si el usuario cancela, no pasa nada.
Future<void> cerrarSesion(BuildContext context, {String? motivo}) async {
  final auth = context.read<AuthService>();
  final reacciones = context.read<ReaccionService>();

  // Se leen ANTES del await para no tocar el context después del gap asíncrono.
  final eventos = context.read<EventoService>();
  final cumpleanios = context.read<CumpleaniosService>();
  final nutrisoft = context.read<NutrisoftService>();
  final sorteos = context.read<SorteoService>();
  final calendario = context.read<CalendarioEventoService>();
  final sugerencias = context.read<SugerenciaService>();
  final usuarios = context.read<UsuarioService>();
  final registrosLogo = context.read<RegistroLogoService>();
  // PerfilService no se limpia acá: es un ChangeNotifierProxyProvider sobre
  // AuthService y, cuando `logout()` notifica, él mismo descarta los datos del
  // usuario que salió (`PerfilService.alCambiarSesion`).

  final navegador = Navigator.of(context);

  final Future<bool?> dialogo =
      motivo != null
          ? _avisarCierreForzado(context, motivo)
          : _confirmarCierre(context);
  final confirmado = await dialogo;

  if (confirmado != true) return;
  if (!context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  await auth.logout();
  await PushService.instance.stopCompletely();
  await BadgeService.limpiar();
  // La caché de reacciones es por usuario: se descarta al salir.
  await reacciones.limpiar();

  // Resto de datos de la sesión que quedaban en memoria.
  eventos.limpiar();
  cumpleanios.limpiar();
  nutrisoft.limpiar();
  sorteos.limpiar();
  calendario.limpiar();
  sugerencias.limpiar();
  usuarios.cerrarSesion();
  // La cola de Logo Nutri es por usuario: se descarta de memoria, pero lo
  // guardado en disco se conserva para cuando ese usuario vuelva.
  registrosLogo.limpiar();

  // Imágenes descargadas (fotos de perfil, adjuntos de eventos): son del
  // usuario que sale y no deben reaparecer en la sesión siguiente.
  imageCache.clear();
  imageCache.clearLiveImages();

  // Se cierra el indicador y se vacía el stack: atrás no puede devolver a una
  // pantalla de la sesión que acaba de cerrarse.
  navegador.pop();
  navegador.pushNamedAndRemoveUntil('/', (_) => false);
}

/// Aviso del cierre forzado: un solo botón, así que siempre termina en `true`.
Future<bool> _avisarCierreForzado(BuildContext context, String motivo) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogo) {
      return PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: Base().COLOR_BLANCO,
          title: Text(
            'Sesión finalizada',
            style: TextStyle(color: Base().COLOR_AZUL_CORP),
          ),
          content: Text(motivo),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogo).pop(),
              child: Text(
                'Aceptar',
                style: TextStyle(color: Base().COLOR_AZUL_CORP),
              ),
            ),
          ],
        ),
      );
    },
  );
  return true;
}

/// Pregunta antes de cerrar la sesión a pedido del usuario.
Future<bool?> _confirmarCierre(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogo) {
      return AlertDialog(
        backgroundColor: Base().COLOR_BLANCO,
        title: Text(
          'Cerrar Sesión',
          style: TextStyle(color: Base().COLOR_AZUL_CORP),
        ),
        content: const Text('¿Estás seguro que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Base().COLOR_AZUL_CORP),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      );
    },
  );
}
