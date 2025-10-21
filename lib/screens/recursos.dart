import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/notification_banner.dart';
import '../services/auth_service.dart';
import '../services/recurso_service.dart';
import '../models/recurso.dart';

class RecursosScreen extends StatefulWidget {
  const RecursosScreen({super.key});

  @override
  State<RecursosScreen> createState() => _RecursosScreenState();
}

class _RecursosScreenState extends State<RecursosScreen> {
  bool _cargando = true;
  List<Recurso> _recursos = [];

  @override
  void initState() {
    super.initState();
    _cargarRecursos();
  }

  Future<void> _cargarRecursos() async {
    try {
      final recursoService = context.read<RecursoService>();
      final auth = context.read<AuthService>();
      final usuario = auth.currentUser;

      if (usuario == null) {
        setState(() => _cargando = false);
        return;
      }

      final recursos = await recursoService.obtenerRecursos(usuario);
      setState(() {
        _recursos = recursos;
        _cargando = false;
      });
    } catch (e) {
      setState(() => _cargando = false);
      if (mounted) {
        NotificationBanner.show(
          context,
          'Error al cargar recursos: ${e.toString()}',
          NotificationType.error,
        );
      }
    }
  }

  // Generar y descargar PDF
  Future<void> _descargarPDF(
      BuildContext context, String titulo, String contenido) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text(
                    'Nutri Leche Ecuador',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue700,
                    ),
                  ),
                ),
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
                  'Fecha de descarga: ${DateTime.now().toString().substring(0, 10)}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf.save());

      if (mounted) {
        NotificationBanner.show(
          context,
          'PDF descargado exitosamente',
          NotificationType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        NotificationBanner.show(
          context,
          'Error al generar el PDF',
          NotificationType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final usuario = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recursos', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFA78BFA),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _recursos.isEmpty
              ? const Center(
                  child: Text(
                    'No hay recursos disponibles en este momento.',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _recursos.length,
                  itemBuilder: (context, index) {
                    final recurso = _recursos[index];
                    return _buildRecursoCard(
                      context,
                      recurso,
                      usuario?.nombre ?? '',
                    );
                  },
                ),
    );
  }

  Widget _buildRecursoCard(
      BuildContext context, Recurso recurso, String usuarioNombre) {
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
            color: const Color(0xFF8B5CF6).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.folder_copy_rounded,
              color: Color(0xFF8B5CF6)),
        ),
        title: Text(
          recurso.titulo,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(recurso.descripcion ?? 'Sin descripción'),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.download, color: Colors.indigo),
          tooltip: 'Descargar PDF',
          onPressed: () => _descargarPDF(
            context,
            recurso.titulo,
            recurso.contenido ?? 'Contenido no disponible',
          ),
        ),
      ),
    );
  }
}
