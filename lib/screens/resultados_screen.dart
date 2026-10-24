import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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
  Map<int, List<String>> galeriasPorPerfil = {};
  Set<int> favoritosIds = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    await _cargarFavoritosLocales();
    await fetchProfesionales();
  }

  Future<void> _cargarFavoritosLocales() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> favs = prefs.getStringList('favoritos') ?? [];
    final Set<int> ids = {};
    for (final item in favs) {
      try {
        final Map<String, dynamic> map = json.decode(item);
        if (map['id'] != null) ids.add(map['id'] as int);
      } catch (_) {}
    }
    if (mounted) {
      setState(() => favoritosIds = ids);
    }
  }

  Future<void> _alternarFavorito(Map<String, dynamic> prof) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> favs = prefs.getStringList('favoritos') ?? [];
    final int id = prof['id'];

    if (favoritosIds.contains(id)) {
      favs.removeWhere((item) {
        try {
          return json.decode(item)['id'] == id;
        } catch (_) {
          return false;
        }
      });
      favoritosIds.remove(id);
    } else {
      favs.add(json.encode(prof));
      favoritosIds.add(id);
    }

    await prefs.setStringList('favoritos', favs);
    if (mounted) setState(() {});
  }

  Future<void> fetchProfesionales() async {
    try {
      final url = Uri.parse(
        'https://guia-norte-backend.onrender.com/api/rubros/${widget.rubroId}/profesionales',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> lista = json.decode(response.body);
        if (!mounted) return;
        setState(() {
          profesionales = lista;
          isLoading = false;
        });

        // Cargar las 4 miniaturas de cada perfil (usa fotos_galeria si viene del backend, o consulta su galería)
        for (final prof in lista) {
          final int id = prof['id'];
          final int planId = prof['plan_id'] ?? prof['nivel'] ?? 1;
          if (planId > 1) {
            if (prof['fotos_galeria'] != null &&
                prof['fotos_galeria'] is List) {
              final List<String> urls = (prof['fotos_galeria'] as List)
                  .map((e) => e.toString())
                  .where((u) => u.isNotEmpty)
                  .take(4)
                  .toList();
              if (urls.isNotEmpty && mounted) {
                setState(() => galeriasPorPerfil[id] = urls);
                continue;
              }
            }
            _cargarGaleriaIndividual(id);
          }
        }
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('Error en la petición: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _cargarGaleriaIndividual(int perfilId) async {
    try {
      final res = await http.get(
        Uri.parse(
          'https://guia-norte-backend.onrender.com/api/perfiles/$perfilId/galeria',
        ),
      );
      if (res.statusCode == 200 && mounted) {
        final List<dynamic> data = json.decode(res.body);
        final List<String> urls = data
            .map((img) => (img['imagen_url'] ?? '').toString())
            .where((u) => u.isNotEmpty)
            .take(4)
            .toList();
        if (urls.isNotEmpty) {
          setState(() => galeriasPorPerfil[perfilId] = urls);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0B101E)
          : const Color(0xFFEDEFF2),
      appBar: AppBar(
        title: Text(
          widget.rubroNombre,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF161B26),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00B4D8)),
            )
          : profesionales.isEmpty
          ? const Center(child: Text("Aún no hay profesionales en este rubro."))
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: profesionales.length,
              itemBuilder: (context, index) {
                final prof = profesionales[index];
                final int id = prof['id'];
                final int planId = prof['plan_id'] ?? prof['nivel'] ?? 1;
                final bool isDestacado = planId >= 2;
                final bool esFav = favoritosIds.contains(id);
                final List<String> fotos = galeriasPorPerfil[id] ?? [];

                final double calificacion =
                    double.tryParse(
                      (prof['calificacion_promedio'] ?? '0.0').toString(),
                    ) ??
                    0.0;

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            PerfilDetalleScreen(perfil: prof, currentUserId: 1),
                      ),
                    ).then((_) => _cargarFavoritosLocales());
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      gradient: isDark
                          ? const LinearGradient(
                              colors: [Color(0xFF1A2234), Color(0xFF141A29)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : const LinearGradient(
                              colors: [Color(0xFFF4F9FF), Color(0xFFE6F0FA)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDestacado
                            ? const Color(0xFF00C4FF)
                            : (isDark ? Colors.white24 : Colors.grey.shade400),
                        width: isDestacado ? 2.2 : 1.0,
                      ),
                      boxShadow: [
                        if (isDestacado)
                          BoxShadow(
                            color: const Color(0xFF00B4D8)
                                .withValues(alpha: 0.35),
                            blurRadius: 12,
                            spreadRadius: 1,
                            offset: const Offset(0, 3),
                          )
                        else
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // CABECERA: LOGO CIRCULAR + NOMBRE + INSIGNIA DESTACADO + CORAZÓN
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(
                                    color: isDestacado
                                        ? const Color(0xFF00B4D8)
                                        : Colors.grey.shade300,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 5,
                                    ),
                                  ],
                                  image:
                                      prof['logo_url'] != null &&
                                          prof['logo_url'].toString().isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(prof['logo_url']),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child:
                                    (prof['logo_url'] == null ||
                                        prof['logo_url'].toString().isEmpty)
                                    ? const Icon(
                                        Icons.storefront,
                                        size: 34,
                                        color: Color(0xFF00B4D8),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 14),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            prof['nombre_comercial'] ??
                                                'Sin nombre',
                                            style: TextStyle(
                                              fontSize: 19,
                                              fontWeight: FontWeight.w800,
                                              height: 1.15,
                                              color: isDark
                                                  ? Colors.white
                                                  : const Color(0xFF111827),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            if (isDestacado)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 5,
                                                    ),
                                                decoration: BoxDecoration(
                                                  gradient:
                                                      const LinearGradient(
                                                        colors: [
                                                          Color(0xFF00C4B4),
                                                          Color(0xFF0088FF),
                                                        ],
                                                      ),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.blue
                                                          .withValues(
                                                            alpha: 0.3,
                                                          ),
                                                      blurRadius: 4,
                                                      offset: const Offset(
                                                        0,
                                                        2,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                child: const Text(
                                                  'DESTACADO',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.4,
                                                  ),
                                                ),
                                              ),
                                            const SizedBox(height: 6),
                                            GestureDetector(
                                              onTap: () =>
                                                  _alternarFavorito(prof),
                                              child: Icon(
                                                esFav
                                                    ? Icons.favorite
                                                    : Icons.favorite_border,
                                                color: esFav
                                                    ? Colors.redAccent
                                                    : (isDark
                                                          ? Colors.white60
                                                          : Colors.black54),
                                                size: 24,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          calificacion.toStringAsFixed(2),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
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

                          // DESCRIPCIÓN DEL COMERCIO / PROFESIONAL
                          Text(
                            (prof['descripcion'] != null &&
                                    prof['descripcion']
                                        .toString()
                                        .trim()
                                        .isNotEmpty)
                                ? prof['descripcion']
                                : 'Servicio disponible en Tartagal.',
                            style: TextStyle(
                              fontSize: 14.5,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF1F2937),
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          // FILA DE MINIATURAS DEL PORTAFOLIO (Hasta 4 fotos abajo tal cual el diseño)
                          if (fotos.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 76,
                              child: Row(
                                children: List.generate(
                                  fotos.length > 4 ? 4 : fotos.length,
                                  (imgIndex) {
                                    return Expanded(
                                      child: Container(
                                        margin: EdgeInsets.only(
                                          right: imgIndex < 3 ? 8 : 0,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.08,
                                              ),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                          image: DecorationImage(
                                            image: NetworkImage(
                                              fotos[imgIndex],
                                            ),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
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
