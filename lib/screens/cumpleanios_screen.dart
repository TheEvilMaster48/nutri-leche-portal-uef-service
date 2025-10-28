import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/notification_banner.dart';
import '../models/cumpleanios.dart';
import '../services/cumpleanios_service.dart';
import 'calendario_evento_screen.dart';

class CumpleaniosScreen extends StatefulWidget {
  const CumpleaniosScreen({super.key});

  @override
  State<CumpleaniosScreen> createState() => _CumpleaniosScreenState();
}

class _CumpleaniosScreenState extends State<CumpleaniosScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _apellidoController = TextEditingController();
  final TextEditingController _correoController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  DateTime? _fechaSeleccionada;
  String? _plantaSeleccionada;

  final List<String> _plantas = [
    'Planta Administrativa',
    'Planta de Recursos Humanos',
    'Planta Bodega',
    'Planta de Producción',
    'Planta de Ventas',
  ];

  List<Cumpleanios> _cumpleanios = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarCumpleanios();
  }

  // CARGAR CUMPLEAÑOS DESDE API
  Future<void> _cargarCumpleanios() async {
    try {
      final service = context.read<CumpleaniosService>();
      final data = await service.listarCumpleanios(context);
      setState(() {
        _cumpleanios = data;
        _cargando = false;
      });
    } catch (e) {
      setState(() => _cargando = false);
      NotificationBanner.show(
        context,
        'Error al cargar cumpleaños: $e',
        NotificationType.error,
      );
    }
  }

  // GUARDAR NUEVO CUMPLEAÑOS
  Future<void> _guardarCumpleanio() async {
    if (!_formKey.currentState!.validate() || _fechaSeleccionada == null) {
      NotificationBanner.show(
        context,
        'Completa todos los campos.',
        NotificationType.error,
      );
      return;
    }

    final nuevo = Cumpleanios(
      nombre: _nombreController.text.trim(),
      apellido: _apellidoController.text.trim(),
      correo: _correoController.text.trim(),
      telefono: _telefonoController.text.trim(),
      planta: _plantaSeleccionada ?? '',
      fechaNacimiento: _fechaSeleccionada!,
    );

    try {
      final service = context.read<CumpleaniosService>();
      await service.crearCumpleanio(context, nuevo);

      NotificationBanner.show(
        context,
        'Cumpleaños registrado correctamente.',
        NotificationType.success,
      );

      _nombreController.clear();
      _apellidoController.clear();
      _correoController.clear();
      _telefonoController.clear();
      _plantaSeleccionada = null;
      _fechaSeleccionada = null;

      await _cargarCumpleanios();

      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CalendarioEventosScreen()),
        );
      }
    } catch (e) {
      NotificationBanner.show(
        context,
        'Error al guardar cumpleaños: $e',
        NotificationType.error,
      );
    }
  }

  // ELIMINAR CUMPLEAÑOS
  Future<void> _eliminarCumpleanio(int id) async {
    try {
      final service = context.read<CumpleaniosService>();
      await service.eliminarCumpleanio(context, id);
      await _cargarCumpleanios();
      NotificationBanner.show(
        context,
        'Cumpleaños eliminado correctamente.',
        NotificationType.success,
      );
    } catch (e) {
      NotificationBanner.show(
        context,
        'Error al eliminar cumpleaños: $e',
        NotificationType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.teal.shade700,
        title: const Text(
          'Registrar Cumpleaños',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nombreController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) => v!.isEmpty ? 'Campo obligatorio' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _apellidoController,
                          decoration: const InputDecoration(
                            labelText: 'Apellido',
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (v) => v!.isEmpty ? 'Campo obligatorio' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _correoController,
                          decoration: const InputDecoration(
                            labelText: 'Correo',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (v) => v!.isEmpty ? 'Campo obligatorio' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _telefonoController,
                          decoration: const InputDecoration(
                            labelText: 'Teléfono',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          validator: (v) => v!.isEmpty ? 'Campo obligatorio' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Planta / Departamento',
                            prefixIcon: Icon(Icons.apartment_outlined),
                          ),
                          value: _plantaSeleccionada,
                          items: _plantas.map((planta) {
                            return DropdownMenuItem(
                              value: planta,
                              child: Text(planta),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _plantaSeleccionada = v),
                          validator: (v) => v == null ? 'Selecciona una planta' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _fechaSeleccionada == null
                                    ? 'Selecciona la fecha de nacimiento'
                                    : 'Fecha seleccionada: ${DateFormat('dd/MM/yyyy').format(_fechaSeleccionada!)}',
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.calendar_month),
                              onPressed: () async {
                                final fecha = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime(2000),
                                  firstDate: DateTime(1900),
                                  lastDate: DateTime.now(),
                                );
                                if (fecha != null) {
                                  setState(() => _fechaSeleccionada = fecha);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _guardarCumpleanio,
                          icon: const Icon(Icons.save_alt),
                          label: const Text('Guardar Información'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    'Cumpleaños registrados',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  if (_cumpleanios.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: Text(
                          'No hay cumpleaños registrados.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  if (_cumpleanios.isNotEmpty)
                    ..._cumpleanios.map((c) {
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: const Icon(Icons.cake, color: Colors.pink),
                          title: Text(c.nombreCompleto),
                          subtitle: Text(
                            '${c.planta}\n${DateFormat('dd/MM/yyyy').format(c.fechaNacimiento)}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _eliminarCumpleanio(c.hashCode),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
