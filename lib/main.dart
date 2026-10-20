import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'screens/main_screen.dart';

// ==========================================
// VARIABLES GLOBALES: Tema Claro Oficial y Navegador para Notificaciones
// ==========================================
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ==========================================
// 1. MANEJADOR DE NOTIFICACIONES EN SEGUNDO PLANO
// ==========================================
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Mensaje recibido en segundo plano: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const GuiaDelNorteApp());
}

class GuiaDelNorteApp extends StatelessWidget {
  const GuiaDelNorteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, _) {
        return MaterialApp(
          title: 'Guía del Norte',
          navigatorKey:
              navigatorKey, // Clave para abrir perfiles desde notificaciones
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,

          // ==========================================
          // TEMA CLARO (PRINCIPAL Y OFICIAL)
          // ==========================================
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: Colors.grey[100],
            primaryColor: const Color(0xFF00B4D8),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              iconTheme: IconThemeData(color: Colors.black87),
              elevation: 1,
            ),
            cardColor: Colors.white,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF00B4D8),
              brightness: Brightness.light,
            ),
          ),

          // ==========================================
          // TEMA OSCURO (SECUNDARIO / OPCIONAL)
          // ==========================================
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0B101E),
            primaryColor: const Color(0xFF00B4D8),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              iconTheme: IconThemeData(color: Colors.white),
              elevation: 0,
            ),
            cardColor: const Color(0xFF1A1F2E),
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
