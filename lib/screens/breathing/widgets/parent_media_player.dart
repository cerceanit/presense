import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../core/app_colors.dart';

class ParentMediaPlayer extends StatefulWidget {
  final String mediaUrl;

  const ParentMediaPlayer({super.key, required this.mediaUrl});

  @override
  State<ParentMediaPlayer> createState() => _ParentMediaPlayerState();
}

class _ParentMediaPlayerState extends State<ParentMediaPlayer>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoController;
  bool _isVideo = false;
  bool _audioPlaying = false;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _initMedia();
  }

  bool _urlIsVideo(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.mp4') ||
        lower.contains('.mov') ||
        lower.contains('.webm') ||
        lower.contains('video');
  }

  Future<void> _initMedia() async {
    _isVideo = _urlIsVideo(widget.mediaUrl);
    if (_isVideo) {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.mediaUrl),
      );
      await _videoController!.initialize();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isVideo && _videoController != null) {
      if (!_videoController!.value.isInitialized) {
        return const Center(child: CircularProgressIndicator());
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppColors.radius),
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_videoController!),
              IconButton(
                icon: Icon(
                  _videoController!.value.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  size: 56,
                  color: AppColors.primaryAccent,
                ),
                onPressed: () {
                  setState(() {
                    _videoController!.value.isPlaying
                        ? _videoController!.pause()
                        : _videoController!.play();
                  });
                },
              ),
            ],
          ),
        ),
      );
    }

    return _AudioWaveform(
      playing: _audioPlaying,
      waveController: _waveController,
      onPlay: () {
        setState(() => _audioPlaying = !_audioPlaying);
        if (_audioPlaying) {
          _waveController.repeat();
        } else {
          _waveController.stop();
        }
      },
    );
  }
}

class _AudioWaveform extends StatelessWidget {
  final bool playing;
  final AnimationController waveController;
  final VoidCallback onPlay;

  const _AudioWaveform({
    required this.playing,
    required this.waveController,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: waveController,
            builder: (_, __) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(12, (i) {
                  final h = playing
                      ? 12.0 + 28 * ((i + waveController.value) % 3) / 3
                      : 12.0;
                  return Container(
                    width: 6,
                    height: h,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryAccent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 16),
          IconButton(
            iconSize: 48,
            color: AppColors.primaryAccent,
            onPressed: onPlay,
            icon: Icon(playing ? Icons.pause_circle : Icons.play_circle),
          ),
        ],
      ),
    );
  }
}
