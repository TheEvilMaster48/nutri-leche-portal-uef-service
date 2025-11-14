import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cumpleanios.dart';
import '../services/cumpleanios_service.dart';
import '../core/notification_banner.dart';
import '../services/auth_service.dart';
import 'detalle_cumpleanios_screen.dart';
import 'menu.dart';

class CumpleaniosScreen extends StatefulWidget {
  const CumpleaniosScreen({super.key});

  @override
  State<CumpleaniosScreen> createState() => _CumpleaniosScreenState();
}

class _CumpleaniosScreenState extends State<CumpleaniosScreen> {
  bool _cargando = true;
  int idUsuario = 0;

  @override
  void initState() {
    super.initState();
    _cargarCumpleanios();
  }

  Future<void> _cargarCumpleanios() async {
    final cumpleService = context.read<CumpleaniosService>();

    try {
      final authService = context.read<AuthService>();
      final usuarioActual = authService.currentUser;

      if (usuarioActual != null && usuarioActual.id != 0) {
        idUsuario = usuarioActual.id;
      } else {
        final prefs = await SharedPreferences.getInstance();
        idUsuario = prefs.getInt('idUsuario') ?? 0;
      }
    } catch (e) {
      debugPrint("No se pudo obtener el idUsuario: $e");
    }

    if (idUsuario == 0) {
      NotificationBanner.show(
        context,
        "No se encontró un usuario válido para cargar los cumpleaños.",
        NotificationType.error,
      );
      setState(() => _cargando = false);
      return;
    }

    await cumpleService.obtenerCumpleanios(idUsuario: idUsuario);
    setState(() => _cargando = false);
  }

  DateTime _parseFecha(String fecha) {
    try {
      if (fecha.isEmpty || fecha == '0000-00-00') return DateTime.now();
      if (fecha.contains('/')) {
        final partes = fecha.split('/');
        if (partes.length == 3) {
          final dia = int.tryParse(partes[0]) ?? 1;
          final mes = int.tryParse(partes[1]) ?? 1;
          final anio = int.tryParse(partes[2]) ?? DateTime.now().year;
          return DateTime(anio, mes, dia);
        }
      }
      return DateTime.tryParse(fecha) ?? DateTime.now();
    } catch (_) {
      return DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cumpleanios = context.watch<CumpleaniosService>().cumpleanios;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFF4081),
              Color(0xFFFF80AB),
              Color(0xFFFFC1E3),
              Color(0xFFFFFFFF)
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF4081), Color(0xFFFF80AB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const MenuScreen()),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Cumpleaños Corporativos',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _cargando
                    ? const Center(child: CircularProgressIndicator())
                    : Padding(
                        padding: const EdgeInsets.all(12),
                        child: cumpleanios.isEmpty
                            ? const Center(
                                child: Text(
                                  'No hay cumpleaños disponibles actualmente.',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.black54,
                                  ),
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: () async {
                                  await context
                                      .read<CumpleaniosService>()
                                      .obtenerCumpleanios(
                                          idUsuario: idUsuario);
                                },
                                child: ListView.builder(
                                  itemCount: cumpleanios.length,
                                  itemBuilder: (context, i) {
                                    final cumple = cumpleanios[i];
                                    return _CumpleItem(
                                      cumple: cumple,
                                      idUsuario: idUsuario,
                                      parseFecha: _parseFecha,
                                    );
                                  },
                                ),
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CumpleItem extends StatelessWidget {
  const _CumpleItem({
    required this.cumple,
    required this.idUsuario,
    required this.parseFecha,
  });
  final Cumpleanios cumple;
  final int idUsuario;
  final DateTime Function(String) parseFecha;

  @override
  Widget build(BuildContext context) {
    final textoEstado = cumple.estado == 0 ? 'Pendiente' : 'Leído';
    final colorEstado = cumple.estado == 0 ? Colors.orange : Colors.green;
    final fechaFormateada = parseFecha(cumple.fecha);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      elevation: 3,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        leading: const Icon(Icons.cake, color: Color(0xFFFF4081)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                cumple.titulo,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFF4081),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              textoEstado,
              style: TextStyle(
                color: colorEstado,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${fechaFormateada.day.toString().padLeft(2, '0')}/${fechaFormateada.month.toString().padLeft(2, '0')}/${fechaFormateada.year}',
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetalleCumpleaniosScreen(cumple: cumple),
            ),
          );

          if (cumple.estado == 0) {
            cumple.estado = 1;
            Future.microtask(() {
              context.read<CumpleaniosService>().marcarCumpleaniosComoVisto(
                    idUsuario: idUsuario,
                    idCumpleanios: cumple.idCumpleanios,
                  );
            });
          }
        },
      ),
    );
  }
}
