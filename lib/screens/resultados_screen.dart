import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'perfil_detalle_screen.dart';

class ResultadosScreen extends StatefulWidget {
  final int rubroId;
  final String rubroNombre;

  const ResultadosScreen({
    super.key,
    required this.rubroId,
    required this.rubroNombre,
  });

  @override
  State<ResultadosScreen> createState() => _ResultadosScreenState();
}

class _ResultadosScreenState extends State<ResultadosScreen> {
  List<dynamic> profesionales = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchProfesionales();
  }

  Future<void> fetchProfesionales() async {
    try {
      final url = Uri.parse(
        'http://localhost:3000/api/rubros/${widget.rubroId}/profesionales',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          profesionales = json.decode(response.body);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error en la petición: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200], // Fondo claro estilo ML
      appBar: AppBar(
        title: Text(
          widget.rubroNombre,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.black, // Barra superior negra
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ), // Flecha hacia atrás blanca
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : profesionales.isEmpty
          ? const Center(child: Text("Aún no hay profesionales en este rubro."))
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
                        builder: (context) => PerfilDetalleScreen(
                          perfil: prof,
                          currentUserId: 1, // Esto ya no se usará gracias a tu nueva lógica de Firebase
                        ),
                      ),
                    );
                  },
                  child: Card(
                    elevation: isPremium ? 4 : 1,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isPremium
                          ? const BorderSide(
                              color: Colors.lightBlue,
                              width: 2,
                            ) // Borde celeste destacado
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
                                radius: 26,
                                backgroundColor: Colors.blue[50],
                                backgroundImage: prof['logo_url'] != null
                                    ? NetworkImage(prof['logo_url'])
                                    : null,
                                child: prof['logo_url'] == null
                                    ? const Icon(
                                        Icons.store,
                                        color: Colors.lightBlue,
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
                                              color: Colors.lightBlue
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'DESTACADO',
                                              style: TextStyle(
                                                color: Colors.lightBlue,
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
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                debugPrint(
                                  'Contactar a: ${prof['telefono_contacto']}',
                                );
                              },
                              icon: const Icon(
                                Icons.phone,
                                color: Colors.white,
                                size: 18,
                              ),
                              label: const Text('Contactar por WhatsApp'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Colors.black87, // Botón oscuro elegante
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
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
