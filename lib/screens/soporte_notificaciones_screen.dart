import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

class SoporteNotificacionesScreen extends StatefulWidget {
  const SoporteNotificacionesScreen({super.key});

  @override
  State<SoporteNotificacionesScreen> createState() =>
      _SoporteNotificacionesScreenState();
}

class _SoporteNotificacionesScreenState
    extends State<SoporteNotificacionesScreen> {
  // Preferencias de Notificaciones
  bool _notifGenerales = true;
  bool _notifNuevosPremium = true;
  bool _filtrarPorCategorias = false;
  List<dynamic> _categorias = [];
  Set<int> _categoriasSuscritas = {};
  bool _cargandoCategorias = true;

  // Formulario de Soporte
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _contactoCtrl = TextEditingController();
  final _mensajeCtrl = TextEditingController();
  String _asuntoSeleccionado = 'Duda general sobre la App';
  bool _enviandoSoporte = false;

  // Datos oficiales de contacto
  static const String emailSoporte = 'yoprogramador99@gmail.com';
  static const String webOficial = 'https://guiadelnorte.com.ar';
  static const String whatsappSoporte = '5493873569838';

  @override
  void initState() {
    super.initState();
    _cargarPreferenciasYCategorias();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _contactoCtrl.dispose();
    _mensajeCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarPreferenciasYCategorias() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> guardadas =
        prefs.getStringList('notif_categorias') ?? [];

    setState(() {
      _notifGenerales = prefs.getBool('notif_generales') ?? true;
      _notifNuevosPremium = prefs.getBool('notif_nuevos_premium') ?? true;
      _filtrarPorCategorias = prefs.getBool('notif_filtrar_cat') ?? false;
      _categoriasSuscritas = guardadas.map((id) => int.parse(id)).toSet();
    });

    try {
      final res = await http.get(
        Uri.parse('https://guia-norte-backend.onrender.com/api/categorias'),
      );
      if (res.statusCode == 200 && mounted) {
        final lista = json.decode(res.body) as List<dynamic>;
        setState(() {
          _categorias = lista;
          // Si es la primera vez, marcamos todas por defecto
          if (guardadas.isEmpty) {
            _categoriasSuscritas = lista
                .map<int>((c) => c['id'] as int)
                .toSet();
          }
          _cargandoCategorias = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargandoCategorias = false);
    }
  }

  Future<void> _cambiarNotifGeneral(bool activo) async {
    setState(() => _notifGenerales = activo);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_generales', activo);

    if (!kIsWeb) {
      if (activo) {
        await FirebaseMessaging.instance.subscribeToTopic('general');
      } else {
        await FirebaseMessaging.instance.unsubscribeFromTopic('general');
      }
    }
  }

  Future<void> _cambiarNotifPremium(bool activo) async {
    setState(() => _notifNuevosPremium = activo);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_nuevos_premium', activo);

    if (!kIsWeb) {
      if (activo) {
        await FirebaseMessaging.instance.subscribeToTopic('nuevos_ingresos');
      } else {
        await FirebaseMessaging.instance.unsubscribeFromTopic(
          'nuevos_ingresos',
        );
      }
    }
  }

  Future<void> _alternarCategoriaNotif(int catId, bool seleccionada) async {
    setState(() {
      if (seleccionada) {
        _categoriasSuscritas.add(catId);
      } else {
        _categoriasSuscritas.remove(catId);
      }
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'notif_categorias',
      _categoriasSuscritas.map((e) => e.toString()).toList(),
    );

    if (!kIsWeb) {
      final topicName = 'cat_$catId';
      if (seleccionada) {
        await FirebaseMessaging.instance.subscribeToTopic(topicName);
      } else {
        await FirebaseMessaging.instance.unsubscribeFromTopic(topicName);
      }
    }
  }

  Future<void> _enviarCorreoDirecto() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: emailSoporte,
      query:
          'subject=${Uri.encodeComponent("Consulta - App Guía del Norte")}&body=${Uri.encodeComponent("Hola equipo de Guía del Norte, necesito ayuda con:")}',
    );
    await launchUrl(emailUri, mode: LaunchMode.externalApplication);
  }

  Future<void> _abrirWebOficial() async {
    await launchUrl(
      Uri.parse(webOficial),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _abrirWhatsAppSoporte() async {
    final Uri waUri = Uri.parse(
      'https://wa.me/$whatsappSoporte?text=${Uri.encodeComponent("Hola, te escribo desde la pestaña de Soporte de Guía del Norte.")}',
    );
    await launchUrl(waUri, mode: LaunchMode.externalApplication);
  }

  Future<void> _enviarFormularioSoporte() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _enviandoSoporte = true);
    try {
      final res = await http.post(
        Uri.parse('https://guia-norte-backend.onrender.com/api/soporte'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'nombre': _nombreCtrl.text.trim(),
          'contacto': _contactoCtrl.text.trim(),
          'asunto': _asuntoSeleccionado,
          'mensaje': _mensajeCtrl.text.trim(),
        }),
      );

      if (res.statusCode == 201 && mounted) {
        _mensajeCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Mensaje enviado! Te responderemos a la brevedad.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Error al enviar. Puedes contactarnos por WhatsApp o Correo.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enviandoSoporte = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notificaciones y Soporte',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==========================================
            // 1. BLOQUE: CONFIGURACIÓN DE NOTIFICACIONES
            // ==========================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Mis Notificaciones',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Elige qué avisos quieres recibir en tu celular.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const Divider(height: 24),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Novedades y Avisos de Tartagal',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Ofertas, avisos importantes y actualizaciones',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _notifGenerales,
                    activeThumbColor: Theme.of(context).primaryColor,
                    onChanged: _cambiarNotifGeneral,
                  ),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Nuevos Profesionales Destacados',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Enterate cuando un comercio Premium se suma a la guía',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _notifNuevosPremium,
                    activeThumbColor: Theme.of(context).primaryColor,
                    onChanged: _cambiarNotifPremium,
                  ),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Elegir categorías de mi interés',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Personaliza de qué rubros quieres recibir alertas',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _filtrarPorCategorias,
                    activeThumbColor: Theme.of(context).primaryColor,
                    onChanged: (val) async {
                      setState(() => _filtrarPorCategorias = val);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('notif_filtrar_cat', val);
                    },
                  ),

                  if (_filtrarPorCategorias) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Toca las categorías que te interesan:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _cargandoCategorias
                        ? const Center(child: CircularProgressIndicator())
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _categorias.map((cat) {
                              final int id = cat['id'];
                              final bool activa = _categoriasSuscritas.contains(
                                id,
                              );
                              return FilterChip(
                                label: Text(
                                  cat['nombre'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: activa
                                        ? Colors.white
                                        : (isDark
                                              ? Colors.white70
                                              : Colors.black87),
                                  ),
                                ),
                                selected: activa,
                                selectedColor: Theme.of(context).primaryColor,
                                checkmarkColor: Colors.white,
                                onSelected: (val) =>
                                    _alternarCategoriaNotif(id, val),
                              );
                            }).toList(),
                          ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ==========================================
            // 2. BLOQUE: ACCESOS RÁPIDOS (WEB, CORREO, WHATSAPP)
            // ==========================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.support_agent,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Canales Oficiales de Contacto',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.withValues(alpha: 0.15),
                      child: const Icon(Icons.language, color: Colors.blue),
                    ),
                    title: const Text(
                      'Visitar Página Web Oficial',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('guiadelnorte.com.ar'),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: _abrirWebOficial,
                  ),
                  const Divider(),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                      child: const Icon(
                        Icons.email_outlined,
                        color: Colors.redAccent,
                      ),
                    ),
                    title: const Text(
                      'Enviar un Correo Electrónico',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(emailSoporte),
                    trailing: const Icon(Icons.send),
                    onTap: _enviarCorreoDirecto,
                  ),
                  const Divider(),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.withValues(alpha: 0.15),
                      child: const Icon(Icons.chat, color: Colors.green),
                    ),
                    title: const Text(
                      'Atención Rápida por WhatsApp',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Soporte técnico y comercial'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _abrirWhatsAppSoporte,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ==========================================
            // 3. BLOQUE: DEJAR DUDAS O PEDIR AYUDA
            // ==========================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '¿Tienes dudas o necesitas ayuda?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Déjanos tu mensaje aquí y te contactaremos para ayudarte.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      initialValue: _asuntoSeleccionado,
                      decoration: InputDecoration(
                        labelText: 'Motivo de consulta',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Duda general sobre la App',
                          child: Text('Duda general sobre la App'),
                        ),
                        DropdownMenuItem(
                          value: 'Ayuda con mi Perfil o Plan',
                          child: Text('Ayuda con mi Perfil o Plan'),
                        ),
                        DropdownMenuItem(
                          value: 'Sugerir nueva Categoría o Rubro',
                          child: Text('Sugerir nueva Categoría o Rubro'),
                        ),
                        DropdownMenuItem(
                          value: 'Reportar un problema técnico',
                          child: Text('Reportar un problema técnico'),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _asuntoSeleccionado = val!),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _nombreCtrl,
                      decoration: InputDecoration(
                        labelText: 'Tu Nombre',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Ingresa tu nombre'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _contactoCtrl,
                      decoration: InputDecoration(
                        labelText: 'Tu WhatsApp o Correo para responderte',
                        prefixIcon: const Icon(Icons.contact_phone_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Ingresa un medio de contacto'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _mensajeCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Escribe tu duda o pedido de ayuda...',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Escribe tu consulta'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _enviandoSoporte
                            ? null
                            : _enviarFormularioSoporte,
                        icon: _enviandoSoporte
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                        label: const Text(
                          'Enviar Consulta a Soporte',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
