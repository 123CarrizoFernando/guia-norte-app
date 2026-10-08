import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';

import 'editar_perfil_screen.dart';
import 'main_screen.dart';
import 'visor_imagenes_screen.dart';
import '../main.dart';

class DashboardScreen extends StatefulWidget {
  final int usuarioId;
  const DashboardScreen({super.key, required this.usuarioId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? perfilData;
  List<dynamic> miGaleria = [];
  bool isLoading = true;
  bool isUploading = false;

  @override
  void initState() {
    super.initState();
    cargarPerfilYGaleria();
  }

  Future<void> cargarPerfilYGaleria() async {
    try {
      final urlPerfil = Uri.parse(
        'https://guia-norte-backend.onrender.com/api/usuarios/${widget.usuarioId}/perfil',
      );
      final responsePerfil = await http.get(urlPerfil);

      if (responsePerfil.statusCode == 200) {
        final data = json.decode(responsePerfil.body);
        setState(() => perfilData = data);

        final urlGaleria = Uri.parse(
          'https://guia-norte-backend.onrender.com/api/perfiles/${data['id']}/galeria',
        );
        final responseGaleria = await http.get(urlGaleria);

        if (responseGaleria.statusCode == 200) {
          setState(() => miGaleria = json.decode(responseGaleria.body));
        }
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _subirFotoGaleria() async {
    final picker = ImagePicker();
    final XFile? imagen = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (imagen == null) return;

    setState(() => isUploading = true);

    try {
      final bytes = await imagen.readAsBytes();
      const cloudName = 'ymlcqawz';
      final urlCloudinary = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );
      final request = http.MultipartRequest('POST', urlCloudinary)
        ..fields['upload_preset'] = 'guia_norte_preset';
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: imagen.name),
      );

      final responseCloudinary = await request.send();
      if (responseCloudinary.statusCode == 200) {
        final responseData = await responseCloudinary.stream.toBytes();
        final jsonMap = json.decode(utf8.decode(responseData));
        final secureUrl = jsonMap['secure_url'];

        await http.post(
          Uri.parse(
            'https://guia-norte-backend.onrender.com/api/perfiles/${perfilData!['id']}/galeria',
          ),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'imagen_url': secureUrl}),
        );
        cargarPerfilYGaleria();
      }
    } catch (e) {
      debugPrint('Error al subir foto: $e');
    } finally {
      setState(() => isUploading = false);
    }
  }

  Future<void> _cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('profesional_id');

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const MainScreen(initialIndex: 0),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Mi Panel',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: Theme.of(context).primaryColor,
            ),
            onPressed: () {
              themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _cerrarSesion,
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).primaryColor,
              ),
            )
          : perfilData == null
          ? Center(
              child: Text(
                'No se encontró el perfil.',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            )
          // ==========================================
          // MAGIA: RefreshIndicator
          // ==========================================
          : RefreshIndicator(
              color: Theme.of(context).primaryColor,
              backgroundColor: Theme.of(context).cardColor,
              onRefresh: cargarPerfilYGaleria,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(), // Clave
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Rendimiento de mi Negocio',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? Colors.white10 : Colors.black12,
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.visibility,
                                  color: Color(0xFF00B4D8),
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${perfilData!['visitas_perfil'] ?? 0}',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color,
                                  ),
                                ),
                                Text(
                                  'Visitas al perfil',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? Colors.white10 : Colors.black12,
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.chat,
                                  color: Color(0xFF25D366),
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${perfilData!['clics_whatsapp'] ?? 0}',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color,
                                  ),
                                ),
                                Text(
                                  'Clics a WhatsApp',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                        boxShadow: [
                          if (!isDark)
                            const BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark
                                  ? const Color(0xFF2A3143)
                                  : Colors.grey[200],
                              image: perfilData!['logo_url'] != null
                                  ? DecorationImage(
                                      image: NetworkImage(
                                        perfilData!['logo_url'],
                                      ),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: perfilData!['logo_url'] == null
                                ? Icon(
                                    Icons.store,
                                    size: 40,
                                    color: Theme.of(context).primaryColor,
                                  )
                                : null,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            perfilData!['nombre_comercial'],
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.color,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Horario: ${perfilData!['hora_apertura'] ?? '08:00'} a ${perfilData!['hora_cierre'] ?? '18:00'}',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (perfilData!['descripcion'] != null &&
                              perfilData!['descripcion']
                                  .toString()
                                  .trim()
                                  .isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF0B101E)
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                perfilData!['descripcion'],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color,
                                  height: 1.4,
                                ),
                              ),
                            )
                          else
                            const Text(
                              'Aún no has descrito tus servicios. ¡Toca "Editar" para contarle a tus clientes qué ofreces!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditarPerfilScreen(
                                      perfilData: perfilData!,
                                    ),
                                  ),
                                );
                                if (result == true) {
                                  setState(() => isLoading = true);
                                  cargarPerfilYGaleria();
                                }
                              },
                              icon: Icon(
                                Icons.edit,
                                color: Theme.of(context).primaryColor,
                              ),
                              label: Text(
                                'Editar mis datos',
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mi Portafolio',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        isUploading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).primaryColor,
                                ),
                              )
                            : TextButton.icon(
                                onPressed: _subirFotoGaleria,
                                icon: Icon(
                                  Icons.add_a_photo,
                                  color: Theme.of(context).primaryColor,
                                  size: 18,
                                ),
                                label: Text(
                                  'Añadir foto',
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    miGaleria.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? Colors.white10 : Colors.black12,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Aún no has subido fotos de tus trabajos.',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color,
                                ),
                              ),
                            ),
                          )
                        : SizedBox(
                            height: 120,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: miGaleria.length,
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            VisorImagenesScreen(
                                              galeria: miGaleria,
                                              indexInicial: index,
                                            ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 12),
                                    width: 150,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      image: DecorationImage(
                                        image: NetworkImage(
                                          miGaleria[index]['imagen_url'],
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white24 : Colors.black12,
                        ),
                        boxShadow: [
                          if (!isDark)
                            const BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Plan Actual',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: perfilData!['plan_id'] == 3
                                      ? Colors.amber.withOpacity(0.2)
                                      : (perfilData!['plan_id'] == 2
                                            ? Colors.lightBlue.withOpacity(0.2)
                                            : Colors.grey.withOpacity(0.2)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  perfilData!['plan_id'] == 3
                                      ? 'PREMIUM'
                                      : (perfilData!['plan_id'] == 2
                                            ? 'MEDIO'
                                            : 'BÁSICO'),
                                  style: TextStyle(
                                    color: perfilData!['plan_id'] == 3
                                        ? Colors.amber
                                        : (perfilData!['plan_id'] == 2
                                              ? Colors.lightBlue
                                              : (isDark
                                                    ? Colors.white
                                                    : Colors.black87)),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (perfilData!['plan_id'] != 3) ...[
                            Text(
                              '¡Destaca tu negocio!',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Mejora tu plan para conseguir más clientes en Tartagal.',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (perfilData!['plan_id'] == 1)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    await launchUrl(
                                      Uri.parse('TU_LINK_DE_12500'),
                                      mode: LaunchMode.externalApplication,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.arrow_upward,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    'Subir a Plan Medio (\$12.500/mes)',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await launchUrl(
                                    Uri.parse('https://mpago.la/2TWNwfq'),
                                    mode: LaunchMode.externalApplication,
                                  );
                                },
                                icon: const Icon(
                                  Icons.star,
                                  color: Colors.black87,
                                ),
                                label: const Text(
                                  'Subir a Plan Premium (\$25.000/mes)',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: Colors.black87,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (perfilData!['plan_id'] == 3) ...[
                            const Text(
                              '¡Eres Nivel Premium!',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Actualmente disfrutas del máximo posicionamiento en las búsquedas.',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }
}
