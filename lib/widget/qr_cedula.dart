import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/qr_store.dart';
import '../services/reserva_service.dart';

/// Tarjeta con el QR de la cédula del empleado conectado.
///
/// El QR lleva la cédula codificada en Base64 (UTF-8), sin prefijos ni JSON:
/// quien lo lea (comedor, garita) tiene que decodificarlo para obtener el
/// número. Debajo se muestra la cédula en claro para verificarla a ojo.
///
/// Funciona sin internet: `AuthService` guarda la cédula en [QrStore] al
/// iniciar sesión y cada vez que se actualiza el usuario; si el usuario en
/// memoria viene sin cédula, aquí se usa la guardada.
class QrCedula extends StatefulWidget {
  const QrCedula({super.key, required this.idUsuario, required this.cedula});

  final int idUsuario;
  final String? cedula;

  @override
  State<QrCedula> createState() => _QrCedulaState();
}

class _QrCedulaState extends State<QrCedula> {
  QrGuardado? _guardado;

  @override
  void initState() {
    super.initState();
    _sincronizar();
  }

  @override
  void didUpdateWidget(QrCedula oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cedula != widget.cedula ||
        oldWidget.idUsuario != widget.idUsuario) {
      _sincronizar();
    }
  }

  /// Sin cédula en memoria, recupera la guardada en el teléfono.
  Future<void> _sincronizar() async {
    if ((widget.cedula ?? '').trim().isNotEmpty) return;

    final guardado = await QrStore.leer(widget.idUsuario);
    if (!mounted) return;
    setState(() => _guardado = guardado);
  }

  @override
  Widget build(BuildContext context) {
    final enMemoria = (widget.cedula ?? '').trim();
    final cedula = enMemoria.isNotEmpty ? enMemoria : _guardado?.cedula;
    final qr =
        enMemoria.isNotEmpty
            ? ReservaService.qrDeCedula(enMemoria)
            : _guardado?.qr;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Mi código QR',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0052A3),
            ),
          ),
          const SizedBox(height: 16),
          if (qr == null || cedula == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No hay cédula registrada para generar el código.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            )
          else ...[
            QrImageView(
              data: qr,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              // Margen blanco alrededor: sin él algunos lectores no lo toman.
              padding: const EdgeInsets.all(8),
            ),
            const SizedBox(height: 12),
            Text(
              'Cédula: $cedula',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
