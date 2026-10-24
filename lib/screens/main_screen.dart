import 'package:flutter/material.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';

import 'home_screen.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'perfil_detalle_screen.dart';
import 'soporte_notificaciones_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int? profesionalId;
  bool isLoading = true;

  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);

    _verificarSesion();
    _configurarNotificaciones();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ==========================================
  // FUNCIÓN QUE ABRE EL PERFIL AL TOCAR LA NOTIFICACIÓN PUSH
  // ==========================================
  Future<void> _abrirPerfilDesdeNotificacion(RemoteMessage message) async {
    final perfilId = message.data['perfil_id'];
    if (perfilId == null || perfilId.toString().trim().isEmpty) return;

    try {
      final res = await http.get(
        Uri.parse(
          'https://guia-norte-backend.onrender.com/api/perfiles/$perfilId',
        ),
      );
      if (res.statusCode == 200) {
        final perfilData = json.decode(res.body);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PerfilDetalleScreen(
              perfil: perfilData,
              currentUserId: profesionalId ?? 0,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error abriendo perfil desde notificación: $e');
    }
  }

  // ==========================================
  // CONFIGURACIÓN DE NOTIFICACIONES PUSH Y LISTENERS DE CLIC
  // ==========================================
  Future<void> _configurarNotificaciones() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Permiso de notificaciones concedido.');

      if (!kIsWeb) {
        try {
          await messaging.subscribeToTopic('general');
          debugPrint('Suscrito al tema: general');
        } catch (e) {
          debugPrint('Error al suscribirse al tema: $e');
        }
      }
    }

    // 1. Si la app estaba totalmente CERRADA y el usuario entró tocando la notificación:
    RemoteMessage? initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      Future.delayed(const Duration(milliseconds: 600), () {
        _abrirPerfilDesdeNotificacion(initialMessage);
      });
    }

    // 2. Si la app estaba en SEGUNDO PLANO (minimizada) y el usuario tocó la notificación:
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _abrirPerfilDesdeNotificacion(message);
    });

    // 3. Si el usuario tiene la app ABIERTA en el momento que llega la notificación:
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (!mounted) return;
      final titulo = message.notification?.title ?? 'Nueva notificación';
      final cuerpo = message.notification?.body ?? '';
      final tienePerfil =
          message.data['perfil_id'] != null &&
          message.data['perfil_id'].toString().isNotEmpty;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$titulo\n$cuerpo'),
          duration: const Duration(seconds: 6),
          action: tienePerfil
              ? SnackBarAction(
                  label: 'VER PERFIL',
                  textColor: Colors.amber,
                  onPressed: () => _abrirPerfilDesdeNotificacion(message),
                )
              : null,
        ),
      );
    });
  }

  Future<void> _verificarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      profesionalId = prefs.getInt('profesional_id');
      isLoading = false;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
      if (index == 2) {
        _verificarSesion();
      }
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      if (index == 2) {
        _verificarSesion();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).primaryColor,
          ),
        ),
      );
    }

    final List<Widget> pantallas = [
      const HomeScreen(),
      const FavoritosScreen(),
      profesionalId != null
          ? DashboardScreen(usuarioId: profesionalId!)
          : const LoginScreen(),
      const SoporteNotificacionesScreen(), // <-- NUEVA PESTAÑA 4
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const BouncingScrollPhysics(),
        children: pantallas,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: isDark ? Colors.white54 : Colors.black54,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Buscar'),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            activeIcon: Icon(Icons.favorite),
            label: 'Favoritos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Mi Perfil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.help_outline),
            activeIcon: Icon(Icons.support_agent),
            label: 'Soporte',
          ),
        ],
      ),
    );
  }
}

// ==========================================
// PANTALLA DE FAVORITOS (TEMA DINÁMICO)
// ==========================================
class FavoritosScreen extends StatelessWidget {
  const FavoritosScreen({super.key});

  Future<List<dynamic>> cargarFavoritos() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> favoritosStr = prefs.getStringList('favoritos') ?? [];
    return favoritosStr.map((item) => json.decode(item)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mis Guardados',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: cargarFavoritos(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).primaryColor,
              ),
            );
          }

          final profesionalesGuardados = snapshot.data ?? [];

          if (profesionalesGuardados.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 64,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aún no tienes favoritos',
                    style: TextStyle(
                      fontSize: 18,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Guarda a los profesionales\npara encontrarlos rápido.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: profesionalesGuardados.length,
            itemBuilder: (context, index) {
              final prof = profesionalesGuardados[index];

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          PerfilDetalleScreen(perfil: prof, currentUserId: 1),
                    ),
                  ).then((_) {
                    (context as Element).markNeedsBuild();
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? const Color(0xFF2A3143)
                            : Colors.grey[200],
                        image: prof['logo_url'] != null
                            ? DecorationImage(
                                image: NetworkImage(prof['logo_url']),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: prof['logo_url'] == null
                          ? Icon(
                              Icons.store,
                              color: Theme.of(context).primaryColor,
                            )
                          : null,
                    ),
                    title: Text(
                      prof['nombre_comercial'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              prof['calificacion_promedio']?.toString() ??
                                  '0.0',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
