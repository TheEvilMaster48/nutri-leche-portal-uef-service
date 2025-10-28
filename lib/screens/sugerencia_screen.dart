import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../models/sugerencia.dart';
import '../services/sugerencia_service.dart';
import '../core/notification_banner.dart';

class SugerenciaScreen extends StatefulWidget {
  const SugerenciaScreen({super.key});

  @override
  State<SugerenciaScreen> createState() => _SugerenciaScreenState();
}

class _SugerenciaScreenState extends State<SugerenciaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _categoria;
  String? _archivoNombre;
  Uint8List? _archivoBytes;
  bool _enviando = false;

  List<Sugerencia> _lista = [];

  final _categorias = [
    'Clima laboral',
    'Producción',
    'Administración',
    'Recursos Humanos',
    'Distribución y Ventas',
    'Innovación',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = Provider.of<SugerenciaService>(context, listen: false);
    _cargarSugerencias(service);
  }

  // CARGAR SUGERENCIAS DESDE EL BACKEND
  Future<void> _cargarSugerencias(SugerenciaService service) async {
    try {
      final data = await service.listarSugerencias(context);
      if (mounted) {
        setState(() => _lista = data.reversed.toList());
      }
    } catch (_) {}
  }

  // SELECCIONAR ARCHIVO (PDF, DOCX, IMAGEN, ETC)
  Future<void> _seleccionarArchivo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'xls', 'xlsx', 'jpg', 'png'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;

      setState(() {
        _archivoNombre = file.name;
        _archivoBytes = file.bytes;
      });
    } catch (e) {
      NotificationBanner.show(
        context,
        'Error al seleccionar archivo: $e',
        NotificationType.error,
      );
    }
  }

  // ENVIAR NUEVA SUGERENCIA AL BACKEND
  Future<void> _enviarSugerencia() async {
    if (!_formKey.currentState!.validate()) return;
    if (_archivoBytes == null) {
      NotificationBanner.show(
        context,
        'Por favor adjunta un archivo antes de enviar.',
        NotificationType.warning,
      );
      return;
    }

    setState(() => _enviando = true);

    final nueva = Sugerencia(
      id: const Uuid().v4(),
      categoria: _categoria ?? 'Sin categoría',
      titulo: _tituloCtrl.text.trim(),
      descripcion: _descCtrl.text.trim(),
      imagenPath: _archivoNombre,
      fecha: DateTime.now(),
      base64: base64Encode(_archivoBytes!),
      rutaLocal: null,
    );

    final service = Provider.of<SugerenciaService>(context, listen: false);
    await service.crearSugerencia(context, nueva);
    await _cargarSugerencias(service);

    setState(() {
      _tituloCtrl.clear();
      _descCtrl.clear();
      _archivoNombre = null;
      _archivoBytes = null;
      _categoria = null;
      _enviando = false;
    });
  }

  // ELIMINAR SUGERENCIA (POR ID)
  Future<void> _eliminarSugerencia(String id) async {
    final service = Provider.of<SugerenciaService>(context, listen: false);
    await service.eliminarSugerencia(context, id);
    await _cargarSugerencias(service);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6FA),
      appBar: AppBar(
        title: const Text('Buzón de sugerencias'),
        backgroundColor: Colors.teal[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '🗳️ Envío anónimo',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tu opinión es confidencial. Nutri Leche valora tus ideas.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 25),

                  // CAMPO CATEGORÍA
                  DropdownButtonFormField<String>(
                    value: _categoria,
                    decoration: InputDecoration(
                      labelText: 'Categoría',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: _categorias
                        .map((cat) =>
                            DropdownMenuItem(value: cat, child: Text(cat)))
                        .toList(),
                    onChanged: (v) => setState(() => _categoria = v),
                    validator: (v) =>
                        v == null ? 'Seleccione una categoría' : null,
                  ),
                  const SizedBox(height: 20),

                  // CAMPO TÍTULO
                  TextFormField(
                    controller: _tituloCtrl,
                    decoration: InputDecoration(
                      labelText: 'Título',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Ingrese un título' : null,
                  ),
                  const SizedBox(height: 20),

                  // CAMPO DESCRIPCIÓN
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Descripción',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (v) => v == null || v.isEmpty
                        ? 'Ingrese una descripción'
                        : null,
                  ),
                  const SizedBox(height: 20),

                  // BOTÓN PARA ADJUNTAR ARCHIVO
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _seleccionarArchivo,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('Añadir archivo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (_archivoNombre != null)
                        Expanded(
                          child: Text(
                            _archivoNombre!,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 25),

                  // BOTÓN ENVIAR
                  ElevatedButton.icon(
                    onPressed: _enviando ? null : _enviarSugerencia,
                    icon: _enviando
                        ? const CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)
                        : const Icon(Icons.send),
                    label: Text(_enviando ? 'Enviando...' : 'Enviar sugerencia'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[700],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 14),
                      textStyle: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(thickness: 1.5, height: 40),

            // LISTADO DE SUGERENCIAS ENVIADAS
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '📋 Sugerencias enviadas',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800]),
              ),
            ),
            const SizedBox(height: 10),

            if (_lista.isEmpty)
              const Text('Aún no hay sugerencias enviadas.',
                  style: TextStyle(color: Colors.black54))
            else
              ListView.builder(
                itemCount: _lista.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final s = _lista[index];
                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.teal,
                        child: Icon(Icons.person_off, color: Colors.white),
                      ),
                      title: Text(
                        s.titulo,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.descripcion),
                          const SizedBox(height: 6),
                          Text('Categoría: ${s.categoria}',
                              style: const TextStyle(color: Colors.grey)),
                          Text(
                            'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(s.fecha)}',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                          ),
                          if (s.imagenPath != null)
                            Row(
                              children: [
                                const Icon(Icons.insert_drive_file,
                                    color: Colors.teal),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    s.imagenPath!,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.black87,
                                        decoration: TextDecoration.underline),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _eliminarSugerencia(s.id),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
