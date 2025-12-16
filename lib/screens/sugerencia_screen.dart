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

    var map = <String, dynamic>{};
    map['categoria'] = _categoria;
    map['titulo'] = _tituloCtrl.text;
    map['descripcion'] = _descCtrl.text;
    map['fecha'] = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(DateTime.now());
    final imagenesBase64 = await convertirImagenesABase64(images);
    map["imagenes_base64"] = imagenesBase64;

    try {
      // HTTP al Webservice
      final response = await http.post(
        Uri.parse(
            "https://servicioslsaqas.nutri.com.ec/nutrisoft/rest/appOficial/api/v1/insertar_sugerencia"),
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
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          // Fondo azul superior con curva
          ClipPath(
            clipper: SugerenciaWaveClipper(),
            child: Container(
              height: 120,
              decoration: const BoxDecoration(
                color: Color(0xFF0052A3),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'BUZÓN DE SUGERENCIAS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Card informativo - CAMBIO AQUÍ: Color de fondo a gris
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0E0E0), // CAMBIADO DE 0xFFE8F4F8 A GRIS
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.mail_outline,
                                    size: 48,
                                    color: const Color(0xFF0052A3),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    '🗳️ Envío anónimo',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0052A3),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Tu opinión es confidencial. Nutri valora tus ideas.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF666666),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Formulario en card blanco
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // CAMPO CATEGORÍA
                                  const Text(
                                    'Categoría',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0052A3),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    initialValue: _categoria,
                                    decoration: InputDecoration(
                                      hintText: 'Selecciona una categoría',
                                      hintStyle: const TextStyle(
                                        color: Color(0xFF999999),
                                        fontSize: 14,
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFFF5F5F5),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF0052A3),
                                          width: 2,
                                        ),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Colors.red,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.arrow_drop_down,
                                      color: Color(0xFF0052A3),
                                    ),
                                    items: _categorias
                                        .map((cat) => DropdownMenuItem(
                                              value: cat,
                                              child: Text(
                                                cat,
                                                style: const TextStyle(fontSize: 14),
                                              ),
                                            ))
                                        .toList(),
                                    onChanged: (v) => setState(() => _categoria = v),
                                    validator: (v) =>
                                        v == null ? 'Seleccione una categoría' : null,
                                  ),
                                  const SizedBox(height: 20),

                                  // CAMPO TÍTULO
                                  const Text(
                                    'Título',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0052A3),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _tituloCtrl,
                                    style: const TextStyle(fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'Escribe el título de tu sugerencia',
                                      hintStyle: const TextStyle(
                                        color: Color(0xFF999999),
                                        fontSize: 14,
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFFF5F5F5),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF0052A3),
                                          width: 2,
                                        ),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Colors.red,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    validator: (v) =>
                                        v == null || v.isEmpty ? 'Ingrese un título' : null,
                                  ),
                                  const SizedBox(height: 20),

                                  // CAMPO DESCRIPCIÓN
                                  const Text(
                                    'Descripción',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0052A3),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _descCtrl,
                                    maxLines: 5,
                                    style: const TextStyle(fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'Describe tu sugerencia en detalle...',
                                      hintStyle: const TextStyle(
                                        color: Color(0xFF999999),
                                        fontSize: 14,
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFFF5F5F5),
                                      contentPadding: const EdgeInsets.all(16),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF0052A3),
                                          width: 2,
                                        ),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Colors.red,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    validator: (v) => v == null || v.isEmpty
                                        ? 'Ingrese una descripción'
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Botón Adjuntar fotos
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: images.length >= 5 ? null : pickImage,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.camera_alt,
                                          color: images.length >= 5
                                              ? Colors.grey
                                              : const Color(0xFF0052A3),
                                          size: 24,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          "Adjuntar fotos (${images.length}/5)",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: images.length >= 5
                                                ? Colors.grey
                                                : const Color(0xFF0052A3),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Grid de imágenes
                            if (images.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                  ),
                                  itemCount: images.length,
                                  itemBuilder: (context, index) {
                                    return Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.file(
                                            images[index],
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                          ),
                                        ),
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                images.removeAt(index);
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),

                            // Botón Enviar
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0052A3),
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  shadowColor: Colors.black.withOpacity(0.2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  disabledBackgroundColor: Colors.grey[300],
                                ),
                                onPressed: _enviando ? null : _enviarSugerencia,
                                child: _enviando
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: const [
                                          Icon(Icons.send, size: 20),
                                          SizedBox(width: 10),
                                          Text(
                                            "Enviar Sugerencia",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SugerenciaWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();

    path.lineTo(0, size.height - 30);

    var firstControlPoint = Offset(size.width * 0.25, size.height - 40);
    var firstEndPoint = Offset(size.width * 0.5, size.height - 30);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    var secondControlPoint = Offset(size.width * 0.75, size.height - 20);
    var secondEndPoint = Offset(size.width, size.height - 30);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}