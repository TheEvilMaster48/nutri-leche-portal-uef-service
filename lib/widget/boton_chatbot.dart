import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'barra_inferior.dart';
import 'tarjeta_menu.dart';

/// Burbuja de chat que abre el Asistente Nutri.
///
/// No es un módulo más: flota a la derecha, justo encima de la barra de abajo,
/// en las tres pestañas. Va como hijo directo del `Stack` de cada pantalla,
/// después de la barra.
///
/// El usuario la puede esconder con la "×": queda una pestaña verde pegada al
/// borde derecho que la vuelve a mostrar. La preferencia es una sola para las
/// tres pestañas ([visible]) y se recuerda en el teléfono.
class BotonChatbot extends StatelessWidget {
  const BotonChatbot({super.key});

  static const double margen = 16;

  static const String _clave = 'chatbot_visible';

  /// Si la burbuja se muestra. Compartido por las tres pestañas.
  @visibleForTesting
  static final ValueNotifier<bool> visible = ValueNotifier<bool>(true);

  static bool _cargado = false;

  /// Lee la preferencia guardada una sola vez por ejecución de la app.
  static Future<void> _cargar() async {
    if (_cargado) return;
    _cargado = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      visible.value = prefs.getBool(_clave) ?? true;
    } catch (e) {
      debugPrint('⚠️ No se pudo leer la preferencia del chatbot: $e');
    }
  }

  static Future<void> cambiarVisible(bool valor) async {
    visible.value = valor;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_clave, valor);
    } catch (e) {
      debugPrint('⚠️ No se pudo guardar la preferencia del chatbot: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    _cargar();
    final double bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Positioned(
      right: 0,
      bottom: BarraInferior.alto + bottomInset + margen,
      child: ValueListenableBuilder<bool>(
        valueListenable: visible,
        builder: (context, mostrar, _) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animacion) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(animacion),
            child: child,
          ),
          child: mostrar ? _burbuja(context) : _pestana(),
        ),
      ),
    );
  }

  Widget _burbuja(BuildContext context) {
    return Padding(
      key: const ValueKey('burbuja'),
      // El margen derecho va aquí (no en el Positioned) para que la pestaña
      // oculta quede pegada al borde.
      padding: const EdgeInsets.only(right: margen, top: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          FloatingActionButton(
            heroTag: 'chatbot',
            tooltip: 'Asistente Nutri',
            backgroundColor: PaletaMenu.verde,
            foregroundColor: Colors.white,
            onPressed: () => Navigator.pushNamed(context, '/chatbot'),
            child: const Icon(Icons.smart_toy_outlined),
          ),
          Positioned(
            top: -8,
            right: -8,
            child: Tooltip(
              message: 'Ocultar asistente',
              child: GestureDetector(
                onTap: () => cambiarVisible(false),
                child: Container(
                  // Área táctil más grande que el círculo dibujado.
                  padding: const EdgeInsets.all(4),
                  color: Colors.transparent,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: PaletaMenu.verde, width: 1.5),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 3),
                      ],
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pestana() {
    return Tooltip(
      key: const ValueKey('pestana'),
      message: 'Mostrar asistente',
      child: Material(
        color: PaletaMenu.verde,
        elevation: 4,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
        child: InkWell(
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(14),
          ),
          onTap: () => cambiarVisible(true),
          child: const SizedBox(
            width: 28,
            height: 56,
            child: Icon(Icons.chevron_left, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
