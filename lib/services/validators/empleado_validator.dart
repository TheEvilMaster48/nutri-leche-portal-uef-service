class EmpleadoValidator {
  static bool validarCodigoEmpleado(String codigo) {
    // Permitir letras y números, longitud mínima 4
    final regex = RegExp(r'^[a-zA-Z0-9]{4,10}$');
    return regex.hasMatch(codigo);
  }

  static String? validarNombreCompleto(String nombre) {
    if (nombre.trim().isEmpty) {
      return 'El nombre completo es requerido';
    }
    if (nombre.trim().split(' ').length < 2) {
      return 'Ingrese nombre y apellido';
    }
    return null;
  }

  static String? validarCorreo(String correo) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(correo)) {
      return 'Correo electrónico inválido';
    }
    return null;
  }
}
