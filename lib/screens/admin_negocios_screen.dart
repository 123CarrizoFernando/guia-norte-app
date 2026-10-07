import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

class AdminNegociosScreen extends StatefulWidget {
  const AdminNegociosScreen({super.key});

  @override
  State<AdminNegociosScreen> createState() => _AdminNegociosScreenState();
}

class _AdminNegociosScreenState extends State<AdminNegociosScreen> {
  List<dynamic> negocios = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    cargarNegocios();
  }

  Future<void> cargarNegocios() async {
    try {
      final response = await http.get(
        Uri.parse('https://guia-norte-backend.onrender.com/api/admin/perfiles'),
      );
      if (response.statusCode == 200) {
        setState(() {
          negocios = json.decode(response.body);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> cambiarPlan(int perfilId, int nuevoPlanId) async {
    try {
      final response = await http.put(
        Uri.parse(
          'https://guia-norte-backend.onrender.com/api/admin/perfiles/$perfilId/plan',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'plan_id': nuevoPlanId}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Plan actualizado con éxito'),
            backgroundColor: Colors.green,
          ),
        );
        cargarNegocios(); // Recarga la lista
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al cambiar plan'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _mostrarOpcionesDePlan(int perfilId, String nombreComercial) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Asignar plan a: $nombreComercial',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.looks_one, color: Colors.grey),
                title: const Text('Plan Básico (Gratis)'),
                onTap: () {
                  Navigator.pop(context);
                  cambiarPlan(perfilId, 1);
                },
              ),
              ListTile(
                leading: const Icon(Icons.looks_two, color: Colors.blue),
                title: const Text('Plan Medio (\$12.500)'),
                onTap: () {
                  Navigator.pop(context);
                  cambiarPlan(perfilId, 2);
                },
              ),
              ListTile(
                leading: const Icon(Icons.star, color: Colors.amber),
                title: const Text('Plan Premium (\$25.000)'),
                onTap: () {
                  Navigator.pop(context);
                  cambiarPlan(perfilId, 3);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Planes'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: negocios.length,
              itemBuilder: (context, index) {
                final n = negocios[index];

                // Colores visuales según el plan actual
                Color colorPlan = Colors.grey;
                if (n['plan_id'] == 2) colorPlan = Colors.blue;
                if (n['plan_id'] == 3) colorPlan = Colors.amber;

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    title: Text(
                      n['nombre_comercial'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Plan actual: ${n['plan_nombre']}'),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorPlan,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _mostrarOpcionesDePlan(
                        n['id'],
                        n['nombre_comercial'],
                      ),
                      child: const Text('Cambiar'),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
