import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'package:universal_html/html.dart' as html;
import 'package:provider/provider.dart';
import '../models/agenda.dart';
import '../services/agenda_service.dart';
import '../services/auth_service.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  final _tituloCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _horaInicioCtrl = TextEditingController();
  final _horaFinCtrl = TextEditingController();
  final _recordatorioCtrl = TextEditingController();

  bool _cargando = false;

  // VARIABLES BASE64
  String? _nombreArchivo;
  Uint8List? _archivoBytes;
  String? _archivoBase64;

  // GUARDADO LOCAL DE ARCHIVOS
  final Map<int, Uint8List> _archivosGuardados = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        Provider.of<AgendaService>(context, listen: false).obtenerCitas());
  }

  // SELECCIONAR ARCHIVO Y CONVERTIR A BASE64
  Future<void> _seleccionarArchivo() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final archivo = result.files.first;
      setState(() {
        _nombreArchivo = archivo.name;
        _archivoBytes = archivo.bytes;
        _archivoBase64 = base64Encode(archivo.bytes!);
      });
    }
  }

  // ABRIR ARCHIVO EN NAVEGADOR DESDE BASE64
  Future<void> _abrirArchivo(String base64Data, String nombre) async {
    try {
      final bytes = base64Decode(base64Data);
      final mimeType = lookupMimeType(nombre) ?? 'application/octet-stream';
      final blob = html.Blob([bytes], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.window.open(url, "_blank");
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Error al abrir archivo: $e")),
      );
    }
  }

  // CREAR NUEVA CITA
  Future<void> _crearCita() async {
    final agendaService = context.read<AgendaService>();
    final authService = context.read<AuthService>();
    final usuarioActual = authService.currentUser;

    if (usuarioActual == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No hay usuario autenticado")),
      );
      return;
    }

    if (_tituloCtrl.text.isEmpty ||
        _descripcionCtrl.text.isEmpty ||
        _archivoBase64 == null ||
        _nombreArchivo == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Completa todos los campos y añade un archivo")),
      );
      return;
    }

    setState(() => _cargando = true);

    final nuevaCita = Agenda(
      id: DateTime.now().millisecondsSinceEpoch,
      titulo: _tituloCtrl.text.trim(),
      descripcion:
          "${_descripcionCtrl.text.trim()} (Archivo: $_nombreArchivo)", // descripción extendida
      fecha: DateTime.now(),
      horaInicio: _horaInicioCtrl.text.trim(),
      horaFin: _horaFinCtrl.text.trim(),
      recordatorio: _archivoBase64!, // SE GUARDA BASE64 EN EL CAMPO RECORDATORIO
    );

    try {
      await agendaService.crearCita(nuevaCita, usuarioActual);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Cita creada correctamente")),
      );

      // GUARDAR LOCALMENTE EL ARCHIVO
      _archivosGuardados[nuevaCita.id] = _archivoBytes!;

      _limpiarCampos();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error al crear cita: $e")),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _eliminarCita(String id) async {
    final service = context.read<AgendaService>();
    setState(() => _cargando = true);
    try {
      await service.eliminarCita(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🗑️ Cita eliminada correctamente")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error al eliminar cita: $e")),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _limpiarCampos() {
    _tituloCtrl.clear();
    _descripcionCtrl.clear();
    _horaInicioCtrl.clear();
    _horaFinCtrl.clear();
    _recordatorioCtrl.clear();
    _nombreArchivo = null;
    _archivoBytes = null;
    _archivoBase64 = null;
  }

  @override
  Widget build(BuildContext context) {
    final agendaService = context.watch<AgendaService>();
    final citas = agendaService.citas;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🗓️ Agenda de Citas con Base64'),
        backgroundColor: Colors.teal.shade700,
      ),
      body: RefreshIndicator(
        onRefresh: () => agendaService.obtenerCitas(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ExpansionTile(
              title: const Text("Agregar nueva cita"),
              children: [
                TextField(
                    controller: _tituloCtrl,
                    decoration: const InputDecoration(labelText: "Título")),
                TextField(
                    controller: _descripcionCtrl,
                    decoration: const InputDecoration(labelText: "Descripción")),
                TextField(
                    controller: _horaInicioCtrl,
                    decoration:
                        const InputDecoration(labelText: "Hora de inicio")),
                TextField(
                    controller: _horaFinCtrl,
                    decoration:
                        const InputDecoration(labelText: "Hora de fin")),
                const SizedBox(height: 12),

                // BOTÓN PARA SELECCIONAR ARCHIVO
                GestureDetector(
                  onTap: _seleccionarArchivo,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.teal.shade300, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.attach_file,
                            color: Colors.teal.shade600, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _nombreArchivo ?? "Añadir Archivos",
                            style: TextStyle(
                              color: _nombreArchivo == null
                                  ? Colors.teal.shade700
                                  : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                ElevatedButton.icon(
                  onPressed: _cargando ? null : _crearCita,
                  icon: const Icon(Icons.save),
                  label: _cargando
                      ? const Text("Guardando...")
                      : const Text("Guardar Cita"),
                ),
                const SizedBox(height: 12),
              ],
            ),
            const Divider(),

            citas.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(top: 100),
                    child: Center(child: Text("No hay citas registradas")),
                  )
                : Column(
                    children: citas.map((c) {
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: Text(c.titulo,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            "${c.descripcion}\n${c.horaInicio} - ${c.horaFin}",
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.open_in_new,
                                    color: Colors.blue),
                                onPressed: () => _abrirArchivo(
                                    c.recordatorio, c.titulo),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: _cargando
                                    ? null
                                    : () => _eliminarCita(c.id.toString()),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _horaInicioCtrl.dispose();
    _horaFinCtrl.dispose();
    _recordatorioCtrl.dispose();
    super.dispose();
  }
}
