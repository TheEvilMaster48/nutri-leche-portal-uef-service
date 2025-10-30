import 'dart:typed_data';
import 'dart:convert'; 
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:universal_html/html.dart' as html;
import 'package:mime/mime.dart';
import '../models/beneficio.dart';
import '../services/beneficio_service.dart';
import '../core/notification_banner.dart';

class BeneficiosScreen extends StatefulWidget {
  const BeneficiosScreen({super.key});

  @override
  State<BeneficiosScreen> createState() => _BeneficiosScreenState();
}

class _BeneficiosScreenState extends State<BeneficiosScreen> {
  final BeneficioService _service = BeneficioService();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _tipoController = TextEditingController();
  final _categoriaController = TextEditingController();

  bool _activo = true;
  String? _nombreArchivo;
  Uint8List? _archivoBytes;
  String? _archivoBase64;
  List<Beneficio> _beneficios = [];

  // ARCHIVOS EN MEMORIA LOCAL
  final Map<int, Uint8List> _archivosGuardados = {};

  @override
  void initState() {
    super.initState();
    _cargarBeneficios();
  }

  Future<void> _cargarBeneficios() async {
    final lista = await _service.listar();
    setState(() => _beneficios = lista);
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
        _archivoBase64 = base64Encode(archivo.bytes!); // CONVERTIR A BASE64
      });
    }
  }

  // GUARDAR BENEFICIO LOCALMENTE
  Future<void> _guardarBeneficio() async {
    if (_nombreController.text.isEmpty ||
        _descripcionController.text.isEmpty ||
        _tipoController.text.isEmpty ||
        _categoriaController.text.isEmpty ||
        _archivoBase64 == null ||
        _nombreArchivo == null) {
      NotificationBanner.show(
        context,
        "⚠️ Completa todos los campos y selecciona un archivo",
        NotificationType.error,
      );
      return;
    }

    final beneficio = Beneficio(
      id: DateTime.now().millisecondsSinceEpoch,
      nombre: _nombreController.text.trim(),
      descripcion: _descripcionController.text.trim(),
      tipo: _tipoController.text.trim(),
      categoria: _categoriaController.text.trim(),
      imagenUrl: _archivoBase64!, // SE GUARDA EL BASE64 AQUÍ
      fechaPublicacion: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      activo: _activo,
    );

    _archivosGuardados[beneficio.id] = _archivoBytes!;
    await _service.agregar(beneficio);

    NotificationBanner.show(
      context,
      "🎁 Beneficio agregado correctamente",
      NotificationType.success,
    );

    _nombreController.clear();
    _descripcionController.clear();
    _tipoController.clear();
    _categoriaController.clear();
    setState(() {
      _nombreArchivo = null;
      _archivoBytes = null;
      _archivoBase64 = null;
      _activo = true;
    });
    await _cargarBeneficios();
  }

  // ABRIR ARCHIVO DESDE BASE64
  Future<void> _abrirArchivo(int id, String base64Data) async {
    try {
      final bytes = _archivosGuardados[id] ?? base64Decode(base64Data);
      final mimeType = lookupMimeType('', headerBytes: bytes) ?? 'application/octet-stream';
      final blob = html.Blob([bytes], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.window.open(url, "_blank");
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      NotificationBanner.show(
        context,
        "⚠️ Error al abrir el archivo",
        NotificationType.error,
      );
    }
  }

  Future<void> _eliminarBeneficio(int id) async {
    _archivosGuardados.remove(id);
    await _service.eliminar(id);
    await _cargarBeneficios();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.teal.shade700,
        title: const Text(
          "Beneficios Corporativos",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildFormulario(),
            const SizedBox(height: 16),
            Expanded(
              child: _beneficios.isEmpty
                  ? const Center(
                      child: Text(
                        "No hay beneficios registrados.",
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _beneficios.length,
                      itemBuilder: (context, index) =>
                          _buildCard(_beneficios[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormulario() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black26, blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _input("Nombre del beneficio", Icons.card_giftcard, _nombreController),
          const SizedBox(height: 10),
          _input("Descripción", Icons.description, _descripcionController,
              maxLines: 2),
          const SizedBox(height: 10),

          // COMBOBOX DE TIPOS
          DropdownButtonFormField<String>(
            value: _tipoController.text.isNotEmpty ? _tipoController.text : null,
            items: const [
              DropdownMenuItem(value: "Salud y Bienestar", child: Text("Salud y Bienestar")),
              DropdownMenuItem(value: "Desarrollo Profesional", child: Text("Desarrollo Profesional")),
              DropdownMenuItem(value: "Reconocimientos e Incentivos", child: Text("Reconocimientos e Incentivos")),
              DropdownMenuItem(value: "Convenios Comerciales", child: Text("Convenios Comerciales")),
              DropdownMenuItem(value: "Descuentos Internos", child: Text("Descuentos Internos")),
              DropdownMenuItem(value: "Apoyo Familiar", child: Text("Apoyo Familiar")),
              DropdownMenuItem(value: "Bienestar Social y Comunitario", child: Text("Bienestar Social y Comunitario")),
              DropdownMenuItem(value: "Otros Beneficios Corporativos", child: Text("Otros Beneficios Corporativos")),
            ],
            onChanged: (value) {
              setState(() {
                _tipoController.text = value ?? '';
              });
            },
            decoration: InputDecoration(
              labelText: "Tipo de beneficio",
              prefixIcon: Icon(Icons.category, color: Colors.teal.shade700),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.teal),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: Colors.tealAccent.shade700, width: 2),
              ),
            ),
            dropdownColor: Colors.white,
            iconEnabledColor: Colors.teal.shade700,
            style: const TextStyle(
                color: Colors.black87, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),

          _input("Categoría", Icons.class_, _categoriaController),
          const SizedBox(height: 10),

          // 📁 BOTÓN AÑADIR ARCHIVOS
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
                  Icon(Icons.attach_file, color: Colors.teal.shade600, size: 28),
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
          const SizedBox(height: 12),

          Row(
            children: [
              Checkbox(
                value: _activo,
                onChanged: (val) => setState(() => _activo = val ?? true),
                activeColor: Colors.teal,
              ),
              const Text("Activo", style: TextStyle(color: Colors.black87))
            ],
          ),
          const SizedBox(height: 10),

          ElevatedButton.icon(
            onPressed: _guardarBeneficio,
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text(
              "Guardar Beneficio",
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 6,
            ),
          ),
        ],
      ),
    );
  }

  TextField _input(String label, IconData icon, TextEditingController c,
      {int maxLines = 1}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.teal.shade700),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.teal)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: Colors.tealAccent.shade700, width: 2)),
      ),
    );
  }

  Widget _buildCard(Beneficio b) {
    return InkWell(
      onTap: () => _abrirArchivo(b.id, b.imagenUrl),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.teal.shade400, width: 1.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black26, blurRadius: 8, offset: const Offset(0, 3))
          ],
        ),
        child: ListTile(
          leading: const Icon(Icons.folder, color: Colors.teal, size: 40),
          title: Text(
            b.nombre,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          subtitle: Text(
            "Archivo guardado en Base64",
            style: const TextStyle(color: Colors.black54),
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
            onPressed: () => _eliminarBeneficio(b.id),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _tipoController.dispose();
    _categoriaController.dispose();
    super.dispose();
  }
}
