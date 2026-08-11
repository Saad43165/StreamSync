import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mini_player_service.dart';
import '../theme/app_theme.dart';
import '../screens/native_stream_player_screen.dart';

class MiniPlayerWidget extends StatelessWidget {
  const MiniPlayerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MiniPlayerService>(
      builder: (context, svc, _) {
        return AnimatedSlide(
          offset: Offset(0, svc.isMiniPlayerActive ? 0 : 1),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: svc.isMiniPlayerActive ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: svc.isMiniPlayerActive
                ? _MiniBar(svc: svc)
                : const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

class _MiniBar extends StatelessWidget {
  final MiniPlayerService svc;
  const _MiniBar({required this.svc});

  void _expand(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => NativeStreamPlayerScreen(
          id: svc.currentTmdbId ?? 0,
          title: svc.currentTitle ?? '',
          mediaType: svc.currentMediaType ?? 'movie',
          season: svc.currentSeason ?? 1,
          episode: svc.currentEpisode ?? 1,
          posterPath: svc.posterPath,
        ),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final posterUrl = svc.posterPath != null && svc.posterPath!.isNotEmpty
        ? 'https://image.tmdb.org/t/p/w154${svc.posterPath}'
        : null;

    final subtitle = svc.currentMediaType == 'tv' && svc.currentSeason != null
        ? 'Season ${svc.currentSeason}  ·  Episode ${svc.currentEpisode}'
        : null;

    return GestureDetector(
      onTap: () => _expand(context),
      onHorizontalDragEnd: (d) {
        // Swipe left or right to dismiss
        if ((d.primaryVelocity ?? 0).abs() > 500) svc.stopMiniPlayer();
      },
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) < -400) _expand(context);
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF111114),
          border: const Border(top: BorderSide(color: Colors.white10, width: 0.5)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 20, offset: const Offset(0, -4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar at the very top
            LinearProgressIndicator(
              value: svc.progress,
              minHeight: 2.5,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
            ),

            // Content row
            SizedBox(
              height: 68,
              child: Row(
                children: [
                  // Poster thumbnail
                  SizedBox(
                    width: 48,
                    height: 68,
                    child: posterUrl != null
                        ? CachedNetworkImage(
                            imageUrl: posterUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const _ThumbPlaceholder(),
                            errorWidget: (_, __, ___) => const _ThumbPlaceholder(),
                          )
                        : const _ThumbPlaceholder(),
                  ),
                  const SizedBox(width: 12),

                  // Title + subtitle
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          svc.currentTitle ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11),
                          ),
                        ],
                        if (!svc.isNativeMode) ...[
                          const SizedBox(height: 3),
                          Text(
                            'Tap to resume',
                            style: TextStyle(color: AppTheme.accent.withValues(alpha: 0.8), fontSize: 10.5),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Controls
                  _ControlButton(
                    icon: svc.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 30,
                    onTap: svc.togglePlayPause,
                  ),
                  _ControlButton(
                    icon: Icons.forward_10_rounded,
                    size: 22,
                    color: Colors.white60,
                    onTap: svc.seekForward,
                  ),
                  _ControlButton(
                    icon: Icons.close_rounded,
                    size: 20,
                    color: Colors.white38,
                    onTap: svc.stopMiniPlayer,
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.size,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Icon(icon, color: color, size: size),
      ),
    );
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF222228),
      child: const Icon(Icons.movie_rounded, color: Colors.white12, size: 20),
    );
  }
}
