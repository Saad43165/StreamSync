// lib/widgets/mini_player_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../services/mini_player_service.dart';
import '../theme/app_theme.dart';
import '../screens/native_stream_player_screen.dart';

class MiniPlayerWidget extends StatefulWidget {
  const MiniPlayerWidget({super.key});

  @override
  State<MiniPlayerWidget> createState() => _MiniPlayerWidgetState();
}

class _MiniPlayerWidgetState extends State<MiniPlayerWidget> with TickerProviderStateMixin {
  Player? _player;
  VideoController? _videoController;
  Timer? _positionTimer;
  bool _isInitialized = false;
  String? _lastStreamUrl;

  @override
  void initState() {
    super.initState();
    _positionTimer = Timer.periodic(
      const Duration(seconds: 1),
          (_) => _updatePosition(),
    );
  }

  void _updatePosition() {
    if (_player != null && _player!.state.position != Duration.zero) {
      final miniPlayerService = context.read<MiniPlayerService>();
      miniPlayerService.updatePosition(
        _player!.state.position,
        _player!.state.duration,
      );
    }
  }

  Future<void> _initializePlayer(String url) async {
    if (_isInitialized && _lastStreamUrl == url) return;

    // Dispose old player
    _player?.dispose();

    try {
      _player = Player();
      _videoController = VideoController(_player!);
      await _player!.open(Media(url));
      _isInitialized = true;
      _lastStreamUrl = url;

      // Set volume low for mini player
      _player!.setVolume(50);
    } catch (e) {
      debugPrint('Mini player error: $e');
    }
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MiniPlayerService>(
      builder: (context, miniPlayerService, child) {
        if (!miniPlayerService.isMiniPlayerActive) {
          return const SizedBox.shrink();
        }

        // Initialize player if stream changed
        if (miniPlayerService.currentStreamUrl != null &&
            miniPlayerService.currentStreamUrl != _lastStreamUrl) {
          _initializePlayer(miniPlayerService.currentStreamUrl!);
        }

        return GestureDetector(
          onTap: () {
            // Navigate back to full player
            if (miniPlayerService.currentTmdbId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NativeStreamPlayerScreen(
                    id: miniPlayerService.currentTmdbId!,
                    title: miniPlayerService.currentTitle ?? 'Player',
                    mediaType: miniPlayerService.currentMediaType ?? 'movie',
                    season: miniPlayerService.currentSeason ?? 1,
                    episode: miniPlayerService.currentEpisode ?? 1,
                  ),
                ),
              );
            }
            miniPlayerService.stopMiniPlayer();
          },
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E).withOpacity(0.98),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    // Mini video preview
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 48,
                        height: 48,
                        color: Colors.black,
                        child: _isInitialized && _videoController != null
                            ? Video(controller: _videoController!)
                            : const Icon(Icons.play_circle_outline,
                            color: Colors.white38),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Title and progress
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            miniPlayerService.currentTitle ?? 'Playing...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(1),
                            child: LinearProgressIndicator(
                              value: miniPlayerService.progress,
                              backgroundColor: Colors.white12,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.accent,
                              ),
                              minHeight: 2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Play/Pause button
                    IconButton(
                      icon: Icon(
                        miniPlayerService.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () {
                        if (miniPlayerService.isPlaying) {
                          _player?.pause();
                          miniPlayerService.pause();
                        } else {
                          _player?.play();
                          miniPlayerService.resume();
                        }
                      },
                    ),

                    // Close button
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white54,
                        size: 20,
                      ),
                      onPressed: () {
                        miniPlayerService.close();
                        _player?.stop();
                        _isInitialized = false;
                        _lastStreamUrl = null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}