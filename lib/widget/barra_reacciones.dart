import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../base/base.dart';
import '../models/reaccion.dart';
import '../services/auth_service.dart';
import '../services/reaccion_service.dart';

/// Fila de reacciones (👍 ❤️ 🎉 😂 😮 😢) para el detalle de eventos y
/// cumpleaños.
///
/// El usuario tiene una sola reacción activa por contenido: tocar otra la
/// mueve, tocar la misma la quita.
class BarraReacciones extends StatefulWidget {
  const BarraReacciones({
    super.key,
    required this.origen,
    required this.idContenido,
    this.titulo = '¿Qué te parece?',
  });

  /// [OrigenReaccion.evento] o [OrigenReaccion.cumpleanios].
  final String origen;

  /// idEvento / idCumpleanios.
  final int idContenido;

  final String titulo;

  @override
  State<BarraReacciones> createState() => _BarraReaccionesState();
}

class _BarraReaccionesState extends State<BarraReacciones> {
  int _idUsuario = 0;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _inicializar());
  }

  Future<void> _inicializar() async {
    if (!mounted) return;

    int id = 0;
    try {
      id = context.read<AuthService>().currentUser?.id ?? 0;
    } catch (e) {
      debugPrint('REACCIONES: no se pudo leer el usuario del AuthService: $e');
    }

    if (id == 0) {
      // El AuthService puede venir vacío (p. ej. al abrir el detalle desde una
      // notificación push). La sesión persistida vive en 'currentUser' como
      // JSON — no existe ninguna llave 'idUsuario' en SharedPreferences.
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('currentUser');
        if (raw != null && raw.isNotEmpty) {
          final decoded = json.decode(raw);
          if (decoded is Map) {
            final valor = decoded['id'] ?? decoded['idUsuario'];
            id = valor is int ? valor : int.tryParse('$valor') ?? 0;
          }
        }
      } catch (e) {
        debugPrint('REACCIONES: no se pudo leer la sesión guardada: $e');
      }
    }

    if (id == 0) {
      debugPrint('REACCIONES: sin idUsuario, no se enviará nada al servidor');
    }

    if (!mounted) return;
    setState(() => _idUsuario = id);

    await context.read<ReaccionService>().cargar(
          origen: widget.origen,
          idContenido: widget.idContenido,
          idUsuario: id,
        );
  }

  Future<void> _reaccionar(TipoReaccion tipo) async {
    if (_enviando) return;
    setState(() => _enviando = true);

    final ok = await context.read<ReaccionService>().alternar(
          origen: widget.origen,
          idContenido: widget.idContenido,
          idUsuario: _idUsuario,
          tipo: tipo,
        );

    if (!mounted) return;
    setState(() => _enviando = false);

    if (!ok) {
      // La reacción queda guardada en el dispositivo; se avisa que no se pudo
      // sincronizar para que el usuario sepa que puede no verse en el portal.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu reacción se guardó, pero no se pudo sincronizar.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.idContenido <= 0) return const SizedBox.shrink();

    final resumen = context
        .watch<ReaccionService>()
        .resumen(widget.origen, widget.idContenido);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Base().COLOR_AZUL_CORP.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.emoji_emotions_outlined,
                  color: Base().COLOR_AZUL_CORP,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.titulo,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Base().COLOR_AZUL_CORP,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (resumen.total > 0)
                Text(
                  resumen.total == 1
                      ? '1 reacción'
                      : '${resumen.total} reacciones',
                  style: TextStyle(fontSize: 12, color: Base().COLOR_GRIS),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Los 6 tipos siempre se muestran (👍 ❤️ 🎉 😂 😮 😢). El espaciado es
          // justo para que quepan en una sola fila en pantallas de 360dp; si
          // varios traen conteo, el Wrap los pasa a una segunda fila.
          Wrap(
            spacing: 6,
            runSpacing: 8,
            children: TipoReaccion.values.map((tipo) {
              final activa = resumen.miReaccion == tipo;
              final conteo = resumen.conteoDe(tipo);

              return _ChipReaccion(
                tipo: tipo,
                activa: activa,
                conteo: conteo,
                onTap: () => _reaccionar(tipo),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ChipReaccion extends StatelessWidget {
  const _ChipReaccion({
    required this.tipo,
    required this.activa,
    required this.conteo,
    required this.onTap,
  });

  final TipoReaccion tipo;
  final bool activa;
  final int conteo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final azul = Base().COLOR_AZUL_CORP;

    return Tooltip(
      message: tipo.etiqueta,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: activa ? azul.withOpacity(0.12) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: activa ? azul : const Color(0xFFE0E0E0),
              width: activa ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tipo.emoji, style: const TextStyle(fontSize: 18)),
              if (conteo > 0) ...[
                const SizedBox(width: 6),
                Text(
                  conteo.toString(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: activa ? FontWeight.bold : FontWeight.w600,
                    color: activa ? azul : Base().COLOR_GRIS,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
