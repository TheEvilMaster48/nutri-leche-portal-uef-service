import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/usuario.dart';
import '../services/auth_service.dart';
import 'chat_detalle.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Usuario> _usuarios = [];
  List<Usuario> _usuariosFiltrados = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarUsuariosDesdeUEF();
  }

  // Cargar usuarios desde el backend UEF Service
  Future<void> _cargarUsuariosDesdeUEF() async {
    try {
      // Usa la constante baseUrl correctamente
      const baseUrl = AuthService.baseUrl;

      final response = await http.get(Uri.parse('$baseUrl/usuarios'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          _usuarios = (data as List)
              .map((u) => Usuario.fromJson(Map<String, dynamic>.from(u)))
              .toList();
          _usuariosFiltrados = _usuarios;
          _isLoading = false;
        });
      } else {
        throw Exception('Error ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error cargando usuarios: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: !_isSearching
            ? const Text('Mensajes', style: TextStyle(color: Colors.white))
            : TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Buscar usuario...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: _filtrarUsuarios,
              ),
        backgroundColor: const Color(0xFF4ADE80),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchController.clear();
                  _usuariosFiltrados = _usuarios;
                }
                _isSearching = !_isSearching;
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _usuariosFiltrados.isEmpty
              ? const Center(child: Text('No se encontraron usuarios.'))
              : ListView.builder(
                  itemCount: _usuariosFiltrados.length,
                  itemBuilder: (context, index) {
                    final usuario = _usuariosFiltrados[index];
                    final imagenUrl =
                        'https://servicioslsa.nutri.com.ec/alimentacion/${usuario.cedula ?? 'default'}.jpeg';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF4ADE80),
                        backgroundImage: NetworkImage(imagenUrl),
                        onBackgroundImageError: (_, __) {},
                        child: usuario.cedula == null
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                      title: Text(
                        usuario.nombre,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        usuario.telefono.isNotEmpty
                            ? usuario.telefono
                            : 'Sin teléfono',
                        style:
                            const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatDetalleScreen(
                              chatId: usuario.id.toString(),
                              contactoNombre: usuario.nombre,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4ADE80),
        child: const Icon(Icons.chat_outlined, size: 28),
        onPressed: () {
          _mostrarDialogoBuscarUsuario(context);
        },
      ),
    );
  }

  // 🔎 Filtrar usuarios en lista
  void _filtrarUsuarios(String query) {
    final results = _usuarios.where((u) {
      return u.nombre.toLowerCase().contains(query.toLowerCase()) ||
          (u.telefono).toLowerCase().contains(query.toLowerCase()) ||
          (u.cedula ?? '').toLowerCase().contains(query.toLowerCase());
    }).toList();

    setState(() => _usuariosFiltrados = results);
  }

  // Buscar por número o cédula manualmente
  void _mostrarDialogoBuscarUsuario(BuildContext context) {
    final buscarController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Iniciar chat por número o cédula'),
        content: TextField(
          controller: buscarController,
          decoration: const InputDecoration(
            hintText: 'Ingrese número o cédula',
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4ADE80),
            ),
            child: const Text('Buscar'),
            onPressed: () async {
              final query = buscarController.text.trim();
              if (query.isEmpty) return;

              final usuarioEncontrado = _usuarios.firstWhere(
                (u) =>
                    u.telefono == query ||
                    (u.cedula?.toLowerCase() == query.toLowerCase()),
                orElse: () => Usuario(
                  id: 0,
                  nombre: 'No encontrado',
                  correo: '',
                  telefono: '',
                  cargo: '',
                  areaUsuario: '',
                  modulos: '',
                  cedula: '',
                ),
              );

              Navigator.pop(context);

              if (usuarioEncontrado.id != 0) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatDetalleScreen(
                      chatId: usuarioEncontrado.id.toString(),
                      contactoNombre: usuarioEncontrado.nombre,
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Usuario no encontrado en el sistema'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
