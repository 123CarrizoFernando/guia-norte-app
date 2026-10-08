import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'resultados_screen.dart';

class RubrosScreen extends StatefulWidget {
  final int categoriaId;
  final String categoriaNombre;

  const RubrosScreen({
    super.key,
    required this.categoriaId,
    required this.categoriaNombre,
  });

  @override
  State<RubrosScreen> createState() => _RubrosScreenState();
}

class _RubrosScreenState extends State<RubrosScreen> {
  List<dynamic> rubros = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchRubros();
  }

  Future<void> fetchRubros() async {
    try {
      final url = Uri.parse(
        'https://guia-norte-backend.onrender.com/api/categorias/${widget.categoriaId}/rubros',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          rubros = json.decode(response.body);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context)
          .scaffoldBackgroundColor, // Se adapta al tema
      appBar: AppBar(
        title: Text(
          widget.categoriaNombre,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        // Colores controlados por main.dart
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).primaryColor,
              ),
            )
          : rubros.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox,
                    size: 64,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Próximamente más servicios',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: rubros.length,
              itemBuilder: (context, index) {
                final rubro = rubros[index];
                return Card(
                  color: Theme.of(context).cardColor, // Se adapta al tema
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.work_outline,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    title: Text(
                      rubro['nombre'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ResultadosScreen(
                            rubroId: rubro['id'],
                            rubroNombre: rubro['nombre'],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
