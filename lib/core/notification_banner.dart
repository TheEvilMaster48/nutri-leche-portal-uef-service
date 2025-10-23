import 'dart:async';
import 'package:flutter/material.dart';
import '../models/notification_item.dart';

// Tipos de notificación disponibles
enum NotificationType {
  success,
  error,
  info,
  warning,
}

// Banner Flotante
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

  //  Método estático para SnackBars simples (crear/modificar evento)
  static void show(BuildContext context, String message, NotificationType type) {
    final color = switch (type) {
      NotificationType.success => Colors.green.shade600,
      NotificationType.error => Colors.redAccent,
      NotificationType.warning => Colors.orange.shade700,
      NotificationType.info => Colors.blueAccent,
    };

    final icon = switch (type) {
      NotificationType.success => Icons.check_circle,
      NotificationType.error => Icons.error,
      NotificationType.warning => Icons.warning_amber_rounded,
      NotificationType.info => Icons.info_outline,
    };

    // ⏱ Duraciones actualizadas
    final duration = Duration(
      seconds: (type == NotificationType.success || type == NotificationType.info)
          ? 10
          : 20,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: duration,
      ),
    );
  }
}

class _NotificationBannerState extends State<NotificationBanner> {
  List<NotificationItem> _items = [];
  Timer? _timer;
  Timer? _autoHideTimer;

  @override
  void initState() {
    super.initState();
    _refresh();

    // Recarga automática cada 2 minutos
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

    // ⏱ Ajustar duración automática
    int seconds = 10;
    if (tipo.contains('error') || tipo.contains('urgente') || tipo.contains('warning')) {
      seconds = 20;
    }

    _autoHideTimer = Timer(Duration(seconds: seconds), () {
      if (mounted) setState(() => _items = []);
    });

    // Recordatorio cada 2 minutos solo para eventos o notificaciones Urgentes
    if (tipo.contains('error') || tipo.contains('urgente') || tipo.contains('warning')) {
      Timer(const Duration(minutes: 2), () {
        if (mounted && _items.isEmpty) {
          setState(() => _items = [item]);
          _startAutoHide(item);
        }
      });
    }
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
