import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart'; // Para verificar si eres el administrador

import 'rubros_screen.dart';
import 'resultados_busqueda_screen.dart';
import 'perfil_detalle_screen.dart';
import 'admin_dashboard_screen.dart'; // La pantalla secreta de admin

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> categorias = [];
  List<dynamic> destacados = [];
  bool isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchCategorias();
    fetchDestacados();
  }

  Future<void> fetchCategorias() async {
    try {
      final url = Uri.parse('http://localhost:3000/api/categorias');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          categorias = json.decode(response.body);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchDestacados() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:3000/api/destacados'),
      );
      if (response.statusCode == 200) {
        setState(() {
          destacados = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Error al cargar destacados: $e');
    }
  }

  void _ejecutarBusqueda(String valor) {
    if (valor.trim().isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultadosBusquedaScreen(query: valor.trim()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],

      // ==========================================
      // MENÚ LATERAL (HAMBURGUESA) CON MODO ADMIN
      // ==========================================
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 50, bottom: 20, left: 20),
              color: Colors.black,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.lightBlue,
                    child: Icon(Icons.person, color: Colors.white, size: 35),
                  ),
                  SizedBox(height: 12),
                  Text('Bienvenido a', style: TextStyle(color: Colors.white70)),
                  Text(
                    'Guía del Norte',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // ==========================================
            // BOTÓN SECRETO DE SÚPER ADMINISTRADOR
            // ==========================================
            // IMPORTANTE: Cambia 'tu.correo@gmail.com' por el tuyo real
            if (FirebaseAuth.instance.currentUser?.email ==
                'svfdfacilitador@gmail.com')
              ListTile(
                tileColor:
                    Colors.amber[50], // Color de advertencia para que destaque
                leading: const Icon(
                  Icons.admin_panel_settings,
                  color: Colors.amber,
                ),
                title: const Text(
                  'Panel de Control Admin',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context); // Cierra el menú lateral primero
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminDashboardScreen(),
                    ),
                  );
                },
              ),

            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: categorias.length,
                      itemBuilder: (context, index) {
                        final cat = categorias[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.category,
                            color: Colors.black54,
                          ),
                          title: Text(cat['nombre']),
                          trailing: const Icon(Icons.chevron_right, size: 16),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RubrosScreen(
                                  categoriaId: cat['id'],
                                  categoriaNombre: cat['nombre'],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),

      // ==========================================
      // BARRA SUPERIOR CON BUSCADOR INTEGRADO
      // ==========================================
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        titleSpacing: 0,
        title: Container(
          height: 40,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: _ejecutarBusqueda,
            decoration: InputDecoration(
              hintText: 'Estoy buscando en Tartagal...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: Colors.lightBlue),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),

      // ==========================================
      // CUERPO DE LA APP (SCROLL HACIA ABAJO)
      // ==========================================
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. BANNER PROMOCIONAL
            Container(
              height: 150,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black, Colors.black87],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Icon(
                      Icons.campaign,
                      size: 150,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'LOS MEJORES\nPROFESIONALES',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Encuentra confianza y calidad.',
                          style: TextStyle(
                            color: Colors.lightBlue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 2. CÍRCULOS DE CATEGORÍAS
            if (!isLoading) ...[
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: categorias.length,
                  itemBuilder: (context, index) {
                    final cat = categorias[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RubrosScreen(
                              categoriaId: cat['id'],
                              categoriaNombre: cat['nombre'],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 85,
                        margin: const EdgeInsets.only(right: 12),
                        child: Column(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.category,
                                color: Colors.lightBlue,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              cat['nombre'],
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 16),

            // 3. SECCIÓN "Novedades y Destacados"
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Destacados en Tartagal',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),

            destacados.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: destacados.length,
                    itemBuilder: (context, index) {
                      final prof = destacados[index];
                      final bool isPremium = prof['nivel'] == 3;

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PerfilDetalleScreen(
                                perfil: prof,
                                currentUserId: 1,
                              ),
                            ),
                          );
                        },
                        child: Card(
                          elevation: isPremium ? 3 : 1,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isPremium
                                ? const BorderSide(
                                    color: Colors.lightBlue,
                                    width: 2,
                                  )
                                : BorderSide.none,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
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
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              prof['nombre_comercial'] ??
                                                  'Sin nombre',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isPremium)
                                            const Icon(
                                              Icons.verified,
                                              color: Colors.lightBlue,
                                              size: 18,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        prof['descripcion'] ?? '',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 13,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            color: Colors.amber,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            prof['calificacion_promedio']
                                                    ?.toString() ??
                                                '0.0',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
