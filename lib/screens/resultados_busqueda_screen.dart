import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'perfil_detalle_screen.dart';

class ResultadosBusquedaScreen extends StatefulWidget {
  final String query;

  const ResultadosBusquedaScreen({super.key, required this.query});

  @override
  State<ResultadosBusquedaScreen> createState() =>
      _ResultadosBusquedaScreenState();
}

class _ResultadosBusquedaScreenState extends State<ResultadosBusquedaScreen> {
  List<dynamic> profesionales = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    buscarProfesionales();
  }

  Future<void> buscarProfesionales() async {
    try {
      final url = Uri.parse(
        'https://guia-norte-backend.onrender.com/api/buscar?q=${Uri.encodeComponent(widget.query)}',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          profesionales = json.decode(response.body);
          isLoading = false;
        });
      } else {
        throw Exception('Error en la búsqueda');
      }
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'Resultados para "${widget.query}"',
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : profesionales.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No encontramos resultados para "${widget.query}"',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: profesionales.length,
              itemBuilder: (context, index) {
                final prof = profesionales[index];
                final bool isPremium = prof['nivel'] == 3;

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            PerfilDetalleScreen(perfil: prof, currentUserId: 1),
                      ),
                    );
                  },
                  child: Card(
                    elevation: isPremium ? 4 : 1,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isPremium
                          ? const BorderSide(color: Colors.blueAccent, width: 2)
                          : BorderSide.none,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.blue[50],
                                backgroundImage: prof['logo_url'] != null
                                    ? NetworkImage(prof['logo_url'])
                                    : null,
                                child: prof['logo_url'] == null
                                    ? const Icon(
                                        Icons.store,
                                        color: Colors.blueAccent,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            prof['nombre_comercial'] ??
                                                'Sin nombre',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        if (isPremium)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blueAccent
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'DESTACADO',
                                              style: TextStyle(
                                                color: Colors.blueAccent,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          prof['calificacion_promedio'] != null
                                              ? prof['calificacion_promedio']
                                                    .toString()
                                              : '0.0',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            prof['descripcion'] ?? 'Sin descripción.',
                            style: TextStyle(color: Colors.grey[700]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
