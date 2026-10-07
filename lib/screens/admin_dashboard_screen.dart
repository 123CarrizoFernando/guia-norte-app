import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _tituloController = TextEditingController();
  final _mensajeController = TextEditingController();
  bool isSending = false;

  // Función que muestra la ventana emergente para escribir la alerta
  void _mostrarDialogoNotificacion() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Enviar Notificación Masiva',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Este mensaje llegará al celular de TODAS las personas que tengan la app instalada en Tartagal.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _tituloController,
                decoration: const InputDecoration(
                  labelText: 'Título (Ej: ¡Nuevo Profesional!)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _mensajeController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Mensaje (Ej: Conoce al mejor plomero...)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
                _enviarNotificacionAlServidor();
              },
              child: const Text('Enviar a TODOS'),
            ),
          ],
        );
      },
    );
  }

  // Función que se conecta con tu backend Node.js
  Future<void> _enviarNotificacionAlServidor() async {
    if (_tituloController.text.isEmpty || _mensajeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes llenar el título y el mensaje.')),
      );
      return;
    }

    setState(() => isSending = true);

    try {
      final url = Uri.parse(
        'https://guia-norte-backend.onrender.com/api/admin/notificaciones',
      );
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'titulo': _tituloController.text,
          'mensaje': _mensajeController.text,
        }),
      );

      if (response.statusCode == 200) {
        _tituloController.clear();
        _mensajeController.clear();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Notificación masiva enviada con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Error del servidor');
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hubo un error al enviar la alerta.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text(
          'Súper Administrador',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.amber,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Resumen General',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: const [
                              Icon(Icons.store, color: Colors.blue, size: 32),
                              SizedBox(height: 8),
                              Text(
                                '14',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Negocios',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: const [
                              Icon(Icons.people, color: Colors.green, size: 32),
                              SizedBox(height: 8),
                              Text(
                                '58',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Usuarios',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                const Text(
                  'Herramientas Administrativas',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                Card(
                  elevation: 1,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.category,
                          color: Colors.indigo,
                        ),
                        title: const Text('Gestionar Categorías y Rubros'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Función en desarrollo...'),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.star, color: Colors.amber),
                        title: const Text('Aprobar Negocios Premium'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Función en desarrollo...'),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.notifications_active,
                          color: Colors.redAccent,
                        ),
                        title: const Text('Enviar Notificación Masiva (Push)'),
                        subtitle: const Text(
                          'Avisa a todos los usuarios de Tartagal',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _mostrarDialogoNotificacion, // ¡Conectado al formulario!
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Indicador de carga visual mientras se envía la alerta a miles de personas
          if (isSending)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              ),
            ),
        ],
      ),
    );
  }
}
