import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

class AdminCategoriasScreen extends StatefulWidget {
  const AdminCategoriasScreen({super.key});

  @override
  State<AdminCategoriasScreen> createState() => _AdminCategoriasScreenState();
}

class _AdminCategoriasScreenState extends State<AdminCategoriasScreen> {
  List<dynamic> categorias = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://guia-norte-backend.onrender.com/api/categorias'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> catData = json.decode(response.body);

        // Cargamos los rubros por cada categoría para mostrarlos en lista desplegable
        for (var cat in catData) {
          final resRubros = await http.get(
            Uri.parse(
              'https://guia-norte-backend.onrender.com/api/categorias/${cat['id']}/rubros',
            ),
          );
          if (resRubros.statusCode == 200) {
            cat['rubros_list'] = json.decode(resRubros.body);
          }
        }
        setState(() => categorias = catData);
      }
    } catch (e) {
      debugPrint("Error cargando categorías: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _mostrarDialogoNuevoRubro(int categoriaId, String nombreCategoria) {
    final txtController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nuevo Oficio en $nombreCategoria'),
        content: TextField(
          controller: txtController,
          decoration: const InputDecoration(
            hintText: 'Ej: Electricista, Plomero...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (txtController.text.isNotEmpty) {
                Navigator.pop(context);
                await http.post(
                  Uri.parse(
                    'https://guia-norte-backend.onrender.com/api/admin/rubros',
                  ),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({
                    'nombre': txtController.text,
                    'categoria_id': categoriaId,
                  }),
                );
                _cargarTodo();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Oficio agregado')),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _eliminarRubro(int rubroId, String nombre) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text('¿Seguro que quieres borrar el oficio "$nombre"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await http.delete(
                Uri.parse(
                  'https://guia-norte-backend.onrender.com/api/admin/rubros/$rubroId',
                ),
              );
              _cargarTodo();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Oficio eliminado')));
            },
            child: const Text('Borrar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorías y Oficios'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: categorias.length,
              itemBuilder: (context, index) {
                final c = categorias[index];
                final List rubros = c['rubros_list'] ?? [];

                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: ExpansionTile(
                    leading: const Icon(Icons.folder, color: Colors.indigo),
                    title: Text(
                      c['nombre'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${rubros.length} oficios registrados'),
                    children: [
                      ...rubros.map(
                        (r) => ListTile(
                          title: Text("• ${r['nombre']}"),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () =>
                                _eliminarRubro(r['id'], r['nombre']),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _mostrarDialogoNuevoRubro(c['id'], c['nombre']),
                          icon: const Icon(Icons.add),
                          label: const Text('Añadir nuevo oficio aquí'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
