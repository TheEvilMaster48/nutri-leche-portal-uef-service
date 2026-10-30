import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../widget/controles_video.dart';
import '../widget/tamano_imagen.dart';

/// Visor a pantalla completa para imágenes/GIF y videos (streaming por URL).
class MediaFullscreenScreen extends StatefulWidget {
  final String url;
  final bool isVideo;
  final String title;

  const MediaFullscreenScreen({
    super.key,
    required this.url,
    required this.isVideo,
    this.title = '',
  });

  @override
  State<MediaFullscreenScreen> createState() => _MediaFullscreenScreenState();
}

class _MediaFullscreenScreenState extends State<MediaFullscreenScreen> {
  Player? _player;
  VideoController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    final player = Player();
    final controller = VideoController(player);
    await player.open(Media(widget.url));
    await player.setPlaylistMode(PlaylistMode.loop);
    await player.play();
    if (!mounted) {
      await player.dispose();
      return;
    }
    setState(() {
      _player = player;
      _videoController = controller;
    });
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: widget.title.isEmpty ? null : Text(widget.title),
        elevation: 0,
      ),
      body: Center(
        child: widget.isVideo ? _buildVideo() : _buildImage(),
      ),
    );
  }

  Widget _buildImage() {
    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 4.0,
      child: CachedNetworkImage(
        imageUrl: widget.url,
        fit: BoxFit.contain,
        // El doble de la pantalla: deja ampliar con el zoom sin perder
        // nitidez y sin decodificar la foto original completa.
        memCacheWidth: anchoPantallaPx(context) * 2,
        errorWidget: (_, __, ___) => const Icon(
          Icons.broken_image,
          color: Colors.white54,
          size: 64,
        ),
        placeholder: (_, __) =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
    );
  }

  Widget _buildVideo() {
    if (_videoController == null) {
      return const CircularProgressIndicator(color: Colors.white);
    }
    // Los mismos controles que en el detalle del evento (±10 s y barra),
    // en lugar de los de media_kit, para que se maneje igual en los dos.
    return Stack(
      children: [
        Positioned.fill(
          child: Video(
            controller: _videoController!,
            controls: NoVideoControls,
            fit: BoxFit.contain,
          ),
        ),
        Positioned.fill(
          child: SafeArea(child: ControlesVideo(player: _player!)),
        ),
      ],
    );
  }
}
