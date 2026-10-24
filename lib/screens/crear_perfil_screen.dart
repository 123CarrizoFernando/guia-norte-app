import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:typed_data';

import 'dashboard_screen.dart';
import 'main_screen.dart';

class CrearPerfilScreen extends StatefulWidget {
  final int usuarioId;

  const CrearPerfilScreen({super.key, required this.usuarioId});

  @override
  State<CrearPerfilScreen> createState() => _CrearPerfilScreenState();
}

class _CrearPerfilScreenState extends State<CrearPerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  String _tipoUsuario = 'comercio';

  final _nombreController = TextEditingController();
  final _actividadEspecificaController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();
  final _comprobanteController = TextEditingController();

  int _planSeleccionado = 1;
  String _periodoPago = 'mensual'; // 'mensual' o 'anual'
  String _metodoPagoSeleccionado = 'Transferencia Bancaria / Alias';

  // ALIAS OFICIAL CONFIGURADO:
  static const String aliasTransferencia = 'ajeno.buzo.esmere.mp';

  List<dynamic> _categorias = [];
  List<dynamic> _rubros = [];
  List<dynamic> _servicios = [];
  int? _categoriaSeleccionada;
  int? _rubroSeleccionado;
  int? _servicioSeleccionado;

  Uint8List? _imagenBytes;
  String? _logoUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchCategorias();
  }

  Future<void> _fetchCategorias() async {
    try {
      final response = await http.get(
        Uri.parse('https://guia-norte-backend.onrender.com/api/categorias'),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() => _categorias = json.decode(response.body));
      }
    } catch (e) {
      debugPrint('Error al cargar categorías: $e');
    }
  }

  Future<void> _fetchRubros(int categoriaId) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://guia-norte-backend.onrender.com/api/categorias/$categoriaId/rubros',
        ),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() => _rubros = json.decode(response.body));
      }
    } catch (e) {
      debugPrint('Error al cargar rubros: $e');
    }
  }

  Future<void> _fetchServicios(int rubroId) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://guia-norte-backend.onrender.com/api/rubros/$rubroId/servicios',
        ),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final lista = json.decode(response.body) as List<dynamic>;
        setState(() {
          _servicios = lista;
          if (_servicios.isNotEmpty) {
            _servicioSeleccionado = _servicios.first['id'];
          }
        });
      }
    } catch (e) {
      debugPrint('Error al cargar servicios: $e');
    }
  }

  Future<void> _seleccionarImagen() async {
    final XFile? imagen = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (imagen != null) {
      if (!mounted) return;
      final CroppedFile? imagenRecortada = await ImageCropper().cropImage(
        sourcePath: imagen.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Ajustar Logo',
            toolbarColor: const Color(0xFF0b0f19),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(title: 'Ajustar Logo', aspectRatioLockEnabled: true),
          WebUiSettings(context: context),
        ],
      );

      if (imagenRecortada != null) {
        final bytes = await imagenRecortada.readAsBytes();
        if (!mounted) return;
        setState(() => _imagenBytes = bytes);
      }
    }
  }

  Future<String?> _subirImagenACloudinary() async {
    if (_imagenBytes == null) return null;
    try {
      const cloudName = 'ymlcqawz';
      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = 'guia_norte_preset';

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          _imagenBytes!,
          filename: 'perfil_logo.jpg',
        ),
      );

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final jsonMap = json.decode(utf8.decode(responseData));
        return jsonMap['secure_url'];
      }
    } catch (e) {
      debugPrint('Error subiendo imagen a Cloudinary: $e');
    }
    return null;
  }

  // GUARDA LA SESIÓN DEL CLIENTE Y REDIRIGE AL INICIO SIN PANTALLA EN BLANCO/NEGRO
  Future<void> _guardarComoClienteYEntrar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('profesional_id', widget.usuarioId);
    await prefs.setString('rol_usuario', 'cliente');

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const MainScreen(initialIndex: 0),
      ),
      (route) => false,
    );
  }

  Future<void> _guardarPerfil() async {
    if (!_formKey.currentState!.validate()) return;

    if (_rubroSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona tu Categoría y Rubro'),
        ),
      );
      return;
    }

    final bool pidePlanPago = _planSeleccionado > 1;
    if (pidePlanPago && _comprobanteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ingresa el número de comprobante o nombre del titular del pago para verificar tu alta',
          ),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_imagenBytes != null) {
        _logoUrl = await _subirImagenACloudinary();
      }

      final url = Uri.parse(
        'https://guia-norte-backend.onrender.com/api/perfiles',
      );
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'usuario_id': widget.usuarioId,
          'nombre_comercial': _nombreController.text.trim(),
          'descripcion': _descripcionController.text.trim(),
          'telefono_contacto': _telefonoController.text.trim(),
          'direccion': _direccionController.text.trim(),
          'plan_id': 1,
          'plan_solicitado_id': _planSeleccionado,
          'periodo_pago': _periodoPago,
          'estado_pago': pidePlanPago ? 'pendiente' : 'aprobado',
          'metodo_pago': pidePlanPago ? _metodoPagoSeleccionado : 'Gratis',
          'comprobante_info': _comprobanteController.text.trim(),
          'rubro_id': _rubroSeleccionado,
          'servicio_id': _servicioSeleccionado,
          'actividad_especifica': _actividadEspecificaController.text.trim(),
          'logo_url': _logoUrl,
        }),
      );

      if (response.statusCode == 201) {
        if (!mounted) return;
        if (pidePlanPago) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('¡Perfil Creado! Pago en Verificación'),
              content: const Text(
                'Tu perfil ya está creado. Apenas verifiquemos tu transferencia/depósito, te enviaremos una notificación confirmando el alta de tu Plan.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Entendido'),
                ),
              ],
            ),
          );
        }
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(usuarioId: widget.usuarioId),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Configurar Cuenta'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Cómo quieres usar Guía del Norte?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _tipoUsuario = 'cliente'),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _tipoUsuario == 'cliente'
                            ? Colors.blue.shade50
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _tipoUsuario == 'cliente'
                              ? Colors.blueAccent
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.person_search,
                            size: 32,
                            color: Colors.blueAccent,
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Soy Cliente',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Buscar y dejar reseñas',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _tipoUsuario = 'comercio'),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _tipoUsuario == 'comercio'
                            ? Colors.blue.shade50
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _tipoUsuario == 'comercio'
                              ? Colors.blueAccent
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.storefront,
                            size: 32,
                            color: Colors.blueAccent,
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Ofrezco Servicio',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Negocio / Profesional',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (_tipoUsuario == 'cliente') ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.verified_user,
                      size: 48,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '¡Listo para explorar y dejar reseñas!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No necesitas crear un perfil comercial para buscar ni para calificar negocios en Tartagal.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        onPressed:
                            _guardarComoClienteYEntrar, // <-- CAMBIADO AQUÍ
                        child: const Text('Ir al Inicio'),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _seleccionarImagen,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: _imagenBytes != null
                              ? MemoryImage(_imagenBytes!)
                              : null,
                          child: _imagenBytes == null
                              ? const Icon(
                                  Icons.add_a_photo,
                                  size: 40,
                                  color: Colors.grey,
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Tu Especialidad',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Categoría',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      initialValue: _categoriaSeleccionada,
                      items: _categorias
                          .map(
                            (cat) => DropdownMenuItem<int>(
                              value: cat['id'],
                              child: Text(
                                cat['nombre'],
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _categoriaSeleccionada = val;
                          _rubroSeleccionado = null;
                          _servicioSeleccionado = null;
                          _rubros = [];
                          _servicios = [];
                        });
                        if (val != null) _fetchRubros(val);
                      },
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Rubro Principal',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      initialValue: _rubroSeleccionado,
                      items: _rubros
                          .map(
                            (rubro) => DropdownMenuItem<int>(
                              value: rubro['id'],
                              child: Text(
                                rubro['nombre'],
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _rubros.isEmpty
                          ? null
                          : (val) {
                              setState(() {
                                _rubroSeleccionado = val;
                                _servicioSeleccionado = null;
                                _servicios = [];
                              });
                              if (val != null) _fetchServicios(val);
                            },
                    ),
                    const SizedBox(height: 16),

                    // CAMPO PARA QUE LA PERSONA ESCRIBA SU ACTIVIDAD ESPECÍFICA LIBREMENTE
                    TextFormField(
                      controller: _actividadEspecificaController,
                      decoration: InputDecoration(
                        labelText:
                            'Actividad Específica / Especialidad (Opcional)',
                        hintText: 'Ej: Tortillas a la parrilla, Reparación de Aires, Inglés infantil...',
                        helperText: 'Puedes detallar exactamente tu oficio o especialidad',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    const Text(
                      'Tus Datos',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _nombreController,
                      decoration: InputDecoration(
                        labelText: 'Nombre del Negocio / Profesional',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (val) => val!.isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _descripcionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Descripción de lo que ofreces',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (val) => val!.isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _telefonoController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'WhatsApp',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            validator: (val) =>
                                val!.isEmpty ? 'Requerido' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _direccionController,
                            decoration: InputDecoration(
                              labelText: 'Dirección / Barrio (Opcional)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    const Text(
                      'Elegir Plan',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<int>(
                      initialValue: _planSeleccionado,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 1,
                          child: Text('Plan Básico (Gratis)'),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Text(
                            'Plan Medio (\$5.000/mes o \$50.000/año)',
                          ),
                        ),
                        DropdownMenuItem(
                          value: 3,
                          child: Text(
                            'Plan Premium (\$20.000/mes o \$200.000/año)',
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _planSeleccionado = val!),
                    ),

                    if (_planSeleccionado > 1) ...[
                      const SizedBox(height: 16),
                      // SELECTOR DE MODALIDAD: MENSUAL (DÍA 10) O ANUAL
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Pago Mensual'),
                              selected: _periodoPago == 'mensual',
                              onSelected: (_) =>
                                  setState(() => _periodoPago = 'mensual'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text(
                                '🔥 Pago Anual (2 meses gratis)',
                              ),
                              selected: _periodoPago == 'anual',
                              onSelected: (_) =>
                                  setState(() => _periodoPago = 'anual'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade700),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _periodoPago == 'anual'
                                  ? '💳 Pago Anual: ${_planSeleccionado == 2 ? "\$50.000" : "\$200.000"} (Cubre 12 meses)'
                                  : '💳 Pago Mensual: ${_planSeleccionado == 2 ? "\$5.000" : "\$20.000"}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              '📌 Importante: El pago mensual cubre el mes en curso. Al iniciar el próximo mes, tienes del día 1 al 10 para abonar la renovación.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _metodoPagoSeleccionado,
                              decoration: InputDecoration(
                                labelText: 'Método de Pago',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Transferencia Bancaria / Alias',
                                  child: Text(
                                    'Transferencia / Mercado Pago (Alias)',
                                  ),
                                ),
                                DropdownMenuItem(
                                  value:
                                      'Efectivo / Rapipago / Cobro Presencial',
                                  child: Text(
                                    'Efectivo / Rapipago / Presencial',
                                  ),
                                ),
                              ],
                              onChanged: (val) => setState(
                                () => _metodoPagoSeleccionado = val!,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_metodoPagoSeleccionado.contains(
                              'Transferencia',
                            ))
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Alias para transferir:',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          ),
                                          Text(
                                            aliasTransferencia,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.copy,
                                        color: Colors.blueAccent,
                                      ),
                                      onPressed: () {
                                        Clipboard.setData(
                                          const ClipboardData(
                                            text: aliasTransferencia,
                                          ),
                                        );
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Alias copiado: ajeno.buzo.esmere.mp',
                                                ),
                                              ),
                                            );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _comprobanteController,
                              style: const TextStyle(color: Colors.black),
                              decoration: InputDecoration(
                                labelText: 'Nº de Comprobante o Nombre del Titular que pagó',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 36),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _guardarPerfil,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                _planSeleccionado == 1
                                    ? 'Crear Perfil Comercial'
                                    : 'Enviar Pago a Verificación y Crear Perfil',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _actividadEspecificaController.dispose();
    _descripcionController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _comprobanteController.dispose();
    super.dispose();
  }
}
