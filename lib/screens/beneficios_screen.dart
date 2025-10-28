import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/beneficio.dart';
import '../models/usuario.dart';
import '../services/beneficio_service.dart';
import '../services/auth_service.dart';

class BeneficiosScreen extends StatefulWidget {
  const BeneficiosScreen({super.key});

  @override
  State<BeneficiosScreen> createState() => _BeneficiosScreenState();
}

class _BeneficiosScreenState extends State<BeneficiosScreen> {
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _tipoCtrl = TextEditingController();
  final _categoriaCtrl = TextEditingController();
  bool _activo = true;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        Provider.of<BeneficioService>(context, listen: false).obtenerBeneficios());
  }

  // CREAR NUEVO BENEFICIO
  Future<void> _crearBeneficio() async {
    final beneficioService = context.read<BeneficioService>();
    final authService = context.read<AuthService>();
    final usuarioActual = authService.currentUser;

    if (usuarioActual == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("NO HAY USUARIO AUTENTICADO")),
      );
      return;
    }

    if (_nombreCtrl.text.isEmpty ||
        _descripcionCtrl.text.isEmpty ||
        _tipoCtrl.text.isEmpty ||
        _categoriaCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("DEBE COMPLETAR TODOS LOS CAMPOS")),
      );
      return;
    }

    setState(() => _cargando = true);

    final nuevoBeneficio = Beneficio(
      id: DateTime.now().millisecondsSinceEpoch,
      nombre: _nombreCtrl.text.trim(),
      descripcion: _descripcionCtrl.text.trim(),
      tipo: _tipoCtrl.text.trim(),
      categoria: _categoriaCtrl.text.trim(),
      imagenUrl: "",
      fechaPublicacion: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      activo: _activo,
    );

    try {
      await beneficioService.crearBeneficio(nuevoBeneficio, usuarioActual);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ BENEFICIO CREADO CORRECTAMENTE")),
      );
      _limpiarCampos();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ ERROR AL CREAR BENEFICIO: $e")),
      );
    } finally {
      setState(() => _cargando = false);
    }
  }

  // ELIMINAR BENEFICIO
  Future<void> _eliminarBeneficio(String id) async {
    final beneficioService = context.read<BeneficioService>();
    setState(() => _cargando = true);
    try {
      await beneficioService.eliminarBeneficio(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🗑️ BENEFICIO ELIMINADO CORRECTAMENTE")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ ERROR AL ELIMINAR BENEFICIO: $e")),
      );
    } finally {
      setState(() => _cargando = false);
    }
  }

  void _limpiarCampos() {
    _nombreCtrl.clear();
    _descripcionCtrl.clear();
    _tipoCtrl.clear();
    _categoriaCtrl.clear();
    setState(() => _activo = true);
  }

  @override
  Widget build(BuildContext context) {
    final beneficioService = context.watch<BeneficioService>();
    final beneficios = beneficioService.beneficios;

    return Scaffold(
      appBar: AppBar(
        title: const Text("BENEFICIOS CORPORATIVOS"),
        backgroundColor: Colors.teal,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () => beneficioService.obtenerBeneficios(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ExpansionTile(
              title: const Text("AGREGAR NUEVO BENEFICIO"),
              children: [
                TextField(
                    controller: _nombreCtrl,
                    decoration: const InputDecoration(labelText: "NOMBRE")),
                TextField(
                    controller: _descripcionCtrl,
                    decoration: const InputDecoration(labelText: "DESCRIPCIÓN")),
                TextField(
                    controller: _tipoCtrl,
                    decoration: const InputDecoration(labelText: "TIPO")),
                TextField(
                    controller: _categoriaCtrl,
                    decoration: const InputDecoration(labelText: "CATEGORÍA")),
                Row(
                  children: [
                    Checkbox(
                      value: _activo,
                      onChanged: (v) => setState(() => _activo = v ?? true),
                    ),
                    const Text("ACTIVO"),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _cargando ? null : _crearBeneficio,
                  icon: const Icon(Icons.save),
                  label: const Text("GUARDAR BENEFICIO"),
                ),
              ],
            ),
            const Divider(),
            beneficios.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(top: 100),
                    child: Center(child: Text("NO HAY BENEFICIOS REGISTRADOS")),
                  )
                : Column(
                    children: beneficios.map((b) {
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: Text(b.nombre,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              "${b.descripcion}\n${b.tipo} - ${b.categoria}"),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: _cargando
                                ? null
                                : () => _eliminarBeneficio(b.id.toString()),
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
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _tipoCtrl.dispose();
    _categoriaCtrl.dispose();
    super.dispose();
  }
}
