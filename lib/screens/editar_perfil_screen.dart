import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

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

  // Variables de imagen
  XFile? _imagenSeleccionada;
  Uint8List? _imagenBytes;
  String? _logoUrlExistente;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(
      text: widget.perfilData['nombre_comercial'],
    );
    _descripcionController = TextEditingController(
      text: widget.perfilData['descripcion'] ?? '',
    );
    _telefonoController = TextEditingController(
      text: widget.perfilData['telefono_contacto'],
    );
    _direccionController = TextEditingController(
      text: widget.perfilData['direccion'] ?? '',
    );
    _logoUrlExistente =
        widget.perfilData['logo_url']; // Guardamos la foto que ya tiene
  }

  Future<void> _seleccionarImagen() async {
    // 1. Abrimos la galería
    final XFile? imagen = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );

    if (imagen != null) {
      // 2. Abrimos la pantalla de recorte
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: imagen.path,
        aspectRatio: const CropAspectRatio(
          ratioX: 1,
          ratioY: 1,
        ), // Obligamos a que sea un cuadrado perfecto
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Ajustar Logo',
            toolbarColor: Colors.black, // Mantenemos negro para que se vea siempre bien el recorte
            toolbarWidgetColor: const Color(0xFF00B4D8),
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(title: 'Ajustar Logo', aspectRatioLockEnabled: true),
          // 3. CONFIGURACIÓN WEB SIMPLIFICADA
          WebUiSettings(context: context),
        ],
      );

      // 4. Guardamos la imagen final
      if (croppedFile != null) {
        final bytes = await croppedFile.readAsBytes();
        setState(() {
          _imagenSeleccionada = XFile(croppedFile.path);
          _imagenBytes = bytes;
        });
      }
    }
  }

  Future<String?> _subirImagenACloudinary() async {
    if (_imagenSeleccionada == null || _imagenBytes == null) return null;
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
          filename: _imagenSeleccionada!.name,
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
    setState(() => _isLoading = true);

    try {
      String? nuevaUrlLogo;
      if (_imagenSeleccionada != null) {
        nuevaUrlLogo = await _subirImagenACloudinary();
      }

      final url = Uri.parse(
        'https://guia-norte-backend.onrender.com/api/perfiles/${widget.perfilData['id']}',
      );
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'nombre_comercial': _nombreController.text,
          'descripcion': _descripcionController.text,
          'telefono_contacto': _telefonoController.text,
          'direccion': _direccionController.text,
          'logo_url': nuevaUrlLogo,
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Detectamos el tema actual
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context)
          .scaffoldBackgroundColor, // Se adapta al tema
      appBar: AppBar(
        title: const Text('Editar Datos'),
        // Los colores del AppBar ahora vienen definidos por main.dart
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Círculo de Imagen Actualizable
              GestureDetector(
                onTap: _seleccionarImagen,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: isDark
                      ? const Color(0xFF2A3143)
                      : Colors.blue[50], // Fondo sutil adaptativo
                  backgroundImage: _imagenBytes != null
                      ? MemoryImage(_imagenBytes!) as ImageProvider
                      : (_logoUrlExistente != null
                            ? NetworkImage(_logoUrlExistente!)
                            : null),
                  child: (_imagenBytes == null && _logoUrlExistente == null)
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
              const SizedBox(height: 32),

              // Campos de texto adaptativos
              TextFormField(
                controller: _nombreController,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ), // Color de texto dinámico
                decoration: InputDecoration(
                  labelText: 'Nombre Comercial o Tu Nombre',
                  labelStyle: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Theme.of(context).primaryColor,
                      width: 2,
                    ),
                  ),
                  prefixIcon: Icon(
                    Icons.store,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _descripcionController,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Descripción y Servicios',
                  labelStyle: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                  hintText: 'Ej: Especialista con 10 años de experiencia. Ofrezco servicios a domicilio...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white30 : Colors.black38,
                  ),
                  alignLabelWithHint: true,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Theme.of(context).primaryColor,
                      width: 2,
                    ),
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(bottom: 60),
                    child: Icon(
                      Icons.description,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '¡Este texto es lo que leerán tus clientes para elegirte!',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _telefonoController,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Número de WhatsApp',
                  labelStyle: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                  hintText: 'Ej: 3873000000',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white30 : Colors.black38,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Theme.of(context).primaryColor,
                      width: 2,
                    ),
                  ),
                  prefixIcon: const Icon(
                    Icons.phone_android,
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _actualizarPerfil,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context)
                        .primaryColor, // Celeste marca
                    foregroundColor: Colors.white, // El texto dentro del botón primario siempre queda mejor en blanco
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
