import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nutri/base/base.dart';

import '../models/reserva_pendiente.dart';
import '../models/resultado_reserva.dart';
import '../models/sede_comedor.dart';
import '../models/tipo_reserva_actual.dart';

/// Reservas de comedor, contra el REST `nfc` del proyecto nutrisoft
/// (`com.nutri.alimentacion.ws.WebServices`).
///
///   POST $BASE_URL/nfc/get_tipo_reservaActual   (sin cuerpo)
///        → { error: false, tipoReserva: "ALMUERZO", horaFin: "11:05" }
///        → { error: true, message, proximoTipo, proximaHora, proximoManana }
///
///   POST $BASE_URL/nfc/registrar_reservacu | registrar_reservasa
///        { qrCode: base64(cédula) }   ← el mismo contenido del QR del perfil
///        → { error, msg, nombre, img, pendiente? }   (ver [ResultadoReserva])
///
///   POST $BASE_URL/nfc/listar_reservas_pendientes
///        { qrCode: base64(cédula) }
///        → { error, msg, reservas: [...], total }   (ver [ReservaPendiente])
class ReservaService {
  static const String rutaTipoActual = 'nfc/get_tipo_reservaActual';
  static const String rutaPendientes = 'nfc/listar_reservas_pendientes';

  final String baseUrl = Base().BASE_URL;

  /// Devuelve `null` si no se pudo consultar (sin red, HTTP != 200, JSON roto);
  /// así la pantalla distingue "no hay horario" de "no hubo respuesta".
  Future<TipoReservaActual?> obtenerTipoReservaActual() async {
    final url = Uri.parse('$baseUrl$rutaTipoActual');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode != 200) {
        debugPrint("TIPO RESERVA ACTUAL: HTTP ${response.statusCode}");
        return null;
      }

      final map = json.decode(response.body);
      if (map is! Map<String, dynamic>) return null;

      return TipoReservaActual.fromJson(map);
    } catch (e) {
      debugPrint("ERROR AL CONSULTAR TIPO RESERVA ACTUAL: $e");
      return null;
    }
  }

  /// Registra la reserva del empleado en el comedor [sede].
  ///
  /// Devuelve `null` si no hubo respuesta usable del servidor.
  Future<ResultadoReserva?> registrarReserva({
    required SedeComedor sede,
    required String cedula,
  }) async {
    final url = Uri.parse('$baseUrl${sede.ruta}');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"qrCode": qrDeCedula(cedula)}),
      );

      if (response.statusCode != 200) {
        debugPrint(
          "REGISTRAR RESERVA ${sede.codigo}: HTTP ${response.statusCode}",
        );
        return null;
      }

      final map = json.decode(response.body);
      if (map is! Map<String, dynamic>) return null;

      return ResultadoReserva.fromJson(map);
    } catch (e) {
      debugPrint("ERROR AL REGISTRAR RESERVA ${sede.codigo}: $e");
      return null;
    }
  }

  /// Reservas del día del empleado que aún no se retiran.
  ///
  /// Devuelve `null` si no hubo respuesta usable (sin red, HTTP != 200, o el
  /// backend respondió `error: true`, p. ej. cédula no encontrada).
  Future<List<ReservaPendiente>?> listarPendientes(String cedula) async {
    final url = Uri.parse('$baseUrl$rutaPendientes');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"qrCode": qrDeCedula(cedula)}),
      );

      if (response.statusCode != 200) {
        debugPrint("RESERVAS PENDIENTES: HTTP ${response.statusCode}");
        return null;
      }

      final map = json.decode(response.body);
      if (map is! Map<String, dynamic>) return null;

      if (map['error'] == true || map['error'].toString() == 'true') {
        debugPrint("RESERVAS PENDIENTES: ${map['msg']}");
        return null;
      }

      return ReservaPendiente.listaDesde(map);
    } catch (e) {
      debugPrint("ERROR AL LISTAR RESERVAS PENDIENTES: $e");
      return null;
    }
  }

  /// La cédula tal como va en el QR del perfil y en `qrCode`: Base64 de UTF-8.
  static String qrDeCedula(String cedula) =>
      base64Encode(utf8.encode(cedula.trim()));
}
