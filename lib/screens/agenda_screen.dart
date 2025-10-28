import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    // Cargar citas al abrir la pantalla
    Future.microtask(() =>
        Provider.of<AgendaService>(context, listen: false).obtenerCitas());
  }


  // Crear Nueva Cita
  Future<void> _crearCita() async {
    final agendaService = context.read<AgendaService>();
    final authService = context.read<AuthService>();
    final usuarioActual = authService.currentUser;

    if (usuarioActual == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No hay usuario autenticado")),
      );
      return;
    }

    if (_tituloCtrl.text.isEmpty || _descripcionCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor llena todos los campos")),
      );
      return;
    }

    setState(() => _cargando = true);

    final nuevaCita = Agenda(
      id: DateTime.now().millisecondsSinceEpoch,
      titulo: _tituloCtrl.text.trim(),
      descripcion: _descripcionCtrl.text.trim(),
      fecha: DateTime.now(),
      horaInicio: _horaInicioCtrl.text.trim(),
      horaFin: _horaFinCtrl.text.trim(),
      recordatorio: _recordatorioCtrl.text.trim(),
    );

    try {
      await agendaService.crearCita(nuevaCita, usuarioActual);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Cita creada correctamente")),
      );
      _limpiarCampos();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error al crear cita: $e")),
      );
    } finally {
      setState(() => _cargando = false);
    }
  }

  
  // Eliminar Cita
  Future<void> _eliminarCita(String id) async {
    final service = context.read<AgendaService>();
    setState(() => _cargando = true);
    try {
      await service.eliminarCita(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🗑️ Cita eliminada correctamente")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error al eliminar cita: $e")),
      );
    } finally {
      setState(() => _cargando = false);
    }
  }

  void _limpiarCampos() {
    _tituloCtrl.clear();
    _descripcionCtrl.clear();
    _horaInicioCtrl.clear();
    _horaFinCtrl.clear();
    _recordatorioCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final agendaService = context.watch<AgendaService>();
    final citas = agendaService.citas;

    return Scaffold(
      appBar: AppBar(title: const Text('🗓️ Agenda de Citas')),
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
                TextField(
                    controller: _recordatorioCtrl,
                    decoration:
                        const InputDecoration(labelText: "Recordatorio")),
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
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: _cargando
                                ? null
                                : () => _eliminarCita(c.id.toString()),
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
