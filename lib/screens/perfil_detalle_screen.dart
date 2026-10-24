import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'visor_imagenes_screen.dart';

class PerfilDetalleScreen extends StatefulWidget {
  final Map<String, dynamic> perfil;
  final int currentUserId;

  const PerfilDetalleScreen({
    super.key,
    required this.perfil,
    required this.currentUserId,
  });

  @override
  State<PerfilDetalleScreen> createState() => _PerfilDetalleScreenState();
}

class _PerfilDetalleScreenState extends State<PerfilDetalleScreen> {
  List<dynamic> resenas = [];
  List<dynamic> galeria = [];
  List<dynamic> profesionalesSimilares = [];
  bool isLoading = true;
  bool isFavorite = false;
  bool isSubscribed = false;
  int totalSuscriptores = 0;

  final _nombreAutorController = TextEditingController();
  final _comentarioController = TextEditingController();
  int _estrellasSeleccionadas = 5;
  bool _enviandoResena = false;

  @override
  void initState() {
    super.initState();
    totalSuscriptores = widget.perfil['total_suscriptores'] ?? 0;
    fetchResenas();
    fetchGaleria();
    verificarSiEsFavorito();
    verificarSiEstaSuscrito();
    registrarVisita();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.displayName != null) {
      _nombreAutorController.text = user.displayName!;
    }

    if (widget.perfil['plan_id'] != 3) {
      _cargarCompetencia();
    }
  }

  @override
  void dispose() {
    _nombreAutorController.dispose();
    _comentarioController.dispose();
    super.dispose();
  }

  String _obtenerMiniaturaCloudinary(String url, String? tipo) {
    if (tipo == 'video' && url.contains('/video/upload/')) {
      return url.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '.jpg');
    }
    return url;
  }

  // ==========================================
  // LÓGICA DE SUSCRIPCIÓN AL NEGOCIO PREMIUM
  // ==========================================
  Future<void> verificarSiEstaSuscrito() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> subs =
        prefs.getStringList('suscripciones_negocios') ?? [];
    if (mounted) {
      setState(() {
        isSubscribed = subs.contains(widget.perfil['id'].toString());
      });
    }
  }

  Future<void> alternarSuscripcion() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> subs =
        prefs.getStringList('suscripciones_negocios') ?? [];
    final String idStr = widget.perfil['id'].toString();
    final bool nuevaSuscripcion = !isSubscribed;

    if (nuevaSuscripcion) {
      subs.add(idStr);
      if (!kIsWeb) {
        try {
          await FirebaseMessaging.instance.subscribeToTopic('negocio_$idStr');
        } catch (_) {}
      }
    } else {
      subs.remove(idStr);
      if (!kIsWeb) {
        try {
          await FirebaseMessaging.instance.unsubscribeFromTopic(
            'negocio_$idStr',
          );
        } catch (_) {}
      }
    }
    await prefs.setStringList('suscripciones_negocios', subs);

    try {
      final res = await http.post(
        Uri.parse(
          'https://guia-norte-backend.onrender.com/api/perfiles/$idStr/suscripcion',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'accion': nuevaSuscripcion ? 'suscribir' : 'desuscribir',
        }),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        totalSuscriptores = data['total_suscriptores'] ?? totalSuscriptores;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        isSubscribed = nuevaSuscripcion;
        widget.perfil['total_suscriptores'] = totalSuscriptores;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSubscribed
                ? '🔔 ¡Te suscribiste! Recibirás alertas cuando publique nuevos artículos o novedades.'
                : 'Suscripción desactivada.',
          ),
          backgroundColor: isSubscribed ? Colors.amber.shade800 : Colors.grey,
        ),
      );
    }
  }

  // ==========================================
  // CARGAR COMPETENCIA
  // ==========================================
  Future<void> _cargarCompetencia() async {
    try {
      final nombreComercial = widget.perfil['nombre_comercial'];
      if (nombreComercial == null) return;

      final url = Uri.parse(
        'https://guia-norte-backend.onrender.com/api/buscar?q=${Uri.encodeComponent(nombreComercial)}',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> todos = json.decode(response.body);
        if (mounted) {
          setState(() {
            profesionalesSimilares = todos
                .where((p) => p['id'] != widget.perfil['id'])
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error cargando competencia: $e');
    }
  }

  Future<void> _abrirRedSocial(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error al abrir enlace: $e');
    }
  }

  Future<void> registrarVisita() async {
    try {
      final url = Uri.parse(
        'https://guia-norte-backend.onrender.com/api/perfiles/${widget.perfil['id']}/visita',
      );
      await http.post(url);
    } catch (e) {
      debugPrint('Error registrando visita: $e');
    }
  }

  Future<void> _contactarWhatsApp() async {
    try {
      final url = Uri.parse(
        'https://guia-norte-backend.onrender.com/api/perfiles/${widget.perfil['id']}/clic-whatsapp',
      );
      await http.post(url);
    } catch (e) {
      debugPrint('Error registrando clic: $e');
    }

    final telefonoBruto = widget.perfil['telefono_contacto'];
    if (telefonoBruto == null || telefonoBruto.toString().trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este profesional no tiene WhatsApp registrado.'),
        ),
      );
      return;
    }

    final String telefonoLimpio = telefonoBruto.toString().replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    final String mensaje =
        'Hola, vi tu perfil en la app Guía del Norte y me gustaría hacerte una consulta.';
    final Uri url = Uri.parse(
      'https://wa.me/$telefonoLimpio?text=${Uri.encodeComponent(mensaje)}',
    );

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error al abrir WhatsApp: $e');
    }
  }

  bool _estaAbierto() {
    final String apertura = widget.perfil['hora_apertura'] ?? '08:00';
    final String cierre = widget.perfil['hora_cierre'] ?? '18:00';
    final now = DateTime.now();

    try {
      final int openHour = int.parse(apertura.split(':')[0]);
      final int openMinute = int.parse(apertura.split(':')[1]);
      final int closeHour = int.parse(cierre.split(':')[0]);
      final int closeMinute = int.parse(cierre.split(':')[1]);

      final double currentTime = now.hour + (now.minute / 60.0);
      final double openTime = openHour + (openMinute / 60.0);
      final double closeTime = closeHour + (closeMinute / 60.0);

      if (closeTime < openTime) {
        return currentTime >= openTime || currentTime <= closeTime;
      }
      return currentTime >= openTime && currentTime <= closeTime;
    } catch (e) {
      return true;
    }
  }

  Future<void> fetchGaleria() async {
    try {
      final url = Uri.parse(
        'https://guia-norte-backend.onrender.com/api/perfiles/${widget.perfil['id']}/galeria',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() => galeria = json.decode(response.body));
        }
      }
    } catch (e) {
      debugPrint('Error cargando galería: $e');
    }
  }

  Future<void> verificarSiEsFavorito() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> favoritosStr = prefs.getStringList('favoritos') ?? [];
    if (mounted) {
      setState(() {
        isFavorite = favoritosStr.any((item) {
          final Map<String, dynamic> fav = json.decode(item);
          return fav['id'] == widget.perfil['id'];
        });
      });
    }
  }

  Future<void> alternarFavorito() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> favoritosStr = prefs.getStringList('favoritos') ?? [];
    if (isFavorite) {
      favoritosStr.removeWhere((item) {
        final Map<String, dynamic> fav = json.decode(item);
        return fav['id'] == widget.perfil['id'];
      });
    } else {
      favoritosStr.add(json.encode(widget.perfil));
    }
    await prefs.setStringList('favoritos', favoritosStr);

    if (mounted) {
      setState(() => isFavorite = !isFavorite);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFavorite ? 'Guardado en Favoritos' : 'Eliminado de Favoritos',
          ),
          backgroundColor: isFavorite ? Colors.green : Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _compartirPerfil() {
    final nombre = widget.perfil['nombre_comercial'];
    Share.share(
      '¡Te recomiendo a *$nombre* en Tartagal! Encuentra su contacto y reseñas en la app Guía del Norte.',
    );
  }

  Future<void> _abrirMapa() async {
    final direccion = widget.perfil['direccion'];
    if (direccion == null || direccion.toString().trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este profesional no registró una dirección física.'),
        ),
      );
      return;
    }
    final query = Uri.encodeComponent('$direccion, Tartagal, Salta, Argentina');
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error al abrir mapas: $e');
    }
  }

  Future<void> fetchResenas() async {
    try {
      final url = Uri.parse(
        'https://guia-norte-backend.onrender.com/api/perfiles/${widget.perfil['id']}/resenas',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        if (mounted) {
          final lista = json.decode(response.body) as List<dynamic>;
          setState(() {
            resenas = lista;
            widget.perfil['total_resenas'] = lista.length;
            if (lista.isNotEmpty) {
              final suma = lista.fold<double>(
                0,
                (acc, item) =>
                    acc + ((item['calificacion'] ?? 5) as num).toDouble(),
              );
              widget.perfil['calificacion_promedio'] = (suma / lista.length)
                  .toStringAsFixed(1);
            }
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> enviarResena(StateSetter setModalState) async {
    if (_comentarioController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor escribe un breve comentario sobre el servicio.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setModalState(() => _enviandoResena = true);

    try {
      final String autorFinal = _nombreAutorController.text.trim().isEmpty
          ? 'Vecino de Tartagal'
          : _nombreAutorController.text.trim();

      final url = Uri.parse(
        'https://guia-norte-backend.onrender.com/api/perfiles/${widget.perfil['id']}/resenas',
      );
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'usuario_id': widget.currentUserId > 0 ? widget.currentUserId : null,
          'nombre_autor': autorFinal,
          'calificacion': _estrellasSeleccionadas,
          'comentario': _comentarioController.text.trim(),
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        _comentarioController.clear();
        if (!mounted) return;
        Navigator.pop(context);
        setState(() => isLoading = true);
        await fetchResenas();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Gracias por dejar tu reseña!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar la reseña. Intenta de nuevo.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error enviando reseña: $e');
    } finally {
      setModalState(() => _enviandoResena = false);
    }
  }

  void _mostrarModalResena() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              final isDark = Theme.of(context).brightness == Brightness.dark;

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Calificar Servicio',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < _estrellasSeleccionadas
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 36,
                          ),
                          onPressed: () => setModalState(
                            () => _estrellasSeleccionadas = index + 1,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nombreAutorController,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Tu nombre (Opcional)',
                        hintText: 'Ej: Juan Pérez o Vecino de Tartagal',
                        prefixIcon: const Icon(Icons.person_outline),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _comentarioController,
                      maxLines: 3,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      decoration: InputDecoration(
                        hintText: '¿Cómo fue tu experiencia con este comercio o profesional?',
                        hintStyle: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _enviandoResena
                            ? null
                            : () => enviarResena(setModalState),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _enviandoResena
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Publicar Reseña',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool abierto = _estaAbierto();
    final int planId = widget.perfil['plan_id'] ?? 1;
    final bool esPremium = planId == 3;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.perfil['nombre_comercial'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite
                  ? Colors.redAccent
                  : Theme.of(context).appBarTheme.iconTheme?.color,
            ),
            onPressed: alternarFavorito,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: Theme.of(context).primaryColor,
        backgroundColor: Theme.of(context).cardColor,
        onRefresh: () async {
          await fetchGaleria();
          await fetchResenas();
          if (planId != 3) {
            await _cargarCompetencia();
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: Theme.of(context).cardColor,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: isDark
                              ? const Color(0xFF2A3143)
                              : Colors.blue[50],
                          backgroundImage: widget.perfil['logo_url'] != null
                              ? NetworkImage(widget.perfil['logo_url'])
                              : null,
                          child: widget.perfil['logo_url'] == null
                              ? Icon(
                                  Icons.store,
                                  size: 40,
                                  color: Theme.of(context).primaryColor,
                                )
                              : null,
                        ),
                        if (esPremium)
                          Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.verified,
                              color: Theme.of(context).primaryColor,
                              size: 28,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.perfil['nombre_comercial'],
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    // ==========================================
                    // CONTADOR DE SUSCRIPTORES Y BOTÓN SUSCRIBIRME (PREMIUM)
                    // ==========================================
                    if (esPremium) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.people_alt,
                                  size: 16,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$totalSuscriptores suscriptores',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.amber
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: alternarSuscripcion,
                            icon: Icon(
                              isSubscribed
                                  ? Icons.notifications_active
                                  : Icons.notifications_none,
                              size: 18,
                            ),
                            label: Text(
                              isSubscribed ? 'Suscrito' : 'Suscribirme',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSubscribed
                                  ? Colors.green
                                  : Colors.amber,
                              foregroundColor: isSubscribed
                                  ? Colors.white
                                  : Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),

                    // ==========================================
                    // SECCIÓN: SOBRE NOSOTROS (Descripción)
                    // ==========================================
                    if (widget.perfil['descripcion'] != null &&
                        widget.perfil['descripcion']
                            .toString()
                            .trim()
                            .isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Sobre nosotros',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.perfil['descripcion'],
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.perfil['calificacion_promedio'] ?? '0.0'} (${widget.perfil['total_resenas'] ?? '0'} opiniones)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: abierto
                            ? (isDark
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : Colors.green[50])
                            : (isDark
                                  ? Colors.red.withValues(alpha: 0.2)
                                  : Colors.red[50]),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: abierto ? Colors.green : Colors.red,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            abierto ? Icons.check_circle : Icons.cancel,
                            color: abierto ? Colors.green : Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            abierto ? 'Abierto Ahora' : 'Cerrado',
                            style: TextStyle(
                              color: abierto ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (planId > 1) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _contactarWhatsApp,
                          icon: const Icon(Icons.chat, color: Colors.white),
                          label: const Text(
                            'Contactar por WhatsApp',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? Colors.white24
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.phone_android,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Teléfono: ${widget.perfil['telefono_contacto'] ?? 'No disponible'}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Copia este número para contactarlo.',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _abrirMapa,
                            icon: Icon(
                              Icons.location_on,
                              color: Theme.of(context).primaryColor,
                              size: 18,
                            ),
                            label: Text(
                              'Cómo llegar',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Theme.of(context).primaryColor,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _compartirPerfil,
                            icon: Icon(
                              Icons.share,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.color,
                              size: 18,
                            ),
                            label: Text(
                              'Compartir',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: isDark ? Colors.white54 : Colors.black87,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // ==========================================
                    // REDES SOCIALES Y PÁGINA WEB (Solo Premium)
                    // ==========================================
                    if (planId == 3 &&
                        ((widget.perfil['sitio_web'] != null &&
                                widget.perfil['sitio_web']
                                    .toString()
                                    .trim()
                                    .isNotEmpty) ||
                            (widget.perfil['instagram'] != null &&
                                widget.perfil['instagram']
                                    .toString()
                                    .isNotEmpty) ||
                            (widget.perfil['facebook'] != null &&
                                widget.perfil['facebook']
                                    .toString()
                                    .isNotEmpty))) ...[
                      const SizedBox(height: 16),
                      const Divider(color: Colors.grey),
                      const SizedBox(height: 8),
                      Text(
                        'Web Oficial y Redes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      if (widget.perfil['sitio_web'] != null &&
                          widget.perfil['sitio_web']
                              .toString()
                              .trim()
                              .isNotEmpty) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              String rawUrl = widget.perfil['sitio_web']
                                  .toString()
                                  .trim();
                              if (!rawUrl.startsWith('http://') &&
                                  !rawUrl.startsWith('https://')) {
                                rawUrl = 'https://$rawUrl';
                              }
                              _abrirRedSocial(rawUrl);
                            },
                            icon: const Icon(
                              Icons.language,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Visitar Página Web Oficial',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0077B6),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.perfil['instagram'] != null &&
                              widget.perfil['instagram'].toString().isNotEmpty)
                            IconButton(
                              onPressed: () =>
                                  _abrirRedSocial(widget.perfil['instagram']),
                              icon: const Icon(
                                Icons.camera_alt,
                                color: Colors.purpleAccent,
                                size: 32,
                              ),
                              tooltip: 'Instagram',
                            ),
                          if (widget.perfil['facebook'] != null &&
                              widget.perfil['facebook'].toString().isNotEmpty)
                            IconButton(
                              onPressed: () =>
                                  _abrirRedSocial(widget.perfil['facebook']),
                              icon: const Icon(
                                Icons.facebook,
                                color: Colors.blue,
                                size: 32,
                              ),
                              tooltip: 'Facebook',
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ==========================================
              // SECCIÓN DE GALERÍA (FOTOS Y VIDEOS)
              // ==========================================
              if (galeria.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Portafolio y Trabajos (${galeria.length})',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 155,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: galeria.length,
                    itemBuilder: (context, index) {
                      final item = galeria[index];
                      final bool esVideo = item['tipo'] == 'video';
                      final String thumbUrl = _obtenerMiniaturaCloudinary(
                        item['imagen_url'],
                        item['tipo'],
                      );

                      return GestureDetector(
                        onTap: () async {
                          if (esVideo) {
                            await launchUrl(
                              Uri.parse(item['imagen_url']),
                              mode: LaunchMode.externalApplication,
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VisorImagenesScreen(
                                  galeria: galeria,
                                  indexInicial: index,
                                ),
                              ),
                            );
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          width: 155,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: NetworkImage(thumbUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: esVideo
                              ? Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black38,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.play_circle_fill,
                                      color: Colors.white,
                                      size: 46,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ==========================================
              // SECCIÓN DE RESEÑAS (LIBRE SIN LOGIN)
              // ==========================================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Opiniones de clientes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _mostrarModalResena,
                      icon: Icon(
                        Icons.rate_review,
                        size: 18,
                        color: Theme.of(context).primaryColor,
                      ),
                      label: Text(
                        'Dejar Reseña',
                        style: TextStyle(color: Theme.of(context).primaryColor),
                      ),
                    ),
                  ],
                ),
              ),

              isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    )
                  : resenas.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'Sé el primero en dejar una reseña.',
                          style: TextStyle(
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: resenas.length,
                      separatorBuilder: (context, index) => Divider(
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                      itemBuilder: (context, index) {
                        final r = resenas[index];
                        final String autorNombre =
                            (r['autor'] != null &&
                                r['autor'].toString().trim().isNotEmpty)
                            ? r['autor'].toString()
                            : 'Vecino de Tartagal';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isDark
                                ? const Color(0xFF2A3143)
                                : Colors.grey[300],
                            child: Text(
                              autorNombre[0].toUpperCase(),
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  autorNombre,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Row(
                                children: List.generate(5, (starIndex) {
                                  return Icon(
                                    starIndex < (r['calificacion'] ?? 5)
                                        ? Icons.star
                                        : Icons.star_border,
                                    size: 14,
                                    color: Colors.amber,
                                  );
                                }),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              r['comentario'] ?? '',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
              const SizedBox(height: 30),

              if (planId != 3 && profesionalesSimilares.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Otros profesionales similares',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 130,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: profesionalesSimilares.length,
                    itemBuilder: (context, index) {
                      final comp = profesionalesSimilares[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PerfilDetalleScreen(
                                perfil: comp,
                                currentUserId: widget.currentUserId,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 250,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white10 : Colors.black12,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isDark
                                    ? const Color(0xFF2A3143)
                                    : Colors.grey[200],
                                backgroundImage: comp['logo_url'] != null
                                    ? NetworkImage(comp['logo_url'])
                                    : null,
                                child: comp['logo_url'] == null
                                    ? Icon(
                                        Icons.store,
                                        color: Theme.of(context).primaryColor,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      comp['nombre_comercial'],
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.color,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${comp['calificacion_promedio'] ?? '5.0'}',
                                          style: const TextStyle(
                                            color: Colors.amber,
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
                      );
                    },
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
