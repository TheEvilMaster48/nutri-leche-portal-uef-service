import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/notification_banner.dart';
import '../services/auth_service.dart';

class RecursosScreen extends StatelessWidget {
  const RecursosScreen({super.key});

  Future<void> _descargarPDF(
    BuildContext context,
    String titulo,
    String contenido,
  ) async {
    try {
      final pdf = pw.Document();

      final logoImage =
          await imageFromAssetBundle('assets/icono/nutrileche.png');

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(32),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Nutri Ecuador',
                            style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue800,
                            ),
                          ),
                          pw.Text(
                            'Gestión de Recursos Humanos',
                            style: const pw.TextStyle(
                              fontSize: 14,
                              color: PdfColors.grey600,
                            ),
                          ),
                        ],
                      ),
                      pw.Container(
                        width: 60,
                        height: 60,
                        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                      ),
                    ],
                  ),
                  pw.Divider(),
                  pw.SizedBox(height: 24),
                  pw.Text(
                    titulo.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Divider(),
                  pw.SizedBox(height: 16),
                  pw.Text(
                    contenido,
                    style: const pw.TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: PdfColors.black,
                    ),
                    textAlign: pw.TextAlign.justify,
                  ),
                  pw.Spacer(),
                  pw.Divider(),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      'Fecha de generación: ${DateTime.now().toString().substring(0, 16)}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );

      if (context.mounted) {
        NotificationBanner.show(
          context,
          'El documento "$titulo" se ha descargado correctamente.',
          NotificationType.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        NotificationBanner.show(
          context,
          'Error al descargar el PDF: ${e.toString()}',
          NotificationType.error,
        );
      }
    }
  }

  Future<void> _editarYDescargarPDF(
    BuildContext context,
    String titulo,
    String contenidoInicial,
  ) async {
    final TextEditingController controller =
        TextEditingController(text: contenidoInicial);

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Editar documento: $titulo'),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: controller,
              maxLines: 20,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Edita el contenido del documento...',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.download, color: Colors.white),
              label: const Text(
                'Descargar PDF',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4ADE80),
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                _descargarPDF(context, titulo, controller.text);
              },
            ),
          ],
        );
      },
    );
  }

  bool _tienePermisoEdicion(AuthService auth) {
    final usuario = auth.currentUser;
    final area = usuario?.areaUsuario.toLowerCase() ?? '';
    final modulos = usuario?.modulos.toLowerCase() ?? '';

    return area.contains('recursos') ||
        area.contains('administracion') ||
        area.contains('produccion') ||
        area.contains('bodega') ||
        area.contains('ventas') ||
        modulos.contains('admin') ||
        modulos.contains('rrhh') ||
        modulos.contains('recursos');
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final puedeEditar = _tienePermisoEdicion(auth);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Recursos',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFA78BFA),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTituloSeccion('Documentos Institucionales'),
          _buildDocumentoCard(
            context,
            titulo: 'Manual del Empleado',
            descripcion:
                'Guía general de normas, políticas y beneficios de Nutri Ecuador.',
            icono: Icons.book_outlined,
            color: const Color(0xFF3B82F6),
            contenido: _contenidoManualEmpleado,
            puedeEditar: puedeEditar,
          ),
          _buildDocumentoCard(
            context,
            titulo: 'Código de Conducta',
            descripcion: 'Principios éticos y comportamiento profesional.',
            icono: Icons.gavel,
            color: const Color(0xFF4ADE80),
            contenido: _contenidoCodigoConducta,
            puedeEditar: puedeEditar,
          ),
          _buildDocumentoCard(
            context,
            titulo: 'Políticas de Seguridad y Salud',
            descripcion:
                'Protocolos de seguridad industrial y prevención de accidentes.',
            icono: Icons.health_and_safety,
            color: const Color(0xFFFBBF24),
            contenido: _contenidoPoliticasSeguridad,
            puedeEditar: puedeEditar,
          ),
          const SizedBox(height: 30),
          _buildTituloSeccion('Formularios de Gestión'),
          _buildDocumentoCard(
            context,
            titulo: 'Solicitud de Vacaciones',
            descripcion: 'Formato oficial para solicitar días de descanso.',
            icono: Icons.beach_access,
            color: const Color(0xFFFF6B6B),
            contenido: _contenidoSolicitudVacaciones,
            puedeEditar: puedeEditar,
          ),
          _buildDocumentoCard(
            context,
            titulo: 'Reporte de Incidentes',
            descripcion:
                'Formato para registrar accidentes o situaciones de riesgo.',
            icono: Icons.report_problem,
            color: const Color(0xFFA78BFA),
            contenido: _contenidoReporteIncidentes,
            puedeEditar: puedeEditar,
          ),
        ],
      ),
    );
  }

  Widget _buildTituloSeccion(String titulo) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        titulo,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDocumentoCard(
    BuildContext context, {
    required String titulo,
    required String descripcion,
    required IconData icono,
    required Color color,
    required String contenido,
    required bool puedeEditar,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icono, color: color),
        ),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(descripcion),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (puedeEditar)
              IconButton(
                icon: const Icon(Icons.edit_document, color: Colors.blueAccent),
                tooltip: 'Editar y descargar',
                onPressed: () => _editarYDescargarPDF(context, titulo, contenido),
              ),
            IconButton(
              icon: const Icon(Icons.download, color: Colors.indigo),
              tooltip: 'Descargar PDF',
              onPressed: () => _descargarPDF(context, titulo, contenido),
            ),
          ],
        ),
      ),
    );
  }

  static const String _contenidoManualEmpleado = '''
MANUAL DEL EMPLEADO - NUTRI ECUADOR

1. INTRODUCCIÓN
Bienvenido a Nutri Ecuador. Este manual contiene información importante sobre las políticas, procedimientos y beneficios de la empresa.

2. HORARIOS DE TRABAJO
- Lunes a Viernes: 8:00 AM - 5:00 PM
- Almuerzo: 12:00 PM - 1:00 PM

3. CÓDIGO DE VESTIMENTA
Se requiere vestimenta profesional y apropiada para el ambiente de trabajo.

4. BENEFICIOS
- Seguro médico
- Vacaciones anuales
- Bonos por desempeño

5. POLÍTICAS DE AUSENCIA
Las ausencias deben ser notificadas con anticipación al supervisor directo.
''';

  static const String _contenidoCodigoConducta = '''
CÓDIGO DE CONDUCTA - NUTRI ECUADOR

1. PRINCIPIOS FUNDAMENTALES
- Integridad
- Respeto
- Responsabilidad
- Excelencia

2. COMPORTAMIENTO PROFESIONAL
Todos los empleados deben mantener un comportamiento profesional y ético en todo momento.

3. CONFLICTOS DE INTERÉS
Los empleados deben evitar situaciones que puedan generar conflictos de interés.

4. CONFIDENCIALIDAD
La información confidencial de la empresa debe ser protegida en todo momento.
''';

  static const String _contenidoPoliticasSeguridad = '''
POLÍTICAS DE SEGURIDAD Y SALUD OCUPACIONAL

1. SEGURIDAD EN EL TRABAJO
- Uso obligatorio de equipo de protección personal.
- Reportar inmediatamente cualquier condición insegura.

2. EMERGENCIAS
- Conocer las rutas de evacuación.
- Participar en simulacros de emergencia.

3. PREVENCIÓN DE ACCIDENTES
- Mantener áreas de trabajo limpias y organizadas.
- Seguir todos los procedimientos de seguridad.
''';

  static const String _contenidoSolicitudVacaciones = '''
SOLICITUD DE VACACIONES

Nombre del Empleado: _______________________
Código de Empleado: _______________________
Departamento: _______________________

Fechas solicitadas:
Desde: _______________________
Hasta: _______________________

Total de días: _______________________

Motivo: _______________________

Firma del Empleado: _______________________
Fecha: _______________________

Aprobación del Supervisor: _______________________
''';

  static const String _contenidoReporteIncidentes = '''
REPORTE DE INCIDENTES

Fecha del incidente: _______________________
Hora: _______________________
Ubicación: _______________________

Descripción del incidente:
_____________________________________________________
_____________________________________________________
_____________________________________________________

Personas involucradas:
_____________________________________________________

Testigos:
_____________________________________________________

Acciones tomadas:
_____________________________________________________

Reportado por: _______________________
Firma: _______________________
''';
}
