// ✅ Test básico de verificación del entorno Flutter para Nutri Leche
//
// Este archivo mantiene activo el entorno de pruebas sin depender
// del widget de ejemplo 'MyApp' generado por defecto.
//
// Puedes agregar pruebas reales más adelante, como validar que las
// pantallas de Login o Registro carguen correctamente.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Verifica entorno de pruebas de Nutri', () {
    // 🧩 Prueba simple para confirmar que el entorno de test funciona
    const appName = 'Nutri';
    expect(appName.isNotEmpty, true);
    expect(1 + 1, equals(2));
  });
}
