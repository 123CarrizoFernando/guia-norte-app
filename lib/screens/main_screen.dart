import 'package:flutter/material.dart';

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';

import 'home_screen.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'perfil_detalle_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _verificarSesion();
    _configurarNotificaciones();
  }

  // ==========================================
  // CONFIGURACIÓN DE NOTIFICACIONES PUSH
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
      } else {
        debugPrint(
          'Suscripción a temas ignorada (No soportado en versión Web).',
        );
      }
    } else {
      debugPrint('El usuario denegó los permisos de notificación.');
    }
  }

  // Verifica si el profesional inició sesión
  Future<void> _verificarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      profesionalId = prefs.getInt('profesional_id');
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Detectamos si el tema actual es oscuro
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

    // Definimos qué pantalla se muestra en cada pestaña
    final List<Widget> pantallas = [
      const HomeScreen(),
      const FavoritosScreen(),
      profesionalId != null
          ? DashboardScreen(usuarioId: profesionalId!)
          : const LoginScreen(),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: pantallas[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            if (index == 2) {
              _verificarSesion();
            }
          });
        },
        // Adaptación automática de colores
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
      // El Scaffold tomará automáticamente el color de fondo definido en main.dart
      appBar: AppBar(
        title: const Text(
          'Mis Guardados',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        // La AppBar tomará automáticamente los colores de appBarTheme en main.dart
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
                    color: Theme.of(context).cardColor, // Se adapta al tema
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
