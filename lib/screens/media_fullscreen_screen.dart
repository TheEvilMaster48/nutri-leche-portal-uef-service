import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

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
    return Video(
      controller: _videoController!,
      fit: BoxFit.contain,
    );
  }
}
