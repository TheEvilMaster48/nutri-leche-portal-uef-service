class TelefonoValidator {
  static String? validarTelefono(String telefono, String prefijo) {
    // Remover espacios y guiones
    final telefonoLimpio = telefono.replaceAll(RegExp(r'[\s-]'), '');

    // Validar longitud según el país
    int longitudEsperada = 9; // Por defecto Ecuador
    if (prefijo == '+57') longitudEsperada = 10; // Colombia
    if (prefijo == '+52') longitudEsperada = 10; // México

    if (telefonoLimpio.length != longitudEsperada) {
      return 'El teléfono debe tener $longitudEsperada dígitos';
    }

    // Validar que solo contenga números
    if (int.tryParse(telefonoLimpio) == null) {
      return 'El teléfono solo debe contener números';
    }

    return null;
  }

  static String formatearTelefono(String telefono, String prefijo) {
    final telefonoLimpio = telefono.replaceAll(RegExp(r'[\s-]'), '');
    
    // Formatear según el país
    if (prefijo == '+593') {
      // Ecuador: 09X XXX XXXX
      if (telefonoLimpio.length == 9) {
        return '${telefonoLimpio.substring(0, 2)} ${telefonoLimpio.substring(2, 5)} ${telefonoLimpio.substring(5)}';
      }
    }
    
    return telefonoLimpio;
  }
}
