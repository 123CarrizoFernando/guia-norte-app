import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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
  Map<int, List<String>> galeriasPorPerfil = {};
  Set<int> favoritosIds = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _inicializarBusqueda();
  }

  Future<void> _inicializarBusqueda() async {
    await _cargarFavoritosLocales();
    await buscarProfesionales();
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
    if (mounted) setState(() => favoritosIds = ids);
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

  Future<void> buscarProfesionales() async {
    try {
      final url = Uri.parse(
        'https://guia-norte-backend.onrender.com/api/buscar?q=${Uri.encodeComponent(widget.query)}',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> lista = json.decode(response.body);
        if (!mounted) return;
        setState(() {
          profesionales = lista;
          isLoading = false;
        });

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
      debugPrint('Error: $e');
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
          'Resultados para "${widget.query}"',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF161B26),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00B4D8)),
            )
          : profesionales.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No encontramos resultados para "${widget.query}"',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            )
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
                                                ),
                                                child: const Text(
                                                  'DESTACADO',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
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
