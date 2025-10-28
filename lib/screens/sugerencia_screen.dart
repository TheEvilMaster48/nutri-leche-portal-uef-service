import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  bool _cargando = true;
  List<Sugerencia> _sugerencias = [];

  final _tituloCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _categoriaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarSugerencias();
    });
  }

  Future<void> _cargarSugerencias() async {
    try {
      final service = context.read<SugerenciaService>();
      final data = await service.listarSugerencias(context);
      setState(() {
        _sugerencias = data;
        _cargando = false;
      });
    } catch (e) {
      setState(() => _cargando = false);
    }
  }

  void _mostrarFormulario([Sugerencia? sugerencia]) {
    _tituloCtrl.text = sugerencia?.titulo ?? '';
    _descCtrl.text = sugerencia?.descripcion ?? '';
    _categoriaCtrl.text = sugerencia?.categoria ?? '';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(sugerencia == null
            ? 'Nueva Sugerencia'
            : 'Editar Sugerencia'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _tituloCtrl,
                decoration:
                    const InputDecoration(labelText: 'Título de la sugerencia'),
              ),
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 3,
              ),
              TextField(
                controller: _categoriaCtrl,
                decoration: const InputDecoration(labelText: 'Categoría'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final service = context.read<SugerenciaService>();
              final nueva = Sugerencia(
                id: sugerencia?.id ?? '',
                categoria: _categoriaCtrl.text.trim(),
                titulo: _tituloCtrl.text.trim(),
                descripcion: _descCtrl.text.trim(),
                fecha: DateTime.now(),
                imagenPath: null,
              );

              if (sugerencia == null) {
                await service.crearSugerencia(context, nueva);
              } else {
                // Si hay actualización, puedes implementar PUT igual que en otros servicios
                await service.crearSugerencia(context, nueva);
              }

              if (mounted) {
                Navigator.pop(context);
                await _cargarSugerencias();
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.teal.shade700,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/menu');
          },
        ),
        title: const Text(
          'Buzón de Sugerencias',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal.shade700,
        onPressed: () => _mostrarFormulario(),
        child: const Icon(Icons.add),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _sugerencias.isEmpty
              ? const Center(
                  child: Text(
                    'No hay sugerencias registradas.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sugerencias.length,
                  itemBuilder: (context, index) {
                    final s = _sugerencias[index];
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.shade600,
                          child:
                              const Icon(Icons.lightbulb_outline, color: Colors.white),
                        ),
                        title: Text(
                          s.titulo,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${s.descripcion}\nCategoría: ${s.categoria}\nFecha: ${DateFormat('dd/MM/yyyy').format(s.fecha)}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Confirmar eliminación'),
                                content: Text('¿Eliminar la sugerencia "${s.titulo}"?'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancelar')),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Eliminar')),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              final service =
                                  context.read<SugerenciaService>();
                              await service.eliminarSugerencia(context, s.id);
                              await _cargarSugerencias();
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
