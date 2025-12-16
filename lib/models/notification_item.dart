class NotificationItem {
  final String id;
  final String tipo;
  final String titulo;
  final String detalle;
  final String refId;
  final DateTime fecha;

  NotificationItem({
    this.id = '',
    required this.tipo,
    required this.titulo,
    required this.detalle,
    this.refId = '',
    required this.fecha,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: (json['id'] ?? json['refId'] ?? '').toString(),
      tipo: (json['tipo'] ?? '').toString(),
      titulo: (json['titulo'] ?? '').toString(),
      detalle: (json['detalle'] ?? '').toString(),
      refId: (json['refId'] ?? '').toString(),
      fecha: DateTime.tryParse(json['fecha']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

