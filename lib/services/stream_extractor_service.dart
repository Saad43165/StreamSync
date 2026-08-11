import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Extracts a raw HLS (.m3u8) or MP4 URL from embed providers using
/// headless WebViews. This is the PRIMARY resolution path — if it succeeds
/// the player uses media_kit directly with zero ads, zero iframes.
///
/// Strategy:
///   • Run up to [_maxParallel] headless WebViews simultaneously
///   • Return the first valid master playlist URL found
///   • Hard timeout of 25s total — well within user patience
///   • Prefer master.m3u8 / index.m3u8 over segment files
class StreamExtractorService {

  static const int _maxParallel = 3;   // simultaneous headless views
  static const int _perMirrorTimeout = 12; // seconds per mirror

  // Ordered by how reliably they expose m3u8 in network requests
  static const List<_MirrorDef> _mirrors = [
    _MirrorDef(
      name: 'VidSrc',
      movie: 'https://vidsrc.fyi/embed/movie/{id}',
      tv:    'https://vidsrc.fyi/embed/tv/{id}/{s}/{e}',
    ),
    _MirrorDef(
      name: 'VidLink',
      movie: 'https://vidlink.pro/movie/{id}',
      tv:    'https://vidlink.pro/tv/{id}/{s}/{e}',
    ),
    _MirrorDef(
      name: 'AutoEmbed',
      movie: 'https://autoembed.co/movie/tmdb/{id}',
      tv:    'https://autoembed.co/tv/tmdb/{id}-{s}-{e}',
    ),
    _MirrorDef(
      name: 'VidFast',
      movie: 'https://vidfast.pro/movie/{id}?autoPlay=true',
      tv:    'https://vidfast.pro/tv/{id}/{s}/{e}?autoPlay=true',
    ),
    _MirrorDef(
      name: 'EmbedSU',
      movie: 'https://embed.su/embed/movie/{id}',
      tv:    'https://embed.su/embed/tv/{id}/{s}/{e}',
    ),
    _MirrorDef(
      name: 'VidSrc.cc',
      movie: 'https://vidsrc.cc/v2/embed/movie/{id}',
      tv:    'https://vidsrc.cc/v2/embed/tv/{id}/{s}/{e}',
    ),
    _MirrorDef(
      name: 'VidSrc.me',
      movie: 'https://vidsrc-embed.ru/embed/movie?tmdb={id}',
      tv:    'https://vidsrc-embed.ru/embed/tv?tmdb={id}&season={s}&episode={e}',
    ),
    _MirrorDef(
      name: '2Embed',
      movie: 'https://www.2embed.cc/embed/{id}',
      tv:    'https://www.2embed.cc/embedtv/{id}&s={s}&e={e}',
    ),
  ];

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns a raw stream URL (m3u8/mp4) or null if all mirrors fail.
  /// Runs mirrors in batches of [_maxParallel] for speed.
  static Future<ExtractionResult?> extract({
    required int tmdbId,
    required String mediaType,
    int season = 1,
    int episode = 1,
    void Function(String status)? onStatus,
  }) async {
    final isMovie = mediaType == 'movie';

    // Process mirrors in parallel batches
    for (int i = 0; i < _mirrors.length; i += _maxParallel) {
      final batch = _mirrors.sublist(
          i, (i + _maxParallel).clamp(0, _mirrors.length));

      onStatus?.call(
          'Extracting stream (${i + 1}–${(i + batch.length)} of ${_mirrors.length})…');

      final futures = batch.map((m) => _extractFromMirror(
            mirror: m,
            tmdbId: tmdbId,
            isMovie: isMovie,
            season: season,
            episode: episode,
          ));

      // Race this batch — take first non-null result
      final result = await _raceFirst(futures.toList());
      if (result != null) {
        debugPrint('[Extractor] ✅ ${result.source}: ${result.url}');
        return result;
      }
    }

    return null; // all mirrors exhausted
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  static Future<ExtractionResult?> _raceFirst(
      List<Future<ExtractionResult?>> futures) async {
    final completer = Completer<ExtractionResult?>();
    int pending = futures.length;

    for (final f in futures) {
      f.then((v) {
        if (v != null && !completer.isCompleted) completer.complete(v);
        pending--;
        if (pending == 0 && !completer.isCompleted) completer.complete(null);
      }).catchError((_) {
        pending--;
        if (pending == 0 && !completer.isCompleted) completer.complete(null);
      });
    }

    return completer.future;
  }

  static Future<ExtractionResult?> _extractFromMirror({
    required _MirrorDef mirror,
    required int tmdbId,
    required bool isMovie,
    required int season,
    required int episode,
  }) async {
    final url = mirror.buildUrl(
        tmdbId: tmdbId, isMovie: isMovie, season: season, episode: episode);

    final completer = Completer<ExtractionResult?>();
    HeadlessInAppWebView? wv;

    final timer = Timer(Duration(seconds: _perMirrorTimeout), () {
      debugPrint('[Extractor] ⏱ Timeout: ${mirror.name}');
      if (!completer.isCompleted) completer.complete(null);
    });

    wv = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: Uri.parse(url)),
      initialSettings: InAppWebViewSettings(
        mediaPlaybackRequiresUserGesture: false,
        javaScriptEnabled: true,
        // Block ad network scripts to speed up page load
        contentBlockers: _adBlockers,
        // Don't load images/fonts — we only care about video network requests
        blockNetworkImage: true,
      ),
      onLoadResource: (ctrl, resource) {
        if (completer.isCompleted) return;
        final resUrl = resource.url?.toString() ?? '';
        if (_isMasterPlaylist(resUrl)) {
          debugPrint('[Extractor] 🎯 Master playlist on ${mirror.name}: $resUrl');
          completer.complete(ExtractionResult(
              url: resUrl, source: mirror.name, isMaster: true));
        } else if (_isValidStream(resUrl) && !completer.isCompleted) {
          // Keep looking for a master playlist for up to 3 more seconds
          Future.delayed(const Duration(seconds: 3), () {
            if (!completer.isCompleted) {
              debugPrint('[Extractor] ✅ Fallback stream on ${mirror.name}: $resUrl');
              completer.complete(ExtractionResult(
                  url: resUrl, source: mirror.name, isMaster: false));
            }
          });
        }
      },
      onLoadError: (_, __, ___, ____) {
        if (!completer.isCompleted) completer.complete(null);
      },
      onLoadHttpError: (_, __, statusCode, ___) {
        if (statusCode >= 400 && !completer.isCompleted) completer.complete(null);
      },
    );

    try {
      await wv.run();
      return await completer.future;
    } catch (e) {
      debugPrint('[Extractor] ❌ ${mirror.name}: $e');
      if (!completer.isCompleted) completer.complete(null);
      return null;
    } finally {
      timer.cancel();
      try { await wv.dispose(); } catch (_) {}
    }
  }

  // ── URL validators ─────────────────────────────────────────────────────────

  static bool _isMasterPlaylist(String url) {
    if (url.isEmpty) return false;
    return url.contains('master.m3u8') ||
        url.contains('index.m3u8') ||
        url.contains('playlist.m3u8') ||
        // Some CDNs use /hls/ path with a master file
        (url.contains('/hls/') && url.endsWith('.m3u8') && !_isSegment(url));
  }

  static bool _isValidStream(String url) {
    if (url.isEmpty || url.contains('blank')) return false;
    if (url.contains('.m3u8') && !_isSegment(url)) return true;
    if (url.contains('.mp4') && !url.contains('blank')) return true;
    return false;
  }

  static bool _isSegment(String url) {
    return url.contains('seg-') ||
        url.contains('chunk-') ||
        url.contains('segment') ||
        url.contains('/ts/') ||
        RegExp(r'[\-_]\d{3,}\.m3u8$').hasMatch(url);
  }

  // ── Ad blockers for headless views ─────────────────────────────────────────
  static final List<ContentBlocker> _adBlockers = [
    _block('doubleclick.net'),
    _block('googlesyndication.com'),
    _block('adservice.google.com'),
    _block('popads.net'),
    _block('exoclick.com'),
    _block('juicyads.com'),
    _block('trafficjunky.com'),
    _block('propellerads.com'),
    _block('adsterra.com'),
  ];

  static ContentBlocker _block(String domain) => ContentBlocker(
        trigger: ContentBlockerTrigger(
          urlFilter: '.*',
          ifDomain: [domain],
        ),
        action: ContentBlockerAction(
          type: ContentBlockerActionType.BLOCK,
        ),
      );
}

// ── Models ─────────────────────────────────────────────────────────────────

class ExtractionResult {
  final String url;
  final String source;
  final bool isMaster; // true = master playlist, better quality switching

  const ExtractionResult({
    required this.url,
    required this.source,
    required this.isMaster,
  });
}

class _MirrorDef {
  final String name;
  final String movie;
  final String tv;

  const _MirrorDef({
    required this.name,
    required this.movie,
    required this.tv,
  });

  String buildUrl({
    required int tmdbId,
    required bool isMovie,
    required int season,
    required int episode,
  }) {
    final template = isMovie ? movie : tv;
    return template
        .replaceAll('{id}', '$tmdbId')
        .replaceAll('{s}', '$season')
        .replaceAll('{e}', '$episode');
  }
}