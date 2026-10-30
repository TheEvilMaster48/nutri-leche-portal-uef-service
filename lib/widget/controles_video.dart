import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

/// Controles para los videos de los eventos: reproducir/pausar, retroceder y
/// adelantar [salto], y una barra de progreso que se puede arrastrar.
///
/// Se dibuja encima del `Video` (que va con `NoVideoControls`) y se usa igual
/// en el detalle y en pantalla completa, así el video se maneja de la misma
/// forma en los dos lugares.
class ControlesVideo extends StatefulWidget {
  const ControlesVideo({
    super.key,
    required this.player,
    this.salto = const Duration(seconds: 10),
  });

  final Player player;
  final Duration salto;

  @override
  State<ControlesVideo> createState() => _ControlesVideoState();
}

class _ControlesVideoState extends State<ControlesVideo> {
  final List<StreamSubscription> _subs = [];

  late bool _reproduciendo = widget.player.state.playing;
  late Duration _posicion = widget.player.state.position;
  late Duration _duracion = widget.player.state.duration;

  /// Posición mientras el usuario arrastra la barra; `null` si no arrastra.
  /// Sin esto la barra salta de vuelta con cada actualización del reproductor.
  double? _arrastreMs;

  @override
  void initState() {
    super.initState();
    final stream = widget.player.stream;
    _subs.addAll([
      stream.playing.listen((v) => _actualizar(() => _reproduciendo = v)),
      stream.position.listen((v) => _actualizar(() => _posicion = v)),
      stream.duration.listen((v) => _actualizar(() => _duracion = v)),
    ]);
  }

  void _actualizar(VoidCallback cambio) {
    if (mounted) setState(cambio);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> _saltar(Duration delta) async {
    var destino = _posicion + delta;
    if (destino < Duration.zero) destino = Duration.zero;
    if (_duracion > Duration.zero && destino > _duracion) destino = _duracion;
    await widget.player.seek(destino);
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = _duracion.inMilliseconds.toDouble();
    final actualMs = (_arrastreMs ?? _posicion.inMilliseconds.toDouble()).clamp(
      0.0,
      totalMs > 0 ? totalMs : 0.0,
    );
    final segundosSalto = widget.salto.inSeconds;

    return Stack(
      children: [
        // Botones al centro: retroceder, reproducir/pausar, adelantar.
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _boton(
                icono: Icons.replay_10,
                tooltip: 'Retroceder $segundosSalto s',
                alTocar: () => _saltar(-widget.salto),
              ),
              const SizedBox(width: 20),
              _boton(
                icono: _reproduciendo ? Icons.pause : Icons.play_arrow,
                tooltip: _reproduciendo ? 'Pausar' : 'Reproducir',
                tamano: 34,
                alTocar: () => widget.player.playOrPause(),
              ),
              const SizedBox(width: 20),
              _boton(
                icono: Icons.forward_10,
                tooltip: 'Adelantar $segundosSalto s',
                alTocar: () => _saltar(widget.salto),
              ),
            ],
          ),
        ),

        // Barra de progreso con los tiempos.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black54, Colors.transparent],
              ),
            ),
            child: Row(
              children: [
                _tiempo(Duration(milliseconds: actualMs.round())),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14,
                      ),
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white30,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      min: 0,
                      max: totalMs > 0 ? totalMs : 1,
                      value: totalMs > 0 ? actualMs : 0,
                      onChanged:
                          totalMs > 0
                              ? (v) => setState(() => _arrastreMs = v)
                              : null,
                      onChangeEnd: (v) async {
                        await widget.player.seek(
                          Duration(milliseconds: v.round()),
                        );
                        _actualizar(() => _arrastreMs = null);
                      },
                    ),
                  ),
                ),
                _tiempo(_duracion),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _boton({
    required IconData icono,
    required String tooltip,
    required VoidCallback alTocar,
    double tamano = 28,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: alTocar,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            shape: BoxShape.circle,
          ),
          child: Icon(icono, color: Colors.white, size: tamano),
        ),
      ),
    );
  }

  Widget _tiempo(Duration d) {
    return Text(
      formatoTiempo(d),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// "m:ss", o "h:mm:ss" si pasa de una hora.
String formatoTiempo(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}
