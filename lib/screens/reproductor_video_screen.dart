import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ReproductorVideoScreen extends StatefulWidget {
  final String videoUrl;
  final String titulo;

  const ReproductorVideoScreen({
    super.key,
    required this.videoUrl,
    this.titulo = 'Video del Portafolio',
  });

  @override
  State<ReproductorVideoScreen> createState() => _ReproductorVideoScreenState();
}

class _ReproductorVideoScreenState extends State<ReproductorVideoScreen> {
  late VideoPlayerController _controller;
  bool _inicializado = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize()
          .then((_) {
            if (mounted) {
              setState(() => _inicializado = true);
              _controller.play();
              _controller.setLooping(true);
            }
          })
          .catchError((e) {
            debugPrint('Error cargando video: $e');
            if (mounted) setState(() => _error = true);
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.titulo,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: _error
            ? const Text(
                'No se pudo reproducir el video.',
                style: TextStyle(color: Colors.white),
              )
            : !_inicializado
            ? const CircularProgressIndicator(color: Color(0xFF00B4D8))
            : Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _controller.value.isPlaying
                            ? _controller.pause()
                            : _controller.play();
                      });
                    },
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          VideoPlayer(_controller),
                          if (!_controller.value.isPlaying)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 50,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Color(0xFF00B4D8),
                      bufferedColor: Colors.white38,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: _inicializado
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF00B4D8),
              foregroundColor: Colors.white,
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
              child: Icon(
                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
            )
          : null,
    );
  }
}
