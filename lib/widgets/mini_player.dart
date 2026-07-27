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

class _MiniPlayerWidgetState extends State<MiniPlayerWidget>
    with TickerProviderStateMixin {
  Player? _player;
  VideoController? _videoController;
  Timer? _positionTimer;
  bool _isInitialized = false;
  bool _isInitializing = false;
  String? _lastStreamUrl;
  MiniPlayerService? _miniPlayerService;

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
      try {
        final miniPlayerService = context.read<MiniPlayerService>();
        if (miniPlayerService.isMiniPlayerActive) {
          miniPlayerService.updatePosition(
            _player!.state.position,
            _player!.state.duration,
          );
        }
      } catch (e) {
        // Context might not be valid if widget is disposed
      }
    }
  }

  Future<void> _initializePlayer(String url) async {
    // Prevent multiple simultaneous initializations
    if (_isInitializing) return;
    if (_isInitialized && _lastStreamUrl == url) return;

    _isInitializing = true;

    // Dispose old player
    await _disposePlayer();

    try {
      _player = Player();
      _videoController = VideoController(_player!);
      await _player!.open(Media(url));

      if (!mounted) {
        await _disposePlayer();
        return;
      }

      _isInitialized = true;
      _lastStreamUrl = url;

      // Set volume low for mini player
      _player!.setVolume(50);
    } catch (e) {
      debugPrint('Mini player initialization error: $e');
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _disposePlayer() async {
    try {
      if (_player != null) {
        await _player!.stop();
        _player!.dispose();
      }
    } catch (e) {
      debugPrint('Error disposing mini player: $e');
    }
    _player = null;
    _videoController = null;
    _isInitialized = false;
  }

  void _navigateToFullPlayer(MiniPlayerService miniPlayerService) {
    if (miniPlayerService.currentTmdbId == null) return;

    // Save current state before navigating
    final position = _player?.state.position ?? Duration.zero;
    final duration = _player?.state.duration ?? Duration.zero;

    // Update service with latest position
    if (position != Duration.zero) {
      miniPlayerService.updatePosition(position, duration);
    }

    // Stop mini player but keep service active until navigation completes
    _player?.pause();
    miniPlayerService.stopMiniPlayer();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NativeStreamPlayerScreen(
          id: miniPlayerService.currentTmdbId!,
          title: miniPlayerService.currentTitle ?? 'Player',
          mediaType: miniPlayerService.currentMediaType ?? 'movie',
          season: miniPlayerService.currentSeason ?? 1,
          episode: miniPlayerService.currentEpisode ?? 1,
          posterPath: null, // Will be fetched from history/watchlist
        ),
      ),
    ).then((_) {
      // When returning from full player, dispose mini player resources
      _disposePlayer();
      _lastStreamUrl = null;
    });
  }

  void _handleClose() {
    final miniPlayerService = context.read<MiniPlayerService>();
    _player?.stop();
    _disposePlayer();
    _lastStreamUrl = null;
    miniPlayerService.close();
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _disposePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MiniPlayerService>(
      builder: (context, miniPlayerService, child) {
        _miniPlayerService = miniPlayerService;

        if (!miniPlayerService.isMiniPlayerActive) {
          // Auto-dispose when not active
          if (_isInitialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _disposePlayer();
              _lastStreamUrl = null;
            });
          }
          return const SizedBox.shrink();
        }

        // Initialize player if stream changed
        final streamUrl = miniPlayerService.currentStreamUrl;
        if (streamUrl != null && streamUrl != _lastStreamUrl && !_isInitializing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _initializePlayer(streamUrl);
          });
        }

        return GestureDetector(
          onTap: () => _navigateToFullPlayer(miniPlayerService),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1A1A2E).withValues(alpha: 0.98),
                  const Color(0xFF16213E).withValues(alpha: 0.98),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.accent.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 0),
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
                        decoration: BoxDecoration(
                          color: Colors.black,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (_isInitialized && _videoController != null)
                              Video(controller: _videoController!)
                            else
                              Center(
                                child: _isInitializing
                                    ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.accent.withValues(alpha: 0.7),
                                  ),
                                )
                                    : Icon(
                                  Icons.play_circle_outline,
                                  color: Colors.white.withValues(alpha: 0.4),
                                  size: 24,
                                ),
                              ),
                            // Play overlay on hover effect
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.3),
                                child: Center(
                                  child: Icon(
                                    Icons.open_in_full_rounded,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
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
                              backgroundColor: Colors.white.withValues(alpha: 0.12),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.accent,
                              ),
                              minHeight: 2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 4),

                    // Play/Pause button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          if (miniPlayerService.isPlaying) {
                            _player?.pause();
                            miniPlayerService.pause();
                          } else {
                            _player?.play();
                            miniPlayerService.resume();
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              miniPlayerService.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              key: ValueKey(miniPlayerService.isPlaying),
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Close button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _handleClose,
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white54,
                            size: 20,
                          ),
                        ),
                      ),
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