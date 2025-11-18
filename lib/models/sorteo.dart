class Sorteo {
  final int id;
  final List<int> numeros;
  int? numeroGanador;
  DateTime fecha;

  Sorteo({
    required this.id,
    required this.numeros,
    this.numeroGanador,
    DateTime? fecha,
  }) : fecha = fecha ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'numeros': numeros,
      'numeroGanador': numeroGanador,
      'fecha': fecha.toIso8601String(),
    };
  }

  factory Sorteo.fromJson(Map<String, dynamic> json) {
    return Sorteo(
      id: json['id'],
      numeros: List<int>.from(json['numeros']),
      numeroGanador: json['numeroGanador'],
      fecha: DateTime.parse(json['fecha']),
    );
  }
}
