import 'package:flutter/material.dart';

class VisorImagenesScreen extends StatefulWidget {
  final List<dynamic> galeria;
  final int indexInicial;

  const VisorImagenesScreen({
    super.key,
    required this.galeria,
    required this.indexInicial,
  });

  @override
  State<VisorImagenesScreen> createState() => _VisorImagenesScreenState();
}

class _VisorImagenesScreenState extends State<VisorImagenesScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.indexInicial;
    _pageController = PageController(initialPage: widget.indexInicial);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // El visor siempre queda bien en fondo negro
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${widget.galeria.length}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true, // Para que la foto ocupe toda la pantalla
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.galeria.length,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0, // Permite hacer zoom hasta 4x
            child: Center(
              child: Image.network(
                widget.galeria[index]['imagen_url'],
                fit: BoxFit.contain, // Muestra la imagen completa sin recortar
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const CircularProgressIndicator(color: Color(0xFF00B4D8));
                },
              ),
            ),
          );
        },
      ),
    );
  }
}