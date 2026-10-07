import 'package:flutter/material.dart';

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'perfil_detalle_screen.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';

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
    _configurarNotificaciones(); // NUEVO: Activamos las notificaciones al inicio
  }

  // ==========================================
  // CONFIGURACIÓN DE NOTIFICACIONES PUSH
  // ==========================================
  Future<void> _configurarNotificaciones() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // 1. Pedimos permiso al usuario (Mostrará un cartel nativo del celular)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Permiso de notificaciones concedido.');

      // 2. Suscribimos al canal "general" SOLO si estamos en un celular (Android/iOS)
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
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.lightBlue)),
      );
    }

    // Definimos qué pantalla se muestra en cada pestaña
    final List<Widget> pantallas = [
      const HomeScreen(),
      const FavoritosScreen(),
      // Lógica dinámica: Si hay sesión muestra el panel, si no, el login.
      profesionalId != null
          ? DashboardScreen(usuarioId: profesionalId!)
          : const LoginScreen(),
    ];

    return Scaffold(
      body: pantallas[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            // Si el usuario toca "Mi Perfil", verificamos la sesión nuevamente
            if (index == 2) {
              _verificarSesion();
            }
          });
        },
        backgroundColor: Colors.black, // Barra oscura estilo Mercado Libre
        selectedItemColor: Colors.lightBlue,
        unselectedItemColor: Colors.white54,
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
// PANTALLA DE FAVORITOS (CON DISEÑO ACTUALIZADO)
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
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text(
          'Mis Guardados',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.black, // Cabecera oscura unificada
        elevation: 0,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: cargarFavoritos(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.lightBlue),
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
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aún no tienes favoritos',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Guarda a los profesionales\npara encontrarlos rápido.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
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
                    // Refrescar la pantalla al volver por si quitó el favorito
                    (context as Element).markNeedsBuild();
                  });
                },
                child: Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.blue[50],
                      backgroundImage: prof['logo_url'] != null
                          ? NetworkImage(prof['logo_url'])
                          : null,
                      child: prof['logo_url'] == null
                          ? const Icon(Icons.store, color: Colors.lightBlue)
                          : null,
                    ),
                    title: Text(
                      prof['nombre_comercial'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
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
