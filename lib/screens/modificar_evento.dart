import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

import '../models/evento.dart' as evento_model;
import '../models/usuario.dart';
import '../services/evento_service.dart';
import '../services/auth_service.dart';
import '../core/notification_banner.dart';

class ModificarEventoScreen extends StatefulWidget {
  const ModificarEventoScreen({super.key});

  @override
  State<ModificarEventoScreen> createState() => _ModificarEventoScreenState();
}

class _ModificarEventoScreenState extends State<ModificarEventoScreen> {
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _fechaController = TextEditingController();

  File? _imagen;
  String? _horaSeleccionada;
  final ImagePicker _picker = ImagePicker();
  bool _modoEdicion = false;
  String? _idEventoEditado;

  final List<String> _horasDisponibles = [
    "08H30", "09H00", "09H30", "10H00", "10H30", "11H00",
    "11H30", "12H00", "12H30", "13H00", "13H30", "14H00",
    "14H30", "15H00", "15H30", "16H00", "16H30"
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final evento_model.Evento? evento =
        ModalRoute.of(context)?.settings.arguments as evento_model.Evento?;

    if (evento != null && !_modoEdicion) {
      _modoEdicion = true;
      _idEventoEditado = evento.id;
      _tituloController.text = evento.titulo;
      _descripcionController.text = evento.descripcion;

      final partes = evento.fecha.split(' - ');
      _fechaController.text = partes[0];
      _horaSeleccionada = partes.length > 1 ? partes[1] : null;

      if (evento.imagenPath != null && evento.imagenPath!.isNotEmpty) {
        _imagen = File(evento.imagenPath!);
      }
    }
  }

  Future<void> _seleccionarImagen() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (!mounted) return;
    if (image != null) {
      setState(() => _imagen = File(image.path));
      NotificationBanner.show(context, 'Imagen seleccionada', NotificationType.success);
    }
  }

  Future<void> _seleccionarFecha() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      locale: const Locale('es', 'ES'),
    );
    if (!mounted) return;
    if (picked != null) {
      setState(() {
        _fechaController.text = picked.toString().split(' ')[0];
      });
    }
  }

  Future<void> _guardarEvento() async {
    if (_tituloController.text.isEmpty ||
        _descripcionController.text.isEmpty ||
        _fechaController.text.isEmpty ||
        _horaSeleccionada == null) {
      NotificationBanner.show(context, 'Completa todos los campos', NotificationType.error);
      return;
    }

    final eventoService = context.read<EventoService>();
    final authService = context.read<AuthService>();
    final Usuario? usuarioActual = authService.currentUser;

    if (usuarioActual == null) {
      NotificationBanner.show(context, 'No hay sesión activa', NotificationType.error);
      return;
    }

    final evento = evento_model.Evento(
      id: _modoEdicion
          ? _idEventoEditado!
          : DateTime.now().millisecondsSinceEpoch.toString(),
      titulo: _tituloController.text.trim(),
      descripcion: _descripcionController.text.trim(),
      fecha: "${_fechaController.text} - $_horaSeleccionada",
      creadoPor: usuarioActual.nombre,
      planta: usuarioActual.areaUsuario,
      horaEvento: _horaSeleccionada ?? '',
      imagenPath: _imagen?.path,
      archivoPath: null,
    );

    try {
      if (_modoEdicion) {
        await eventoService.modificarEvento(evento.id, evento, usuarioActual);
        NotificationBanner.show(context, 'Evento modificado exitosamente', NotificationType.success);
      } else {
        await eventoService.crearEvento(evento, usuarioActual);
        NotificationBanner.show(context, 'Evento creado exitosamente', NotificationType.success);
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      NotificationBanner.show(context, 'Error: ${e.toString()}', NotificationType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _modoEdicion ? 'Editar Evento' : 'Crear Evento',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF3B82F6),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _tituloController,
              decoration: const InputDecoration(
                labelText: 'Título *',
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descripcionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Descripción *',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _fechaController,
              readOnly: true,
              onTap: _seleccionarFecha,
              decoration: const InputDecoration(
                labelText: 'Fecha *',
                prefixIcon: Icon(Icons.calendar_today),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _horaSeleccionada,
              items: _horasDisponibles
                  .map((hora) => DropdownMenuItem(value: hora, child: Text(hora)))
                  .toList(),
              onChanged: (valor) => setState(() => _horaSeleccionada = valor),
              decoration: const InputDecoration(
                labelText: 'Hora del evento *',
                prefixIcon: Icon(Icons.access_time),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _seleccionarImagen,
              icon: const Icon(Icons.image),
              label: Text(_imagen == null ? 'Añadir Imagen' : 'Cambiar Imagen'),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _guardarEvento,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                _modoEdicion ? 'Guardar Cambios' : 'Crear Evento',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    _fechaController.dispose();
    super.dispose();
  }
}
