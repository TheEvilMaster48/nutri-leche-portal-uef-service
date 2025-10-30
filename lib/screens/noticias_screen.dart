import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/noticias.dart';
import '../services/noticias_service.dart';
import 'dart:html' as html; // PARA ABRIR ARCHIVOS BASE64 EN NAVEGADOR

class NoticiasScreen extends StatefulWidget {
  const NoticiasScreen({super.key});

  @override
  State<NoticiasScreen> createState() => _NoticiasScreenState();
}

class _NoticiasScreenState extends State<NoticiasScreen> {
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  String? _archivoBase64;
  String? _archivoNombre;
  String? _editandoId;

  @override
  void initState() {
    super.initState();
    _cargarNoticias();
  }

  Future<void> _cargarNoticias() async {
    await context.read<NoticiasService>().obtenerNoticias();
  }

  Future<void> _seleccionarArchivo() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes != null) {
        setState(() {
          _archivoBase64 = base64Encode(bytes);
          _archivoNombre = file.name;
        });
      }
    }
  }

  Future<void> _guardarNoticia() async {
    final titulo = _tituloController.text.trim();
    final descripcion = _descripcionController.text.trim();

    if (titulo.isEmpty || descripcion.isEmpty || _archivoBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos antes de guardar')),
      );
      return;
    }

    final noticia = Noticia(
      id: _editandoId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      titulo: titulo,
      descripcion: descripcion,
      archivo: _archivoBase64 ?? '',
    );

    final service = context.read<NoticiasService>();

    if (_editandoId == null) {
      await service.crearNoticia(noticia);
    } else {
      await service.actualizarNoticia(noticia);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_editandoId == null
            ? 'Noticia añadida correctamente'
            : 'Noticia actualizada correctamente'),
        backgroundColor: Colors.teal,
      ),
    );

    _limpiarFormulario();
  }

  void _limpiarFormulario() {
    setState(() {
      _tituloController.clear();
      _descripcionController.clear();
      _archivoBase64 = null;
      _archivoNombre = null;
      _editandoId = null;
    });
  }

  void _editarNoticia(Noticia noticia) {
    setState(() {
      _editandoId = noticia.id;
      _tituloController.text = noticia.titulo;
      _descripcionController.text = noticia.descripcion;
      _archivoBase64 = noticia.archivo;
      _archivoNombre = "Archivo actual";
    });
  }

  void _eliminarNoticia(String id) async {
    final service = context.read<NoticiasService>();
    await service.eliminarNoticia(id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Noticia eliminada correctamente'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _abrirArchivo(String base64Data) {
    try {
      final bytes = base64Decode(base64Data);
      final blob = html.Blob([Uint8List.fromList(bytes)]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.window.open(url, '_blank');
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al abrir archivo: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final noticiasService = context.watch<NoticiasService>();
    final noticias = noticiasService.noticias;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Noticias Corporativas',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.teal.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Recargar Noticias',
            onPressed: _cargarNoticias,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // FORMULARIO SUPERIOR
            Card(
              color: Colors.teal.shade50,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _tituloController,
                      decoration: const InputDecoration(
                        labelText: 'Título',
                        prefixIcon: Icon(Icons.title, color: Colors.teal),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _descripcionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        prefixIcon: Icon(Icons.description, color: Colors.blue),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _seleccionarArchivo,
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Añadir Archivo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _archivoNombre ?? 'Ningún archivo seleccionado',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _guardarNoticia,
                            icon: const Icon(Icons.save),
                            label: Text(_editandoId == null
                                ? 'Guardar Noticia'
                                : 'Actualizar Noticia'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              minimumSize: const Size(double.infinity, 45),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: _limpiarFormulario,
                          icon: const Icon(Icons.clear),
                          label: const Text('Limpiar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // LISTA DE NOTICIAS
            Expanded(
              child: noticias.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay noticias disponibles por el momento.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: noticias.length,
                      itemBuilder: (context, index) {
                        final noticia = noticias[index];
                        return Card(
                          color: Colors.blue.shade50,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 2,
                          child: ListTile(
                            title: Text(
                              noticia.titulo,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            subtitle: Text(noticia.descripcion),
                            trailing: Wrap(
                              spacing: 8,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.open_in_new, color: Colors.green),
                                  tooltip: 'Abrir archivo',
                                  onPressed: () => _abrirArchivo(noticia.archivo),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  tooltip: 'Editar noticia',
                                  onPressed: () => _editarNoticia(noticia),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  tooltip: 'Eliminar noticia',
                                  onPressed: () => _eliminarNoticia(noticia.id),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
