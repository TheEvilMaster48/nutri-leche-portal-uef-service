import 'dart:async';
import 'package:flutter/material.dart';
import '../models/notification_item.dart';

// TIPOS DE NOTIFICACIÓN DISPONIBLES
enum NotificationType { success, error, info, warning }

// CLASE PRINCIPAL DEL BANNER FLOTANTE
class NotificationBanner extends StatefulWidget {
  final Future<List<NotificationItem>> Function()? load;
  final void Function(NotificationItem item)? onTapItem;
  final VoidCallback? onClose;

  const NotificationBanner({
    super.key,
    this.load,
    this.onTapItem,
    this.onClose,
  });

  @override
  State<NotificationBanner> createState() => _NotificationBannerState();

  // MÉTODO ESTÁTICO GLOBAL — TODAS LAS NOTIFICACIONES SE MUESTRAN ARRIBA A LA DERECHA
  static void show(BuildContext context, String message, NotificationType type) {
    final overlay = Overlay.of(context);

    // CONFIGURACIÓN DE COLOR E ICONO
    Color bgColor;
    IconData icon;
    switch (type) {
      case NotificationType.success:
        bgColor = Colors.green.shade600;
        icon = Icons.check_circle_outline;
        break;
      case NotificationType.error:
        bgColor = Colors.redAccent;
        icon = Icons.error_outline;
        break;
      case NotificationType.warning:
        bgColor = Colors.orange.shade700;
        icon = Icons.warning_amber_rounded;
        break;
      case NotificationType.info:
      default:
        bgColor = Colors.blueAccent;
        icon = Icons.info_outline;
        break;
    }

    // DECLARAR LA VARIABLE ENTRY ANTES DE USARLA
    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 60,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 200),
            offset: const Offset(0, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              width: 360,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    onPressed: () => entry?.remove(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    // SE CIERRA AUTOMÁTICAMENTE TRAS 5 SEGUNDOS
    Future.delayed(const Duration(seconds: 5)).then((_) {
      entry?.remove();
    });
  }
}

// BANNER AUTOMÁTICO PARA CARGA DE NOTIFICACIONES 
class _NotificationBannerState extends State<NotificationBanner> {
  List<NotificationItem> _items = [];
  Timer? _timer;
  Timer? _autoHideTimer;

  @override
  void initState() {
    super.initState();
    _refresh();

    if (widget.load != null) {
      _timer = Timer.periodic(const Duration(minutes: 2), (_) => _refresh());
    }
  }

  Future<void> _refresh() async {
    if (widget.load == null) return;
    try {
      final items = await widget.load!();
      if (!mounted) return;
      if (items.isNotEmpty) {
        setState(() => _items = items);
        _startAutoHide(items.first);
      }
    } catch (_) {}
  }

  void _startAutoHide(NotificationItem item) {
    _autoHideTimer?.cancel();
    final tipo = item.tipo.toLowerCase();

    int seconds = 10;
    if (tipo.contains('error') || tipo.contains('urgente') || tipo.contains('warning')) {
      seconds = 20;
    }

    _autoHideTimer = Timer(Duration(seconds: seconds), () {
      if (mounted) setState(() => _items = []);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _autoHideTimer?.cancel();
    super.dispose();
  }

  Color _bgColor(String tipo) {
    final t = tipo.toLowerCase();
    if (t.contains('success') || t.contains('exito')) return Colors.green.shade600;
    if (t.contains('error') || t.contains('urgente')) return Colors.redAccent;
    if (t.contains('warning') || t.contains('alerta')) return Colors.orange.shade700;
    return Colors.blueAccent;
  }

  IconData _iconFor(String tipo) {
    final t = tipo.toLowerCase();
    if (t.contains('success') || t.contains('exito')) return Icons.check_circle_outline;
    if (t.contains('error') || t.contains('urgente')) return Icons.error_outline;
    if (t.contains('warning') || t.contains('alerta')) return Icons.warning_amber_rounded;
    return Icons.info_outline;
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();

    final n = _items.first;
    final color = _bgColor(n.tipo);

    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 16, right: 16),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 340,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(_iconFor(n.tipo), color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        n.titulo,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                      onPressed: () {
                        _autoHideTimer?.cancel();
                        setState(() => _items = []);
                        widget.onClose?.call();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  n.detalle,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
