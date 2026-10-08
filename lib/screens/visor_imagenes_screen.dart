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
      backgroundColor:
          Colors.black, // El visor siempre queda bien en fondo negro absoluto
      appBar: AppBar(
        backgroundColor:
            Colors.transparent, // Transparente para que la foto destaque
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${widget.galeria.length}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      // PAGEVIEW es el que permite arrastrar el dedo hacia los lados
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.galeria.length,
        physics: const BouncingScrollPhysics(), // Deslizamiento nativo suave
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0, // Zoom de pellizco
            child: Center(
              child: Image.network(
                widget.galeria[index]['imagen_url'],
                fit: BoxFit.contain, // Muestra la foto sin recortarla
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00B4D8)),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
