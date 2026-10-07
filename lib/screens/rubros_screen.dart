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
    return Scaffold(
      backgroundColor: Colors.grey[200], // Fondo claro estilo ML
      appBar: AppBar(
        title: Text(
          widget.categoriaNombre,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.black, // Barra superior negra
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), // Flecha blanca
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.lightBlue),
            )
          : rubros.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Próximamente más servicios',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
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
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.lightBlue.withOpacity(
                          0.1,
                        ), // Círculo celeste tenue
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.work_outline,
                        color: Colors.lightBlue,
                      ), // Ícono celeste
                    ),
                    title: Text(
                      rubro['nombre'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                    ),
                    onTap: () {
                      // Navegamos a la pantalla de resultados que ya rediseñamos antes
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
