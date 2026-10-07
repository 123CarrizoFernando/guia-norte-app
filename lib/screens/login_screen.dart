import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart'; // NUEVA IMPORTACIÓN VITAL

import 'crear_perfil_screen.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLoading = false;

  Future<void> signInWithGoogle() async {
    setState(() {
      isLoading = true;
    });

    try {
      final provider = GoogleAuthProvider();
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithPopup(provider);
      final User? user = userCredential.user;

      if (user != null) {
        final url = Uri.parse('http://localhost:3000/api/auth/google');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'firebase_uid': user.uid,
            'email': user.email,
            'nombre_completo': user.displayName ?? 'Usuario',
          }),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final bool tienePerfil = data['tienePerfil'];

          // ==========================================
          // LA MAGIA QUE FALTABA: GUARDAR EL ID EN MEMORIA
          // ==========================================
          if (tienePerfil) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('profesional_id', data['usuario']['id']);
          }

          if (!mounted) return;

          if (tienePerfil) {
            // Ahora sí, cuando el MainScreen pregunte, encontrará el ID y mostrará el Dashboard
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => const MainScreen(initialIndex: 2),
              ),
              (route) => false,
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    CrearPerfilScreen(usuarioId: data['usuario']['id']),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Error en login: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.storefront, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 24),
              const Text(
                'Panel para Profesionales',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ofrece tus servicios en la Guía del Norte',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 48),
              isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: signInWithGoogle,
                      icon: Image.network(
                        'https://cdn-icons-png.flaticon.com/512/2991/2991148.png',
                        height: 24,
                      ),
                      label: const Text('Continuar con Google'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
