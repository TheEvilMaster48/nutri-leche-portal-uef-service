import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/auth_service.dart';
import '../services/notificacion_service.dart';
import '../core/notification_banner.dart';

class RecursosScreen extends StatelessWidget {
  const RecursosScreen({super.key});

  // Descargar PDF con logo Nutri Leche
  Future<void> _descargarPDF(
      BuildContext context, String titulo, String contenido) async {
    try {
      final pdf = pw.Document();

      // Cargar el logo desde assets
      final logoImage = await imageFromAssetBundle('assets/icono/nutrileche.png');

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Encabezado con título y logo
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Nutri Leche Ecuador',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.Container(
                      width: 60,
                      height: 60,
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    ),
                  ],
                ),
                pw.Divider(),
                pw.SizedBox(height: 20),
                pw.Text(
                  titulo,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.SizedBox(height: 20),
                pw.Text(
                  contenido,
                  style: const pw.TextStyle(fontSize: 12),
                  textAlign: pw.TextAlign.justify,
                ),
                pw.SizedBox(height: 40),
                pw.Text(
                  'Fecha de generación: ${DateTime.now().toString().substring(0, 10)}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Mostrar el PDF generado
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );

      // Registrar notificación
      final notificacionService = context.read<NotificacionService>();
      notificacionService.agregarNotificacion(
        'Documento descargado',
        'Se ha descargado el documento "$titulo" correctamente',
        'recurso',
      );

      if (context.mounted) {
        NotificationBanner.show(
          context,
          'PDF descargado exitosamente',
          NotificationType.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        NotificationBanner.show(
          context,
          'Error al descargar el PDF',
          NotificationType.error,
        );
      }
    }
  }

  // Editar y descargar PDF (solo roles con permiso)
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
          title: Text('Editar: $titulo'),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: controller,
              maxLines: 15,
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
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _descargarPDF(context, titulo, controller.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
              ),
              child: const Text(
                'Descargar PDF',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final usuario = auth.currentUser;

    //  Determinar permisos según área o módulos
    final area = usuario?.areaUsuario.toLowerCase() ?? '';
    final modulos = usuario?.modulos.toLowerCase() ?? '';

    final bool tienePermiso = area.contains('recursos') ||
        area.contains('administrativa') ||
        area.contains('produccion') ||
        area.contains('bodega') ||
        area.contains('ventas') ||
        modulos.contains('recursos') ||
        modulos.contains('admin') ||
        modulos.contains('rrhh');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recursos', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFA78BFA),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSeccion('Documentos de la Empresa'),
          _buildDocumentoCard(
            context,
            titulo: 'Manual del Empleado',
            descripcion:
                'Guía completa sobre políticas y procedimientos de la empresa',
            icono: Icons.book,
            color: const Color(0xFF3B82F6),
            contenido: _contenidoManualEmpleado,
            puedeEditar: tienePermiso,
          ),
          _buildDocumentoCard(
            context,
            titulo: 'Código de Conducta',
            descripcion: 'Normas éticas y de comportamiento profesional',
            icono: Icons.gavel,
            color: const Color(0xFF4ADE80),
            contenido: _contenidoCodigoConducta,
            puedeEditar: tienePermiso,
          ),
          _buildDocumentoCard(
            context,
            titulo: 'Políticas de Seguridad',
            descripcion: 'Protocolos de seguridad y salud ocupacional',
            icono: Icons.security,
            color: const Color(0xFFFBBF24),
            contenido: _contenidoPoliticasSeguridad,
            puedeEditar: tienePermiso,
          ),
          const SizedBox(height: 20),
          _buildSeccion('Formularios'),
          _buildDocumentoCard(
            context,
            titulo: 'Solicitud de Vacaciones',
            descripcion: 'Formato para solicitar días de vacaciones',
            icono: Icons.beach_access,
            color: const Color(0xFFFF6B6B),
            contenido: _contenidoSolicitudVacaciones,
            puedeEditar: tienePermiso,
          ),
          _buildDocumentoCard(
            context,
            titulo: 'Reporte de Incidentes',
            descripcion: 'Formato para reportar incidentes de seguridad',
            icono: Icons.report_problem,
            color: const Color(0xFFA78BFA),
            contenido: _contenidoReporteIncidentes,
            puedeEditar: tienePermiso,
          ),
        ],
      ),
    );
  }

  Widget _buildSeccion(String titulo) {
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
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
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
                icon: const Icon(Icons.edit, color: Colors.blueAccent),
                tooltip: 'Editar y descargar',
                onPressed: () =>
                    _editarYDescargarPDF(context, titulo, contenido),
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

  // -------------------- CONTENIDO DE LOS DOCUMENTOS --------------------

  static const String _contenidoManualEmpleado = '''
MANUAL DEL EMPLEADO - NUTRI LECHE ECUADOR

1. INTRODUCCIÓN
Bienvenido a Nutri Leche Ecuador. Este manual contiene información importante sobre las políticas, procedimientos y beneficios de la empresa.

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
CÓDIGO DE CONDUCTA - NUTRI LECHE ECUADOR

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
POLÍTICAS DE SEGURIDAD - NUTRI LECHE ECUADOR

1. SEGURIDAD EN EL TRABAJO
- Uso obligatorio de equipo de protección personal
- Reportar inmediatamente cualquier condición insegura

2. EMERGENCIAS
- Conocer las rutas de evacuación
- Participar en simulacros de emergencia

3. PREVENCIÓN DE ACCIDENTES
- Mantener áreas de trabajo limpias y organizadas
- Seguir todos los procedimientos de seguridad
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
_______________________
_______________________
_______________________

Personas involucradas:
_______________________

Testigos:
_______________________

Acciones tomadas:
_______________________

Reportado por: _______________________
Firma: _______________________
''';
}
