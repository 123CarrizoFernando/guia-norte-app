import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'rubros_screen.dart';
import 'resultados_busqueda_screen.dart';
import 'perfil_detalle_screen.dart';
import 'admin_dashboard_screen.dart';
import 'soporte_notificaciones_screen.dart';
import '../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> categoriasAlfabeticas = [];
  List<dynamic> categoriasInicio = [];
  List<dynamic> destacados = [];
  Map<int, int> clicsPorCategoria = {};
  bool isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    await _cargarPreferenciasUsoCategorias();
    await Future.wait([fetchCategorias(), fetchDestacados()]);
  }

  Future<void> _cargarPreferenciasUsoCategorias() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('clics_categorias_usuario');
    if (raw != null && raw.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = json.decode(raw);
        clicsPorCategoria = decoded.map(
          (k, v) => MapEntry(int.parse(k), (v as num).toInt()),
        );
      } catch (_) {}
    }
  }

  Future<void> _registrarClicCategoria(Map<String, dynamic> cat) async {
    final int id = cat['id'];
    clicsPorCategoria[id] = (clicsPorCategoria[id] ?? 0) + 1;

    final prefs = await SharedPreferences.getInstance();
    final Map<String, int> paraGuardar = clicsPorCategoria.map(
      (k, v) => MapEntry(k.toString(), v),
    );
    await prefs.setString('clics_categorias_usuario', json.encode(paraGuardar));

    if (mounted) {
      setState(() {
        _ordenarListasDeCategorias(categoriasAlfabeticas);
      });
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RubrosScreen(
          categoriaId: cat['id'],
          categoriaNombre: cat['nombre'],
        ),
      ),
    );
  }

  void _ordenarListasDeCategorias(List<dynamic> listaBase) {
    final List<dynamic> alfa = List<dynamic>.from(listaBase);
    alfa.sort(
      (a, b) => a['nombre'].toString().toLowerCase().compareTo(
        b['nombre'].toString().toLowerCase(),
      ),
    );

    final List<dynamic> inteligentes = List<dynamic>.from(alfa);
    inteligentes.sort((a, b) {
      final int usoA = clicsPorCategoria[a['id']] ?? 0;
      final int usoB = clicsPorCategoria[b['id']] ?? 0;
      if (usoB != usoA) {
        return usoB.compareTo(usoA);
      }
      return a['nombre'].toString().toLowerCase().compareTo(
        b['nombre'].toString().toLowerCase(),
      );
    });

    categoriasAlfabeticas = alfa;
    categoriasInicio = inteligentes;
  }

  Future<void> fetchCategorias() async {
    try {
      final url = Uri.parse(
        'https://guia-norte-backend.onrender.com/api/categorias',
      );
      final response = await http.get(url);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _ordenarListasDeCategorias(data);
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchDestacados() async {
    try {
      final response = await http.get(
        Uri.parse('https://guia-norte-backend.onrender.com/api/destacados'),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> perfilesTotales = json.decode(response.body);
        setState(() {
          destacados = perfilesTotales.where((p) => p['plan_id'] == 3).toList();
        });
      }
    } catch (e) {
      debugPrint('Error cargando destacados: $e');
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

  IconData _obtenerIconoInteligente(String nombre) {
    String n = nombre
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
    if (n.contains('salud') || n.contains('medicina') || n.contains('medico')) {
      return Icons.medical_services;
    }
    if (n.contains('construccion') ||
        n.contains('obra') ||
        n.contains('albanil')) {
      return Icons.construction;
    }
    if (n.contains('mecanic') || n.contains('auto') || n.contains('moto')) {
      return Icons.car_repair;
    }
    if (n.contains('comida') || n.contains('gastro')) return Icons.restaurant;
    if (n.contains('educacion') || n.contains('clase')) return Icons.school;
    if (n.contains('belleza') || n.contains('estetica') || n.contains('pelo')) {
      return Icons.face_retouching_natural;
    }
    if (n.contains('tecnologia') ||
        n.contains('pc') ||
        n.contains('celular') ||
        n.contains('profesional')) {
      return Icons.computer;
    }
    if (n.contains('hogar') || n.contains('limpieza') || n.contains('oficio')) {
      return Icons.handyman;
    }
    if (n.contains('emprendimiento') ||
        n.contains('feria') ||
        n.contains('catalogo')) {
      return Icons.storefront;
    }
    if (n.contains('agro') || n.contains('campo')) return Icons.agriculture;
    if (n.contains('mascota') || n.contains('veterinaria')) return Icons.pets;
    if (n.contains('deporte') || n.contains('fitness')) {
      return Icons.fitness_center;
    }
    if (n.contains('transporte') || n.contains('envio')) {
      return Icons.local_shipping;
    }
    if (n.contains('evento') || n.contains('fiesta')) return Icons.celebration;
    if (n.contains('ropa') ||
        n.contains('indumentaria') ||
        n.contains('moda')) {
      return Icons.checkroom;
    }
    return Icons.category;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: Drawer(
        backgroundColor: Theme.of(context).cardColor,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 50, bottom: 20, left: 20),
              color: const Color(0xFF00B4D8),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.explore,
                      color: Color(0xFF00B4D8),
                      size: 35,
                    ),
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
            ListTile(
              leading: Icon(
                isDark ? Icons.light_mode : Icons.dark_mode,
                color: Theme.of(context).primaryColor,
              ),
              title: Text(
                isDark ? 'Cambiar a Modo Claro' : 'Cambiar a Modo Oscuro',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
              },
            ),
            ListTile(
              leading: Icon(
                Icons.notifications_active_outlined,
                color: Theme.of(context).primaryColor,
              ),
              title: Text(
                'Notificaciones y Soporte',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SoporteNotificacionesScreen(),
                  ),
                );
              },
            ),
            Divider(color: isDark ? Colors.white24 : Colors.black12),
            if (FirebaseAuth.instance.currentUser?.email ==
                'yoprogramador99@gmail.com')
              ListTile(
                tileColor: Colors.amber.withValues(alpha: 0.1),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'CATEGORÍAS (A-Z)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ),
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
                      itemCount: categoriasAlfabeticas.length,
                      itemBuilder: (context, index) {
                        final cat = categoriasAlfabeticas[index];
                        final int cantRubros = cat['cantidad_rubros'] ?? 0;

                        return ListTile(
                          leading: Icon(
                            _obtenerIconoInteligente(cat['nombre']),
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          title: Text(
                            '${cat['nombre']} ($cantRubros)',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.color,
                              fontSize: 14,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _registrarClicCategoria(cat);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        titleSpacing: 0,
        title: Container(
          height: 40,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white : Colors.grey[200],
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            style: const TextStyle(color: Colors.black87),
            onSubmitted: _ejecutarBusqueda,
            decoration: InputDecoration(
              hintText: 'Buscar profesionales, comercios, oficios...',
              hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
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
      body: RefreshIndicator(
        color: Theme.of(context).primaryColor,
        backgroundColor: Theme.of(context).cardColor,
        onRefresh: _cargarDatos,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF0F2027), const Color(0xFF203A43)]
                        : [Theme.of(context).primaryColor, Colors.blueAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
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
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'COMERCIOS, PROFESIONALES,\nOFICIOS Y EMPRENDIMIENTOS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Los mejores profesionales y negocios de Tartagal en un solo lugar.',
                            style: TextStyle(
                              fontSize: 13,
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
              const SizedBox(height: 20),

              if (!isLoading) ...[
                SizedBox(
                  height: 115,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: categoriasInicio.length,
                    itemBuilder: (context, index) {
                      final cat = categoriasInicio[index];
                      final int cantRubros = cat['cantidad_rubros'] ?? 0;

                      return GestureDetector(
                        onTap: () => _registrarClicCategoria(cat),
                        child: Container(
                          width: 90,
                          margin: const EdgeInsets.only(right: 12),
                          child: Column(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
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
                                '${cat['nombre']} ($cantRubros)',
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

              // ==========================================
              // SECCIÓN VITRINA VIP: PORTADA EXCLUSIVA + CARRUSEL DESLIZABLE DE FOTOS
              // ==========================================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.workspace_premium,
                      color: Colors.amber,
                      size: 24,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Profesionales y Comercios VIP',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
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
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color,
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
                        // Usa la portada_url exclusiva (o su logo si no cargó portada)
                        final String? imagenPortada =
                            (prof['portada_url'] != null &&
                                prof['portada_url'].toString().isNotEmpty)
                            ? prof['portada_url']
                            : prof['logo_url'];
                        final String? rubroNombre = prof['rubro_nombre'];
                        final int suscriptores =
                            prof['total_suscriptores'] ?? 0;

                        final List<String> fotosGaleria =
                            (prof['fotos_galeria'] is List)
                            ? (prof['fotos_galeria'] as List)
                                  .map((e) => e.toString())
                                  .where((u) => u.isNotEmpty)
                                  .toList()
                            : [];

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
                            ).then((_) => fetchDestacados());
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.amber.shade600,
                                width: 1.8,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark
                                      ? Colors.black54
                                      : Colors.amber.withValues(alpha: 0.15),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // BANNER SUPERIOR DE PORTADA EXCLUSIVA (135px)
                                SizedBox(
                                  height: 135,
                                  width: double.infinity,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (imagenPortada != null &&
                                          imagenPortada.isNotEmpty)
                                        Image.network(
                                          imagenPortada,
                                          fit: BoxFit.cover,
                                        )
                                      else
                                        Container(
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Color(0xFF0077B6),
                                                Color(0xFF00B4D8),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.storefront,
                                            size: 56,
                                            color: Colors.white38,
                                          ),
                                        ),

                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.black.withValues(
                                                alpha: 0.1,
                                              ),
                                              Colors.black.withValues(
                                                alpha: 0.75,
                                              ),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                      ),

                                      if (rubroNombre != null &&
                                          rubroNombre.isNotEmpty)
                                        Positioned(
                                          top: 10,
                                          left: 10,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(
                                                alpha: 0.65,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              rubroNombre,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),

                                      Positioned(
                                        top: 10,
                                        right: 10,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.amber,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.star,
                                                color: Colors.black,
                                                size: 14,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'DESTACADO VIP',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      Positioned(
                                        bottom: 10,
                                        left: 12,
                                        right: 12,
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 52,
                                              height: 52,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.amber,
                                                  width: 2,
                                                ),
                                                color: Colors.white,
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
                                                  ? const Icon(
                                                      Icons.store,
                                                      color: Color(0xFF00B4D8),
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          prof['nombre_comercial'] ??
                                                              'Sin nombre',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 18,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      const Icon(
                                                        Icons.verified,
                                                        color: Colors.amber,
                                                        size: 18,
                                                      ),
                                                    ],
                                                  ),
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.star,
                                                        color: Colors.amber,
                                                        size: 14,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '${prof['calificacion_promedio'] ?? '5.0'} (${prof['total_resenas'] ?? '0'} op.)',
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                          fontSize: 11.5,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      const Icon(
                                                        Icons.people_alt,
                                                        color: Colors
                                                            .lightBlueAccent,
                                                        size: 14,
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        '$suscriptores suscriptores',
                                                        style: const TextStyle(
                                                          color: Colors
                                                              .lightBlueAccent,
                                                          fontSize: 11.5,
                                                          fontWeight:
                                                              FontWeight.w600,
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
                                    ],
                                  ),
                                ),

                                // CUERPO INFERIOR: DESCRIPCIÓN + CARRUSEL DESLIZABLE DE FOTOS
                                Padding(
                                  padding: const EdgeInsets.all(14.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              prof['descripcion'] != null &&
                                                      prof['descripcion']
                                                          .toString()
                                                          .trim()
                                                          .isNotEmpty
                                                  ? prof['descripcion']
                                                  : 'Profesional / Comercio Destacado en Tartagal',
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.color,
                                                fontSize: 13.5,
                                                height: 1.3,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .primaryColor,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Text(
                                              'Ver Perfil',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      // MINIATURAS DESLIZABLES CON EL DEDO DEBAJO DE LA DESCRIPCIÓN
                                      if (fotosGaleria.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          height: 74,
                                          child: ListView.builder(
                                            scrollDirection: Axis.horizontal,
                                            physics:
                                                const BouncingScrollPhysics(),
                                            itemCount: fotosGaleria.length,
                                            itemBuilder: (context, imgIdx) {
                                              return Container(
                                                width: 82,
                                                margin: const EdgeInsets.only(
                                                  right: 8,
                                                ),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: isDark
                                                        ? Colors.white12
                                                        : Colors.black12,
                                                  ),
                                                  image: DecorationImage(
                                                    image: NetworkImage(
                                                      fotosGaleria[imgIdx],
                                                    ),
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ],
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
      ),
    );
  }
}
