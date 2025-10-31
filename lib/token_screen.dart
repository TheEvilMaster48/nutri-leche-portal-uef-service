import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'dart:html' as html; // SOLO PARA FLUTTER WEB

class TokenScreen extends StatefulWidget {
  const TokenScreen({super.key});

  @override
  State<TokenScreen> createState() => _TokenScreenState();
}

class _TokenScreenState extends State<TokenScreen> {
  String? _token;

  // GENERA UN TOKEN LOCAL Y LO GUARDA EN LOCALSTORAGE
  void _generateLocalToken() {
    const uuid = Uuid();
    final newToken = uuid.v4();

    // GUARDAR TOKEN EN LOCAL STORAGE DEL NAVEGADOR
    html.window.localStorage['flutter_local_token'] = newToken;

    setState(() {
      _token = newToken;
    });

    // IMPRIMIR EN CONSOLA
    print('==========================================');
    print('TOKEN LOCAL GENERADO: $_token');
    print('==========================================');
  }

  // CARGAR TOKEN GUARDADO SI EXISTE
  void _loadSavedToken() {
    final savedToken = html.window.localStorage['flutter_local_token'];
    if (savedToken != null && savedToken.isNotEmpty) {
      setState(() => _token = savedToken);
      print('TOKEN CARGADO DESDE LOCALSTORAGE: $savedToken');
    } else {
      _generateLocalToken();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSavedToken(); // GENERA O CARGA AUTOMÁTICAMENTE AL INICIAR
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TOKEN LOCAL FLUTTER'),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'TOKEN LOCAL DE LA APP:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              SelectableText(
                _token ?? 'AÚN NO SE HA GENERADO TOKEN',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _generateLocalToken,
                icon: const Icon(Icons.vpn_key_rounded),
                label: const Text('GENERAR NUEVO TOKEN'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
