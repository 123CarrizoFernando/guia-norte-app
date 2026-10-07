import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'package:image_picker/image_picker.dart';

import 'dart:typed_data';

import 'dashboard_screen.dart';

class CrearPerfilScreen extends StatefulWidget {
  final int usuarioId;

  const CrearPerfilScreen({super.key, required this.usuarioId});

  @override
  State<CrearPerfilScreen> createState() => _CrearPerfilScreenState();
}

class _CrearPerfilScreenState extends State<CrearPerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();

  int _planSeleccionado = 1;

  List<dynamic> _categorias = [];
  List<dynamic> _rubros = [];
  List<dynamic> _servicios = [];
  int? _categoriaSeleccionada;
  int? _rubroSeleccionado;
  int? _servicioSeleccionado;

  // Variables para la imagen
  XFile? _imagenSeleccionada;
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
      if (response.statusCode == 200) {
        setState(() => _servicios = json.decode(response.body));
      }
    } catch (e) {
      debugPrint('Error al cargar servicios: $e');
    }
  }

  Future<void> _seleccionarImagen() async {
    final XFile? imagen = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (imagen != null) {
      final bytes = await imagen.readAsBytes();
      setState(() {
        _imagenSeleccionada = imagen;
        _imagenBytes = bytes;
      });
    }
  }

  // MÉTODO NUEVO: Subida directa a Cloudinary
  Future<String?> _subirImagenACloudinary() async {
    if (_imagenSeleccionada == null || _imagenBytes == null) return null;

    try {
      // ATENCIÓN: Pon tu Cloud Name real aquí
      const cloudName = 'ymlcqawz';
      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = 'guia_norte_preset'; // Tu preset Unsigned

      // Adjuntamos la imagen leyendo los bytes directamente (ideal para web)
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          _imagenBytes!,
          filename: _imagenSeleccionada!.name,
        ),
      );

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final responseString = utf8.decode(responseData);
        final jsonMap = json.decode(responseString);

        return jsonMap['secure_url']; // Esta es la URL pública generada
      } else {
        debugPrint('Error de Cloudinary: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error subiendo imagen a Cloudinary: $e');
    }
    return null;
  }

  Future<void> _guardarPerfil() async {
    if (!_formKey.currentState!.validate()) return;

    if (_servicioSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona un servicio o actividad'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Subimos la imagen a Cloudinary
      if (_imagenSeleccionada != null) {
        _logoUrl = await _subirImagenACloudinary();
      }

      // 2. Guardamos en nuestra Base de Datos en Neon
      final url = Uri.parse(
        'https://guia-norte-backend.onrender.com/api/perfiles',
      );
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'usuario_id': widget.usuarioId,
          'nombre_comercial': _nombreController.text,
          'descripcion': _descripcionController.text,
          'telefono_contacto': _telefonoController.text,
          'direccion': _direccionController.text,
          'plan_id': _planSeleccionado,
          'servicio_id': _servicioSeleccionado,
          'logo_url': _logoUrl, // Pasamos la URL al backend
        }),
      );

      if (response.statusCode == 201) {
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
        title: const Text('Completar Perfil'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
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
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Subir Logo o Foto (Opcional)',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Tu Especialidad',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<int>(
                decoration: InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                value: _categoriaSeleccionada,
                items: _categorias
                    .map(
                      (cat) => DropdownMenuItem<int>(
                        value: cat['id'],
                        child: Text(cat['nombre']),
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
                decoration: InputDecoration(
                  labelText: 'Rubro',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                value: _rubroSeleccionado,
                items: _rubros
                    .map(
                      (rubro) => DropdownMenuItem<int>(
                        value: rubro['id'],
                        child: Text(rubro['nombre']),
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

              DropdownButtonFormField<int>(
                decoration: InputDecoration(
                  labelText: 'Servicio / Actividad',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                value: _servicioSeleccionado,
                items: _servicios
                    .map(
                      (serv) => DropdownMenuItem<int>(
                        value: serv['id'],
                        child: Text(serv['nombre']),
                      ),
                    )
                    .toList(),
                onChanged: _servicios.isEmpty
                    ? null
                    : (val) => setState(() => _servicioSeleccionado = val),
              ),
              const SizedBox(height: 32),

              const Text(
                'Tus Datos',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                  labelText: 'Descripción',
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
                      validator: (val) => val!.isEmpty ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _direccionController,
                      decoration: InputDecoration(
                        labelText: 'Dirección (Opcional)',
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
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<int>(
                value: _planSeleccionado,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 1,
                    child: Text('Plan Básico (\$5.000 - \$7.000)'),
                  ),
                  DropdownMenuItem(
                    value: 2,
                    child: Text('Plan Medio (\$10.000 - \$15.000)'),
                  ),
                  DropdownMenuItem(
                    value: 3,
                    child: Text('Plan Premium (\$50.000 - \$70.000)'),
                  ),
                ],
                onChanged: (val) => setState(() => _planSeleccionado = val!),
              ),
              const SizedBox(height: 48),

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
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Crear Perfil Comercial',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    super.dispose();
  }
}
