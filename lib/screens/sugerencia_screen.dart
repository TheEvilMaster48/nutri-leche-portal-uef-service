import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
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

  List<File> images = [];

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
    // _cargarSugerencias(service);
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

  Future pickImage() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.camera);
      if (image == null) return;
      final imageTemp = File(image.path);
      //agregar a la lista
      setState(() {
        images.add(imageTemp);
      });
    } on PlatformException catch (e) {
      print('Failed to pick image: $e');
    }
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


    setState(() => _enviando = true);


    Future<List<String>> convertirImagenesABase64(List<File> imagenes) async {
        return Future.wait(imagenes.map((file) async {
          final bytes = await file.readAsBytes();
          return base64Encode(bytes);
        }));
      }

    // 🔸 Armar el cuerpo JSON (sin id)
    var map = new Map<String, dynamic>();
    map['categoria'] = _categoria;
    map['titulo'] = _tituloCtrl.text;
    map['descripcion'] = _descCtrl.text;
    map['fecha'] = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(DateTime.now());
    final imagenesBase64 = await convertirImagenesABase64(images);
    map["imagenes_base64"] = imagenesBase64;

    try {
      // 🔸 Petición HTTP al webservice
      final response = await http.post(
        Uri.parse("https://servicioslsa.nutri.com.ec/nutrisoft/rest/appOficial/api/v1/insertar_sugerencia"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(map),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        NotificationBanner.show(
          context,
          'Sugerencia enviada correctamente.',
          NotificationType.success,
        );
      } else {
        NotificationBanner.show(
          context,
          'Error al enviar sugerencia: ${response.statusCode}',
          NotificationType.error,
        );
      }
    } catch (e) {
      NotificationBanner.show(
        context,
        'Error de conexión: $e',
        NotificationType.error,
      );
    }

    setState(() {
      _tituloCtrl.clear();
      _descCtrl.clear();
      _archivoNombre = null;
      _archivoBytes = null;
      _categoria = null;
      _enviando = false;
      images = [];
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
                      'Tu opinión es confidencial. Nutri valora tus ideas.',
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

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor:
                      images.length >= 5 ? Colors.grey : Colors.teal[700],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: images.length >= 5
                        ? null
                        : () async {
                      await pickImage();
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_alt),
                        Text(" Adjuntar fotos (${images.length}/5)"),
                      ],
                    ),
                  ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  child: GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    children: List.generate(images.length, (index) {
                      return Image.file(images[index]);
                    }),
                  ),
                ),
                  const SizedBox(height: 25),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor:
                      images.length >= 5 ? Colors.grey : Colors.teal[700],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _enviando ? null : _enviarSugerencia,

                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send),
                        Text(" Enviar Sugerencia"),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }
}
