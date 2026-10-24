import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditarPerfilScreen extends StatefulWidget {
  final Map<String, dynamic> perfilData;
  const EditarPerfilScreen({super.key, required this.perfilData});

  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _nombreController;
  late TextEditingController _descripcionController;
  late TextEditingController _telefonoController;
  late TextEditingController _direccionController;
  late TextEditingController _instagramController;
  late TextEditingController _facebookController;
  late TextEditingController _sitioWebController;

  // NUEVO: Listas y valores para cambiar Categoría, Rubro y Servicio
  List<dynamic> _categorias = [];
  List<dynamic> _rubros = [];
  List<dynamic> _servicios = [];
  int? _categoriaSeleccionada;
  int? _rubroSeleccionado;
  int? _servicioSeleccionado;

  Uint8List? _imagenBytes;
  String? _logoUrlExistente;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(
      text: widget.perfilData['nombre_comercial'] ?? '',
    );
    _descripcionController = TextEditingController(
      text: widget.perfilData['descripcion'] ?? '',
    );
    _telefonoController = TextEditingController(
      text: widget.perfilData['telefono_contacto'] ?? '',
    );
    _direccionController = TextEditingController(
      text: widget.perfilData['direccion'] ?? '',
    );
    _instagramController = TextEditingController(
      text: widget.perfilData['instagram'] ?? '',
    );
    _facebookController = TextEditingController(
      text: widget.perfilData['facebook'] ?? '',
    );

    _sitioWebController = TextEditingController(
      text: widget.perfilData['sitio_web'] ?? '',
    );

    _logoUrlExistente = widget.perfilData['logo_url'];

    // Cargamos la especialidad actual si viene en perfilData
    _categoriaSeleccionada = widget.perfilData['categoria_id'];
    _rubroSeleccionado = widget.perfilData['rubro_id'];
    _servicioSeleccionado = widget.perfilData['servicio_id'];

    _inicializarSelectores();
  }

  Future<void> _inicializarSelectores() async {
    await _fetchCategorias();
    if (_categoriaSeleccionada != null) {
      await _fetchRubros(_categoriaSeleccionada!, mantenerSeleccion: true);
    }
    if (_rubroSeleccionado != null) {
      await _fetchServicios(_rubroSeleccionado!, mantenerSeleccion: true);
    }
  }

  Future<void> _fetchCategorias() async {
    try {
      final response = await http.get(
        Uri.parse('https://guia-norte-backend.onrender.com/api/categorias'),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final lista = json.decode(response.body) as List<dynamic>;
        setState(() {
          _categorias = lista;
          if (_categoriaSeleccionada != null &&
              !_categorias.any((c) => c['id'] == _categoriaSeleccionada)) {
            _categoriaSeleccionada = null;
          }
        });
      }
    } catch (e) {
      debugPrint('Error al cargar categorías: $e');
    }
  }

  Future<void> _fetchRubros(
    int categoriaId, {
    bool mantenerSeleccion = false,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://guia-norte-backend.onrender.com/api/categorias/$categoriaId/rubros',
        ),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final lista = json.decode(response.body) as List<dynamic>;
        setState(() {
          _rubros = lista;
          if (!mantenerSeleccion ||
              !_rubros.any((r) => r['id'] == _rubroSeleccionado)) {
            _rubroSeleccionado = null;
          }
        });
      }
    } catch (e) {
      debugPrint('Error al cargar rubros: $e');
    }
  }

  Future<void> _fetchServicios(
    int rubroId, {
    bool mantenerSeleccion = false,
  }) async {
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
          if (!mantenerSeleccion ||
              !_servicios.any((s) => s['id'] == _servicioSeleccionado)) {
            _servicioSeleccionado = _servicios.isNotEmpty
                ? _servicios.first['id']
                : null;
          }
        });
      }
    } catch (e) {
      debugPrint('Error al cargar servicios: $e');
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _sitioWebController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarImagen() async {
    final XFile? imagen = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (imagen != null) {
      if (!mounted) return;
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: imagen.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Ajustar Logo',
            toolbarColor: const Color(0xFF0b0f19),
            toolbarWidgetColor: const Color(0xFF00B4D8),
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(title: 'Ajustar Logo', aspectRatioLockEnabled: true),
          WebUiSettings(context: context),
        ],
      );

      if (croppedFile != null) {
        final bytes = await croppedFile.readAsBytes();
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
          filename: 'logo_actualizado.jpg',
        ),
      );

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final jsonMap = json.decode(utf8.decode(responseData));
        return jsonMap['secure_url'];
      }
    } catch (e) {
      debugPrint('Error subiendo a Cloudinary: $e');
    }
    return null;
  }

  Future<void> _actualizarPerfil() async {
    if (!_formKey.currentState!.validate()) return;

    if (_servicioSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona tu Categoría y Rubro'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No hay usuario logueado');

      final token = await user.getIdToken();

      String? urlFinalLogo = _logoUrlExistente;
      if (_imagenBytes != null) {
        final subidaUrl = await _subirImagenACloudinary();
        if (subidaUrl != null) {
          urlFinalLogo = subidaUrl;
        }
      }

      final url = Uri.parse(
        'https://guia-norte-backend.onrender.com/api/perfiles/${widget.perfilData['id']}',
      );

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'nombre_comercial': _nombreController.text.trim(),
          'descripcion': _descripcionController.text.trim(),
          'telefono_contacto': _telefonoController.text.trim(),
          'direccion': _direccionController.text.trim(),
          'instagram': _instagramController.text.trim(),
          'facebook': _facebookController.text.trim(),
          'logo_url': urlFinalLogo,
          'servicio_id': _servicioSeleccionado,
          'sitio_web': _sitioWebController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Datos y rubro actualizados con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudieron guardar los cambios')),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Editar Perfil y Rubro')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _seleccionarImagen,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: isDark
                            ? const Color(0xFF2A3143)
                            : Colors.blue[50],
                        backgroundImage: _imagenBytes != null
                            ? MemoryImage(_imagenBytes!) as ImageProvider
                            : (_logoUrlExistente != null &&
                                      _logoUrlExistente!.isNotEmpty
                                  ? NetworkImage(_logoUrlExistente!)
                                  : null),
                        child:
                            (_imagenBytes == null &&
                                (_logoUrlExistente == null ||
                                    _logoUrlExistente!.isEmpty))
                            ? Icon(
                                Icons.add_a_photo,
                                size: 40,
                                color: Theme.of(context).primaryColor,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tocar para cambiar logo',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // SECCIÓN PARA CAMBIAR CATEGORÍA Y RUBRO
              const Text(
                'Categoría y Rubro',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<int>(
                isExpanded: true,
                value: _categoriaSeleccionada,
                decoration: InputDecoration(
                  labelText: 'Categoría Principal',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
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
                value: _rubroSeleccionado,
                decoration: InputDecoration(
                  labelText: 'Rubro / Especialidad',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
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

              if (_servicios.length > 1) ...[
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  value: _servicioSeleccionado,
                  decoration: InputDecoration(
                    labelText: 'Actividad Específica',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: _servicios
                      .map(
                        (serv) => DropdownMenuItem<int>(
                          value: serv['id'],
                          child: Text(
                            serv['nombre'],
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) =>
                      setState(() => _servicioSeleccionado = val),
                ),
                const SizedBox(height: 16),
              ],

              const Divider(height: 32),

              const Text(
                'Información del Negocio',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _nombreController,
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Requerido' : null,
                decoration: InputDecoration(
                  labelText: 'Nombre Comercial o Tu Nombre',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.store),
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _descripcionController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Descripción y Servicios',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 60),
                    child: Icon(Icons.description),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _telefonoController,
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Requerido' : null,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Número de WhatsApp',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(
                    Icons.phone_android,
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _direccionController,
                decoration: InputDecoration(
                  labelText: 'Dirección Física (Opcional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 28),

              const Text(
                'Redes Sociales (Opcional)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _instagramController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'Enlace o Usuario de Instagram',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(
                    Icons.camera_alt,
                    color: Colors.purpleAccent,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _facebookController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'Enlace de Facebook',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.facebook, color: Colors.blue),
                ),
              ),
              const SizedBox(height: 32),

              const SizedBox(height: 16),
              TextFormField(
                controller: _sitioWebController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'Página Web o Catálogo Online (Beneficio Premium)',
                  hintText: 'Ej: https://mitienda.com.ar',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.language, color: Colors.teal),
                ),
              ),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _actualizarPerfil,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Guardar Cambios',
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
}
