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
  String _searchQuery = '';
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

  // ==========================================
  // LÓGICA DE ÍCONOS INTELIGENTES
  // ==========================================
  IconData _obtenerIconoInteligente(String nombre) {
    final n = nombre.toLowerCase();
    if (n.contains('salud') || n.contains('medicina') || n.contains('médico'))
      return Icons.medical_services;
    if (n.contains('construcción') ||
        n.contains('obra') ||
        n.contains('albañil'))
      return Icons.construction;
    if (n.contains('mecánica') || n.contains('auto') || n.contains('moto'))
      return Icons.car_repair;
    if (n.contains('comida') || n.contains('gastro')) return Icons.restaurant;
    if (n.contains('educación') || n.contains('clase')) return Icons.school;
    if (n.contains('belleza') || n.contains('estética') || n.contains('pelo'))
      return Icons.face_retouching_natural;
    if (n.contains('tecnología') || n.contains('pc') || n.contains('celular'))
      return Icons.computer;
    if (n.contains('hogar') || n.contains('limpieza'))
      return Icons.cleaning_services;
    if (n.contains('legal') || n.contains('abogado')) return Icons.gavel;
    if (n.contains('ropa') || n.contains('indumentaria'))
      return Icons.checkroom;
    return Icons.folder; // Ícono por defecto
  }

  // ==========================================
  // VENTANAS EMERGENTES (NUEVO Y EDITAR) - CORREGIDO
  // ==========================================
  void _mostrarDialogoCategoria({int? id, String? nombreActual}) {
    final txtController = TextEditingController(text: nombreActual);
    final esEditar = id != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          esEditar ? 'Editar Categoría' : 'Nueva Categoría Principal',
        ),
        content: TextField(
          controller: txtController,
          decoration: const InputDecoration(
            hintText: 'Ej: Mecánica, Gastronomía...',
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (txtController.text.isNotEmpty) {
                // 1. CAPTURAMOS EL MENSAJERO ANTES DE CERRAR LA VENTANA
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context); // Ahora sí cerramos seguro

                setState(() => isLoading = true);

                final url = esEditar
                    ? 'https://guia-norte-backend.onrender.com/api/admin/categorias/$id'
                    : 'https://guia-norte-backend.onrender.com/api/admin/categorias';

                final request = esEditar ? http.put : http.post;

                await request(
                  Uri.parse(url),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({
                    'nombre': txtController.text.toUpperCase(),
                  }),
                );

                await _cargarTodo(); // Esperamos que recargue
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      esEditar ? 'Categoría actualizada' : 'Categoría creada',
                    ),
                  ),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoRubro(
    int categoriaId, {
    int? rubroId,
    String? nombreActual,
  }) {
    final txtController = TextEditingController(text: nombreActual);
    final esEditar = rubroId != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(esEditar ? 'Editar Oficio' : 'Nuevo Oficio'),
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
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                setState(() => isLoading = true);

                final url = esEditar
                    ? 'https://guia-norte-backend.onrender.com/api/admin/rubros/$rubroId'
                    : 'https://guia-norte-backend.onrender.com/api/admin/rubros';

                final request = esEditar ? http.put : http.post;

                await request(
                  Uri.parse(url),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({
                    'nombre': txtController.text,
                    'categoria_id': categoriaId,
                  }),
                );

                await _cargarTodo();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      esEditar ? 'Oficio actualizado' : 'Oficio agregado',
                    ),
                  ),
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
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              setState(() => isLoading = true);

              await http.delete(
                Uri.parse(
                  'https://guia-norte-backend.onrender.com/api/admin/rubros/$rubroId',
                ),
              );

              await _cargarTodo();
              messenger.showSnackBar(
                const SnackBar(content: Text('Oficio eliminado')),
              );
            },
            child: const Text('Borrar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Lógica del filtro de búsqueda
    List categoriasFiltradas = categorias.where((c) {
      if (_searchQuery.isEmpty) return true;
      final catNombre = c['nombre'].toString().toLowerCase();
      final rubros = c['rubros_list'] as List? ?? [];

      final coincideCategoria = catNombre.contains(_searchQuery.toLowerCase());
      final coincideRubro = rubros.any(
        (r) => r['nombre'].toString().toLowerCase().contains(
          _searchQuery.toLowerCase(),
        ),
      );

      return coincideCategoria || coincideRubro;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Categorías y Oficios'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // BARRA DE BÚSQUEDA
          Container(
            color: Colors.indigo,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Buscar categoría u oficio...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // LISTA DE CATEGORÍAS
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : categoriasFiltradas.isEmpty
                ? const Center(
                    child: Text(
                      'No se encontraron resultados',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: categoriasFiltradas.length,
                    itemBuilder: (context, index) {
                      final c = categoriasFiltradas[index];
                      final List rubros = c['rubros_list'] ?? [];

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ExpansionTile(
                          // Si estamos buscando, expandimos las carpetas automáticamente
                          initiallyExpanded: _searchQuery.isNotEmpty,
                          leading: CircleAvatar(
                            backgroundColor: Colors.indigo.withOpacity(0.1),
                            // Aquí usamos la función del ícono inteligente
                            child: Icon(
                              _obtenerIconoInteligente(c['nombre']),
                              color: Colors.indigo,
                            ),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  c['nombre'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                                onPressed: () => _mostrarDialogoCategoria(
                                  id: c['id'],
                                  nombreActual: c['nombre'],
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            '${rubros.length} oficios registrados',
                          ),
                          children: [
                            ...rubros.map(
                              (r) => ListTile(
                                contentPadding: const EdgeInsets.only(
                                  left: 72,
                                  right: 16,
                                ),
                                title: Text("• ${r['nombre']}"),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        size: 20,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () => _mostrarDialogoRubro(
                                        c['id'],
                                        rubroId: r['id'],
                                        nombreActual: r['nombre'],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                        color: Colors.red,
                                      ),
                                      onPressed: () =>
                                          _eliminarRubro(r['id'], r['nombre']),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: OutlinedButton.icon(
                                onPressed: () => _mostrarDialogoRubro(c['id']),
                                icon: const Icon(Icons.add),
                                label: const Text('Añadir nuevo oficio aquí'),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      // BOTÓN FLOTANTE PARA NUEVA CATEGORÍA PRINCIPAL
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarDialogoCategoria,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva Categoría'),
      ),
    );
  }
}
