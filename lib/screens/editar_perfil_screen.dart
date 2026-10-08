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
      imageQuality:
          100, // Mejor calidad inicial para que el recorte no se vea borroso
    );

    if (imagen != null) {
      // 2. Abrimos la pantalla de recorte
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: imagen.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // Obligamos a que sea un cuadrado perfecto (calza ideal en el círculo)
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Ajustar Logo',
            toolbarColor: Colors.black, // Estilo Dark Mode
            toolbarWidgetColor: const Color(0xFF00B4D8), // Acentos celestes
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio:
                true, // No dejamos que hagan rectángulos, solo cuadrados
            hideBottomControls: false,
          ),
          IOSUiSettings(title: 'Ajustar Logo', aspectRatioLockEnabled: true),
          WebUiSettings(context: context),
        ],
      );

      // 3. Si el usuario recortó y le dio a "Aceptar", guardamos la imagen final
      if (croppedFile != null) {
        final bytes = await croppedFile.readAsBytes();
        setState(() {
          _imagenSeleccionada = XFile(
            croppedFile.path,
          ); // Pasamos el archivo recortado
          _imagenBytes =
              bytes; // Guardamos los bytes para mostrarlo al instante
        });
      }
    }
  }

  Future<String?> _subirImagenACloudinary() async {
    if (_imagenSeleccionada == null || _imagenBytes == null) return null;
    try {
      const cloudName = 'TU_CLOUD_NAME'; // RECUERDA PONER TU CLOUD NAME AQUÍ
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
      // Si eligió una nueva foto, la subimos. Si no, enviamos null y SQL mantendrá la vieja.
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
          'logo_url': nuevaUrlLogo, // Pasamos la nueva (o null)
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(
          context,
          true,
        ); // Retorna true para que el Dashboard sepa que debe recargar
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
      appBar: AppBar(
        title: const Text('Editar Datos'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
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
                  backgroundColor: Colors.blue[50],
                  backgroundImage: _imagenBytes != null
                      ? MemoryImage(_imagenBytes!) as ImageProvider
                      : (_logoUrlExistente != null
                            ? NetworkImage(_logoUrlExistente!)
                            : null),
                  child: (_imagenBytes == null && _logoUrlExistente == null)
                      ? const Icon(
                          Icons.add_a_photo,
                          size: 40,
                          color: Colors.lightBlue,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tocar para cambiar logo',
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),

              TextFormField(
                controller: _nombreController,
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
                  hintText: 'Ej: Especialista con 10 años de experiencia. Ofrezco servicios a domicilio, presupuestos sin cargo...',
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
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '¡Este texto es lo que leerán tus clientes para elegirte!',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _telefonoController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Número de WhatsApp',
                  hintText: 'Ej: 3873000000',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
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
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
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
