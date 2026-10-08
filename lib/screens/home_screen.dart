import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';

import 'rubros_screen.dart';
import 'resultados_busqueda_screen.dart';
import 'perfil_detalle_screen.dart';
import 'admin_dashboard_screen.dart';
import '../main.dart'; // Importa la variable themeNotifier

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
      final url = Uri.parse(
        'https://guia-norte-backend.onrender.com/api/categorias',
      );
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
        Uri.parse('https://guia-norte-backend.onrender.com/api/destacados'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> perfilesTotales = json.decode(response.body);

        setState(() {
          destacados = perfilesTotales.where((p) => p['plan_id'] == 3).toList();
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

  // ==========================================
  // LÓGICA DE ÍCONOS INTELIGENTES
  // ==========================================
  IconData _obtenerIconoInteligente(String nombre) {
    String n = nombre.toLowerCase();
    n = n
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');

    if (n.contains('salud') || n.contains('medicina') || n.contains('medico'))
      return Icons.medical_services;
    if (n.contains('construccion') ||
        n.contains('obra') ||
        n.contains('albanil'))
      return Icons.construction;
    if (n.contains('mecanic') || n.contains('auto') || n.contains('moto'))
      return Icons.car_repair;
    if (n.contains('comida') || n.contains('gastro')) return Icons.restaurant;
    if (n.contains('educacion') || n.contains('clase')) return Icons.school;
    if (n.contains('belleza') || n.contains('estetica') || n.contains('pelo'))
      return Icons.face_retouching_natural;
    if (n.contains('tecnologia') || n.contains('pc') || n.contains('celular'))
      return Icons.computer;
    if (n.contains('hogar') || n.contains('limpieza'))
      return Icons.cleaning_services;
    if (n.contains('legal') || n.contains('abogado')) return Icons.gavel;
    if (n.contains('ropa') || n.contains('indumentaria'))
      return Icons.checkroom;

    return Icons.category; // Ícono por defecto
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      // ==========================================
      // MENÚ LATERAL (HAMBURGUESA)
      // ==========================================
      drawer: Drawer(
        backgroundColor: Theme.of(context).cardColor, // Se adapta al modo
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 50, bottom: 20, left: 20),
              color: Theme.of(context)
                  .appBarTheme
                  .backgroundColor, // Sigue el color de la barra
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Color(0xFF00B4D8),
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
            // BOTÓN PARA CAMBIAR TEMA (CLARO/OSCURO)
            // ==========================================
            ListTile(
              leading: Icon(
                isDark ? Icons.light_mode : Icons.dark_mode,
                color: Theme.of(context).primaryColor,
              ),
              title: Text(
                isDark ? 'Modo Claro' : 'Modo Oscuro',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              onTap: () {
                Navigator.pop(context); // Cierra el menú al tocar
                themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
              },
            ),

            // Línea divisoria
            Divider(color: isDark ? Colors.white24 : Colors.black12),

            if (FirebaseAuth.instance.currentUser?.email ==
                'svfdfacilitador@gmail.com')
              ListTile(
                tileColor: Colors.amber.withOpacity(0.1),
                leading: const Icon(
                  Icons.admin_panel_settings,
                  color: Colors.amber,
                ),
                title: const Text(
                  'Panel de Control Admin',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.amber),
                onTap: () {
                  Navigator.pop(context);
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
                  ? Center(
                      child: CircularProgressIndicator(
                        color: Theme.of(context).primaryColor,
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: categorias.length,
                      itemBuilder: (context, index) {
                        final cat = categorias[index];
                        return ListTile(
                          leading: Icon(
                            _obtenerIconoInteligente(cat['nombre']),
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          title: Text(
                            cat['nombre'],
                            style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.color,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
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
      // BARRA SUPERIOR
      // ==========================================
      appBar: AppBar(
        // Ya no ponemos color aquí, dejamos que main.dart lo controle
        titleSpacing: 0,
        title: Container(
          height: 40,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white
                : Colors.grey[200], // Fondo del buscador
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            style: const TextStyle(
              color: Colors.black87,
            ), // Siempre negro para que se lea en el buscador blanco/gris
            onSubmitted: _ejecutarBusqueda,
            decoration: InputDecoration(
              hintText: 'Estoy buscando en Tartagal...',
              hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
              prefixIcon: Icon(
                Icons.search,
                color: Theme.of(context).primaryColor,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),

      // ==========================================
      // CUERPO DE LA APP
      // ==========================================
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. BANNER PROMOCIONAL
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [Colors.black, Colors.black87]
                      : [
                          Theme.of(context).primaryColor,
                          Colors.blueAccent,
                        ], // Si es claro, usamos el azul de la app
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
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'LOS MEJORES\nPROFESIONALES',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Encuentra confianza y calidad.',
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFF00B4D8)
                                : Colors.white,
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
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor, // Se adapta
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark
                                        ? Colors.black45
                                        : Colors.black12,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _obtenerIconoInteligente(cat['nombre']),
                                color: Theme.of(context).primaryColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              cat['nombre'],
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Destacados en Tartagal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
            const SizedBox(height: 12),

            destacados.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Center(
                      child: Text(
                        '¡Nuevos profesionales destacados muy pronto!',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: destacados.length,
                    itemBuilder: (context, index) {
                      final prof = destacados[index];
                      final bool isPremium = prof['plan_id'] == 3;

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
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor, // Automático
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isPremium
                                  ? const Color(0xFF00B4D8).withOpacity(0.5)
                                  : (isDark ? Colors.white10 : Colors.black12), // Borde sutil si no es premium
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isDark ? Colors.black38 : Colors.black12,
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isDark
                                            ? const Color(0xFF2A3143)
                                            : Colors.grey[200],
                                        image: prof['logo_url'] != null
                                            ? DecorationImage(
                                                image: NetworkImage(
                                                  prof['logo_url'],
                                                ),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: prof['logo_url'] == null
                                          ? Icon(
                                              Icons.store,
                                              color: Theme.of(context)
                                                  .primaryColor,
                                              size: 30,
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
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(context)
                                                        .textTheme
                                                        .bodyLarge
                                                        ?.color,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.verified,
                                                color: Theme.of(context)
                                                    .primaryColor,
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            prof['descripcion'] != null &&
                                                    prof['descripcion']
                                                        .toString()
                                                        .isNotEmpty
                                                ? prof['descripcion']
                                                : 'Profesional verificado en Tartagal',
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.color,
                                              fontSize: 13,
                                              height: 1.4,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.star,
                                                color: Colors.amber,
                                                size: 14,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${prof['calificacion_promedio'] ?? '5.0'}',
                                                style: const TextStyle(
                                                  color: Colors.amber,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '• ${prof['total_resenas'] ?? '0'} Trabajos',
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 11,
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
                              if (isPremium)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor,
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(12),
                                        topRight: Radius.circular(16),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.bolt,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Destacado',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
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
