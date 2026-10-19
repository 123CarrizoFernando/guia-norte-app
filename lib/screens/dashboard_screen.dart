import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // CONFIGURA AQUÍ TU ALIAS PARA TRANSFERENCIAS:
  static const String aliasPago = 'guiadelnorte.mp';

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
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _mostrarDialogoPagoPlan(
    int planId,
    String nombrePlan,
    String precio,
    String linkMp,
  ) async {
    String metodoElegido = 'Mercado Pago (Link)';
    final comprobanteCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Activar $nombrePlan ($precio/mes)',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Elige cómo quieres abonar y realiza el pago.\n2. Ingresa debajo el número de comprobante o titular.\n3. Apenas verifiquemos el depósito, daremos de alta tu plan.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: metodoElegido,
                      decoration: InputDecoration(
                        labelText: 'Método de Pago',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Mercado Pago (Link)',
                          child: Text('Pagar con Mercado Pago (Link)'),
                        ),
                        DropdownMenuItem(
                          value: 'Transferencia Bancaria / Alias',
                          child: Text('Transferencia / CBU / Alias'),
                        ),
                        DropdownMenuItem(
                          value: 'Efectivo / Rapipago / Presencial',
                          child: Text('Efectivo / Rapipago / Presencial'),
                        ),
                      ],
                      onChanged: (val) =>
                          setModalState(() => metodoElegido = val!),
                    ),
                    const SizedBox(height: 12),

                    if (metodoElegido == 'Mercado Pago (Link)')
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.open_in_new),
                          label: Text('Abrir Link de Pago ($precio)'),
                          onPressed: () async {
                            await launchUrl(
                              Uri.parse(linkMp),
                              mode: LaunchMode.externalApplication,
                            );
                          },
                        ),
                      ),

                    if (metodoElegido == 'Transferencia Bancaria / Alias')
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Transfiere al Alias:',
                                  style: TextStyle(fontSize: 12),
                                ),
                                Text(
                                  aliasPago,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () {
                                Clipboard.setData(
                                  const ClipboardData(text: aliasPago),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Alias copiado'),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),
                    TextField(
                      controller: comprobanteCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nº de Comprobante o Nombre del Titular',
                        hintText: 'Ej: Comprobante #48291 o Juan Pérez',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.check_circle),
                        label: const Text(
                          'Ya pagué - Enviar para Verificación',
                        ),
                        onPressed: () async {
                          if (comprobanteCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Por favor escribe el Nº de comprobante o nombre de quien transfirió',
                                ),
                                backgroundColor: Colors.deepOrange,
                              ),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          await http.post(
                            Uri.parse(
                              'https://guia-norte-backend.onrender.com/api/perfiles/${perfilData!['id']}/solicitar-plan',
                            ),
                            headers: {'Content-Type': 'application/json'},
                            body: json.encode({
                              'plan_solicitado_id': planId,
                              'metodo_pago': metodoElegido,
                              'comprobante_info': comprobanteCtrl.text.trim(),
                            }),
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '¡Solicitud enviada! Verificaremos tu depósito y daremos de alta tu plan.',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                          cargarPerfilYGaleria();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
      if (mounted) setState(() => isUploading = false);
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
          : RefreshIndicator(
              color: Theme.of(context).primaryColor,
              backgroundColor: Theme.of(context).cardColor,
              onRefresh: cargarPerfilYGaleria,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                          if (perfilData!['categoria_nombre'] != null &&
                              perfilData!['rubro_nombre'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${perfilData!['categoria_nombre']} • ${perfilData!['rubro_nombre']}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
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
                                'Editar mis datos y rubro',
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

                    // ==========================================
                    // SECCIÓN: MI PORTAFOLIO (Usa _subirFotoGaleria)
                    // ==========================================
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

                    // ==========================================
                    // SECCIÓN PLAN Y VERIFICACIÓN DE PAGO
                    // ==========================================
                    Container(
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white24 : Colors.black12,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Plan Actual'),
                              Chip(
                                label: Text(
                                  perfilData!['plan_id'] == 3
                                      ? 'PREMIUM'
                                      : (perfilData!['plan_id'] == 2
                                            ? 'MEDIO'
                                            : 'BÁSICO'),
                                ),
                              ),
                            ],
                          ),
                          if (perfilData!['estado_pago'] == 'pendiente') ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.orange),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.hourglass_top,
                                    color: Colors.orange,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Tu pago está en verificación. Apenas confirmemos el depósito se activará tu nuevo plan.',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          if (perfilData!['plan_id'] != 3) ...[
                            if (perfilData!['plan_id'] == 1)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _mostrarDialogoPagoPlan(
                                    2,
                                    'Plan Medio',
                                    '\$5.000',
                                    'https://mpago.la/1ygAvpA',
                                  ),
                                  icon: const Icon(Icons.arrow_upward),
                                  label: const Text(
                                    'Activar Plan Medio (\$5.000/mes)',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _mostrarDialogoPagoPlan(
                                  3,
                                  'Plan Premium',
                                  '\$20.000',
                                  'https://mpago.la/2TWNwfq',
                                ),
                                icon: const Icon(Icons.star),
                                label: const Text(
                                  'Ser Destacado Premium (\$20.000/mes)',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          Divider(
                            color: isDark ? Colors.white24 : Colors.black12,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.design_services,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '¿No tienes tiempo?',
                                      style: TextStyle(
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Nosotros armamos tu perfil, retocamos tu logo y subimos tu portafolio por un pago único de \$8.000.',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      final Uri url = Uri.parse(
                                        'https://wa.me/5493873569838?text=Hola,%20quiero%20contratar%20el%20armado%20de%20mi%20perfil%20en%20Guía%20del%20Norte.',
                                      );
                                      await launchUrl(
                                        url,
                                        mode: LaunchMode.externalApplication,
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                    child: Text(
                                      'Contratar armado VIP',
                                      style: TextStyle(
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
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
