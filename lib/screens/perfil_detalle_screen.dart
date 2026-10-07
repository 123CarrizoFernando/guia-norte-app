import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool isLoading = true;
  bool isFavorite = false;

  final _comentarioController = TextEditingController();
  int _estrellasSeleccionadas = 5;

  @override
  void initState() {
    super.initState();
    fetchResenas();
    fetchGaleria();
    verificarSiEsFavorito();
    registrarVisita(); // NUEVO: Registra la visita al abrir el perfil
  }

  // ==========================================
  // LÓGICA DE ESTADÍSTICAS (NUEVO)
  // ==========================================
  Future<void> registrarVisita() async {
    try {
      final url = Uri.parse(
        'http://localhost:3000/api/perfiles/${widget.perfil['id']}/visita',
      );
      await http.post(url);
    } catch (e) {
      debugPrint('Error registrando visita: $e');
    }
  }

  Future<void> _contactarWhatsApp() async {
    // 1. Registrar el clic en la base de datos
    try {
      final url = Uri.parse(
        'http://localhost:3000/api/perfiles/${widget.perfil['id']}/clic-whatsapp',
      );
      await http.post(url);
    } catch (e) {
      debugPrint('Error registrando clic: $e');
    }

    // 2. Abrir WhatsApp
    final telefono = widget.perfil['telefono_contacto'];
    if (telefono == null || telefono.toString().trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este profesional no tiene WhatsApp registrado.'),
        ),
      );
      return;
    }

    final String mensaje =
        'Hola, vi tu perfil en la app Guía del Norte y me gustaría hacerte una consulta.';
    final Uri url = Uri.parse(
      'https://wa.me/$telefono?text=${Uri.encodeComponent(mensaje)}',
    );

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error al abrir WhatsApp: $e');
    }
  }

  // ==========================================
  // LÓGICA DE HORARIOS (NUEVO)
  // ==========================================
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
        // Si cierra al día siguiente (ej. 20:00 a 02:00)
        return currentTime >= openTime || currentTime <= closeTime;
      }
      return currentTime >= openTime && currentTime <= closeTime;
    } catch (e) {
      return true; // Por defecto abierto si hay error en el formato
    }
  }

  // ==========================================
  // RESTO DEL CÓDIGO (Galería, Favoritos, Mapas, Reseñas...)
  // ==========================================
  Future<void> fetchGaleria() async {
    try {
      final url = Uri.parse(
        'http://localhost:3000/api/perfiles/${widget.perfil['id']}/galeria',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() => galeria = json.decode(response.body));
      }
    } catch (e) {
      debugPrint('Error cargando galería: $e');
    }
  }

  Future<void> verificarSiEsFavorito() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> favoritosStr = prefs.getStringList('favoritos') ?? [];
    setState(() {
      isFavorite = favoritosStr.any((item) {
        final Map<String, dynamic> fav = json.decode(item);
        return fav['id'] == widget.perfil['id'];
      });
    });
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
    setState(() => isFavorite = !isFavorite);

    if (!mounted) return;
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
        'http://localhost:3000/api/perfiles/${widget.perfil['id']}/resenas',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          resenas = json.decode(response.body);
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _verificarYMostrarModal() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      try {
        if (kIsWeb) {
          GoogleAuthProvider authProvider = GoogleAuthProvider();
          final UserCredential userCredential = await FirebaseAuth.instance
              .signInWithPopup(authProvider);
          user = userCredential.user;
        } else {
          final googleSignIn = GoogleSignIn.instance;
          await googleSignIn.initialize();
          final GoogleSignInAccount googleUser = await googleSignIn
              .authenticate();
          final GoogleSignInAuthentication googleAuth =
              await googleUser.authentication;
          final AuthCredential credential = GoogleAuthProvider.credential(
            idToken: googleAuth.idToken,
          );
          final UserCredential userCredential = await FirebaseAuth.instance
              .signInWithCredential(credential);
          user = userCredential.user;
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al iniciar sesión')),
          );
        return;
      }
    }

    if (user != null) {
      try {
        final url = Uri.parse('http://localhost:3000/api/clientes/auth');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'uid': user.uid,
            'email': user.email,
            'nombre_completo': user.displayName ?? 'Cliente',
          }),
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final int dbUserId = data['usuario_id'];
          if (!mounted) return;
          _mostrarModalResena(dbUserId);
        }
      } catch (e) {}
    }
  }

  Future<void> enviarResena(int usuarioIdDb) async {
    if (_comentarioController.text.isEmpty) return;
    try {
      final url = Uri.parse(
        'http://localhost:3000/api/perfiles/${widget.perfil['id']}/resenas',
      );
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'usuario_id': usuarioIdDb,
          'calificacion': _estrellasSeleccionadas,
          'comentario': _comentarioController.text,
        }),
      );
      if (response.statusCode == 201) {
        _comentarioController.clear();
        setState(() => isLoading = true);
        fetchResenas();
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Gracias por tu reseña!')),
        );
      }
    } catch (e) {}
  }

  void _mostrarModalResena(int usuarioIdDb) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Calificar Servicio',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 16),
                  TextField(
                    controller: _comentarioController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText:
                          '¿Cómo fue tu experiencia con este profesional?',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => enviarResena(usuarioIdDb),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Enviar Reseña',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
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

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: Text(
          widget.perfil['nombre_comercial'],
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? Colors.redAccent : Colors.white,
            ),
            onPressed: alternarFavorito,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==========================================
            // CABECERA DEL PERFIL
            // ==========================================
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blue[50],
                    backgroundImage: widget.perfil['logo_url'] != null
                        ? NetworkImage(widget.perfil['logo_url'])
                        : null,
                    child: widget.perfil['logo_url'] == null
                        ? const Icon(
                            Icons.store,
                            size: 40,
                            color: Colors.lightBlue,
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.perfil['nombre_comercial'],
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.perfil['descripcion'],
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 16),

                  // Reseñas y Puntuación
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.perfil['calificacion_promedio'] ?? '0.0'} (${widget.perfil['total_resenas'] ?? '0'} opiniones)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // INDICADOR ABIERTO/CERRADO
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: abierto ? Colors.green[50] : Colors.red[50],
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
                            color: abierto
                                ? Colors.green[700]
                                : Colors.red[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // BOTÓN GIGANTE DE WHATSAPP (Suma un clic)
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
                        backgroundColor: const Color(
                          0xFF25D366,
                        ), // Color oficial de WhatsApp
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Botones secundarios de Mapas y Compartir
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _abrirMapa,
                          icon: const Icon(
                            Icons.location_on,
                            color: Colors.lightBlue,
                            size: 18,
                          ),
                          label: const Text(
                            'Cómo llegar',
                            style: TextStyle(color: Colors.lightBlue),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.lightBlue),
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
                          icon: const Icon(
                            Icons.share,
                            color: Colors.black87,
                            size: 18,
                          ),
                          label: const Text(
                            'Compartir',
                            style: TextStyle(color: Colors.black87),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.black87),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ==========================================
            // SECCIÓN DE GALERÍA
            // ==========================================
            if (galeria.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Trabajos Realizados',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 150,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: galeria.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: NetworkImage(galeria[index]['imagen_url']),
                          fit: BoxFit.cover,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ==========================================
            // SECCIÓN DE RESEÑAS
            // ==========================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Opiniones de clientes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: _verificarYMostrarModal,
                    icon: const Icon(
                      Icons.rate_review,
                      size: 18,
                      color: Colors.lightBlue,
                    ),
                    label: const Text(
                      'Dejar Reseña',
                      style: TextStyle(color: Colors.lightBlue),
                    ),
                  ),
                ],
              ),
            ),

            isLoading
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : resenas.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'Sé el primero en dejar una reseña.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: resenas.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final r = resenas[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey[300],
                          child: Text(
                            r['autor'][0].toUpperCase(),
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              r['autor'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Row(
                              children: List.generate(5, (starIndex) {
                                return Icon(
                                  starIndex < r['calificacion']
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
                          child: Text(r['comentario']),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
