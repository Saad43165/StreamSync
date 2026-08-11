// lib/widgets/mini_player.dart
// YouTube-style mini player pinned above the nav bar.
// Full width, ~72px tall, slides up from bottom when activated.
// Swipe left to dismiss, swipe up to expand, tap to expand.
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
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: svc.isMiniPlayerActive ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: svc.isMiniPlayerActive
                ? _MiniPlayerBar(svc: svc)
                : const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

class _MiniPlayerBar extends StatelessWidget {
  final MiniPlayerService svc;
  const _MiniPlayerBar({required this.svc});

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
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final posterUrl = svc.posterPath != null && svc.posterPath!.isNotEmpty
        ? 'https://image.tmdb.org/t/p/w92${svc.posterPath}'
        : null;

    return GestureDetector(
      onTap: () => _expand(context),
      onHorizontalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) < -600) svc.stopMiniPlayer();
      },
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) < -400) _expand(context);
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(bottom: bottomPad),
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          border: Border(top: BorderSide(color: Colors.white12, width: 0.5)),
          boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, -3))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Progress bar ──────────────────────────────────────────────
            LinearProgressIndicator(
              value: svc.progress,
              minHeight: 2,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
            ),
            // ── Content row ───────────────────────────────────────────────
            SizedBox(
              height: 64,
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: posterUrl != null
                        ? CachedNetworkImage(
                            imageUrl: posterUrl,
                            width: 44,
                            height: 62,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _fallbackThumb(),
                          )
                        : _fallbackThumb(),
                  ),
                  const SizedBox(width: 10),
                  // Title + subtitle
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          svc.currentTitle ?? '',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (svc.currentMediaType == 'tv' &&
                            svc.currentSeason != null)
                          Text(
                            'S${svc.currentSeason} · E${svc.currentEpisode}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  // Play/Pause
                  IconButton(
                    icon: Icon(
                      svc.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                    ),
                    iconSize: 28,
                    onPressed: () =>
                        svc.isPlaying ? svc.pause() : svc.resume(),
                  ),
                  // Forward 10s
                  IconButton(
                    icon: const Icon(Icons.forward_10_rounded,
                        color: Colors.white70),
                    iconSize: 22,
                    onPressed: () => svc.seekForward(),
                  ),
                  // Close
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white54),
                    iconSize: 20,
                    onPressed: () => svc.stopMiniPlayer(),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackThumb() => Container(
        width: 44,
        height: 62,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.movie_rounded, color: Colors.white24, size: 22),
      );
}
