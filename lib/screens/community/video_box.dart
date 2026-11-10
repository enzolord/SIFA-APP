import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../l10n/l10n.dart';

/// Lecteur vidéo simple (fichier local) : toucher pour lire ou mettre en pause.
class VideoBox extends StatefulWidget {
  const VideoBox({super.key, required this.path});
  final String path;

  @override
  State<VideoBox> createState() => _VideoBoxState();
}

class _VideoBoxState extends State<VideoBox> {
  late final VideoPlayerController _c = VideoPlayerController.file(File(widget.path));
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _c.initialize().then((_) {
      if (mounted) setState(() => _ready = true);
    }).catchError((Object _) {
      if (mounted) setState(() => _failed = true);
    });
    _c.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Colors.black12,
          child: Center(child: Tx('Vidéo introuvable ou illisible')),
        ),
      );
    }
    if (!_ready) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(color: Colors.black12, child: Center(child: CircularProgressIndicator())),
      );
    }
    final playing = _c.value.isPlaying;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: _c.value.aspectRatio,
        child: GestureDetector(
          onTap: () => playing ? _c.pause() : _c.play(),
          child: Stack(alignment: Alignment.center, children: [
            VideoPlayer(_c),
            if (!playing)
              const CircleAvatar(
                radius: 30,
                backgroundColor: Colors.black45,
                child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 42),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(_c, allowScrubbing: true),
            ),
          ]),
        ),
      ),
    );
  }
}
