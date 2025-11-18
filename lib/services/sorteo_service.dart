import 'dart:math';
import 'package:flutter/material.dart';
import '../models/sorteo.dart';

class SorteoService extends ChangeNotifier {
  Sorteo? _sorteoActual;

  Sorteo? get sorteoActual => _sorteoActual;

  // CREAR NUEVO SORTEO
  void crearNuevoSorteo({int cantidad = 100}) {
    final numeros = List<int>.generate(cantidad, (i) => i + 1);
    _sorteoActual = Sorteo(id: DateTime.now().millisecondsSinceEpoch, numeros: numeros);
    notifyListeners();
  }

  // GIRAR RULETA Y ELEGIR GANADOR
  int girarRuleta() {
    if (_sorteoActual == null) {
      crearNuevoSorteo();
    }
    final random = Random();
    final ganador = _sorteoActual!.numeros[random.nextInt(_sorteoActual!.numeros.length)];
    _sorteoActual!.numeroGanador = ganador;
    notifyListeners();
    return ganador;
  }

  // REINICIAR RULETA
  void reiniciarSorteo() {
    if (_sorteoActual != null) {
      _sorteoActual!.numeroGanador = null;
      notifyListeners();
    }
  }
}
