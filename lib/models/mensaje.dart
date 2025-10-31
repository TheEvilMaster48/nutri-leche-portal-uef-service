class Mensaje {
  final String id;
  final String chatId;
  final String remitenteId;
  final String remitenteNombre;
  final String texto;
  final DateTime fecha;

  Mensaje({
    required this.id,
    required this.chatId,
    required this.remitenteId,
    required this.remitenteNombre,
    required this.texto,
    required this.fecha,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatId': chatId,
      'remitenteId': remitenteId,
      'remitenteNombre': remitenteNombre,
      'texto': texto,
      'fecha': fecha.millisecondsSinceEpoch,
    };
  }

  factory Mensaje.fromMap(Map<String, dynamic> map) {
    return Mensaje(
      id: map['id'] ?? '',
      chatId: map['chatId'] ?? '',
      remitenteId: map['remitenteId'] ?? '',
      remitenteNombre: map['remitenteNombre'] ?? '',
      texto: map['texto'] ?? '',
      fecha: map['fecha'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['fecha'])
          : DateTime.tryParse(map['fecha'].toString()) ?? DateTime.now(),
    );
  }
}
