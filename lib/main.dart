import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'screens/main_screen.dart';

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
    return MaterialApp(
      title: 'Guía del Norte',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}
