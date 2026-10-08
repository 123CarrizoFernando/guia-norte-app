import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'screens/main_screen.dart';

// ==========================================
// VARIABLE GLOBAL MAGICA: Controla el tema de toda la app
// ==========================================
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

// ==========================================
// 1. MANEJADOR DE NOTIFICACIONES EN SEGUNDO PLANO
// Debe estar afuera de cualquier clase para funcionar con la app cerrada
// ==========================================
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Mensaje recibido en segundo plano: ${message.messageId}");
}

void main() async {
  // 2. Asegurar la inicialización de los widgets de Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // 3. Inicializar Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 4. Configurar el receptor de notificaciones en segundo plano
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 5. Arrancar la aplicación
  runApp(const GuiaDelNorteApp());
}

class GuiaDelNorteApp extends StatelessWidget {
  const GuiaDelNorteApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder "escucha" los cambios del botón y repinta la app
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'Guía del Norte',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode, // Aquí aplicamos el tema actual
          // ==========================================
          // TEMA CLARO
          // ==========================================
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor:
                Colors.grey[100], // Gris muy clarito de fondo
            primaryColor: const Color(0xFF00B4D8), // Celeste Guía del Norte
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black, // Títulos negros
              iconTheme: IconThemeData(color: Colors.black87), // Íconos negros
              elevation: 1,
            ),
            cardColor: Colors.white, // Tarjetas blancas
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF00B4D8),
              brightness: Brightness.light,
            ),
          ),

          // ==========================================
          // TEMA OSCURO
          // ==========================================
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0B101E), // Azul noche
            primaryColor: const Color(0xFF00B4D8), // Celeste Guía del Norte
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white, // Títulos blancos
              iconTheme: IconThemeData(color: Colors.white), // Íconos blancos
              elevation: 0,
            ),
            cardColor: const Color(0xFF1A1F2E), // Tarjetas azul oscuro
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF00B4D8),
              brightness: Brightness.dark,
            ),
          ),

          home: const MainScreen(),
        );
      },
    );
  }
}
