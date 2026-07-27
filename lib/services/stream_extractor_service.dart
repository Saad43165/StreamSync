import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Extracts raw HLS (.m3u8), MP4, or DASH URLs from embed providers.
///
/// Features:
///   • Concurrent headless WebView extraction
///   • Deep iFrame inspection
///   • Master playlist preference
///   • JS injection for forced playback
///   • Automatic cleanup & memory management
///   • Comprehensive ad blocking
class StreamExtractorService {

  // Configuration
  static const int _maxParallel = 3;
  static const int _perMirrorTimeout = 15;
  static const int _globalTimeout = 30;
  static const int _deepInspectDelay = 4;

  // Mirror definitions with priority ordering
  static const List<_MirrorDef> _mirrors = [
    _MirrorDef(
      name: 'VidSrc',
      movie: 'https://vidsrc.fyi/embed/movie/{id}',
      tv: 'https://vidsrc.fyi/embed/tv/{id}/{s}/{e}',
      priority: 1,
    ),
    _MirrorDef(
      name: 'VidLink',
      movie: 'https://vidlink.pro/movie/{id}',
      tv: 'https://vidlink.pro/tv/{id}/{s}/{e}',
      priority: 1,
    ),
    _MirrorDef(
      name: 'AutoEmbed',
      movie: 'https://autoembed.co/movie/tmdb/{id}',
      tv: 'https://autoembed.co/tv/tmdb/{id}-{s}-{e}',
      priority: 1,
    ),
    _MirrorDef(
      name: 'VidFast',
      movie: 'https://vidfast.pro/movie/{id}?autoPlay=true',
      tv: 'https://vidfast.pro/tv/{id}/{s}/{e}?autoPlay=true',
      priority: 2,
    ),
    _MirrorDef(
      name: 'EmbedSU',
      movie: 'https://embed.su/embed/movie/{id}',
      tv: 'https://embed.su/embed/tv/{id}/{s}/{e}',
      priority: 2,
    ),
    _MirrorDef(
      name: 'VidSrc.cc',
      movie: 'https://vidsrc.cc/v2/embed/movie/{id}',
      tv: 'https://vidsrc.cc/v2/embed/tv/{id}/{s}/{e}',
      priority: 2,
    ),
    _MirrorDef(
      name: 'VidSrc.me',
      movie: 'https://vidsrc-embed.ru/embed/movie?tmdb={id}',
      tv: 'https://vidsrc-embed.ru/embed/tv?tmdb={id}&season={s}&episode={e}',
      priority: 3,
    ),
    _MirrorDef(
      name: '2Embed',
      movie: 'https://www.2embed.cc/embed/{id}',
      tv: 'https://www.2embed.cc/embedtv/{id}&s={s}&e={e}',
      priority: 3,
    ),
  ];

  // ── Public API ─────────────────────────────────────────────────────────────

  static Future<ExtractionResult?> extract({
    required int tmdbId,
    required String mediaType,
    int season = 1,
    int episode = 1,
    void Function(String status)? onStatus,
  }) async {
    final isMovie = mediaType == 'movie';
    final globalTimeout = Timer(const Duration(seconds: _globalTimeout), () {
      debugPrint('[Extractor] ⏱ Global timeout reached');
    });

    try {
      final sortedMirrors = List<_MirrorDef>.from(_mirrors)
        ..sort((a, b) => a.priority.compareTo(b.priority));

      for (int i = 0; i < sortedMirrors.length; i += _maxParallel) {
        if (!globalTimeout.isActive) break;

        final batch = sortedMirrors.sublist(
            i, (i + _maxParallel).clamp(0, sortedMirrors.length));

        onStatus?.call(
            'Trying sources ${i + 1}-${i + batch.length} of ${sortedMirrors.length}…');

        final futures = batch.map((m) => _extractFromMirror(
          mirror: m,
          tmdbId: tmdbId,
          isMovie: isMovie,
          season: season,
          episode: episode,
        ));

        final result = await _raceFirst(futures.toList());
        if (result != null) {
          debugPrint('[Extractor] ✅ Found: ${result.source} (${result.url})');
          onStatus?.call('Stream found via ${result.source}');
          return result;
        }
      }

      return null;
    } finally {
      globalTimeout.cancel();
    }
  }

  // ── Internal: Racing & Extraction ──────────────────────────────────────────

  static Future<ExtractionResult?> _raceFirst(
      List<Future<ExtractionResult?>> futures) async {
    final completer = Completer<ExtractionResult?>();
    int pending = futures.length;

    for (final f in futures) {
      f.then((value) {
        if (value != null && !completer.isCompleted) {
          completer.complete(value);
        }
        pending--;
        if (pending == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      }).catchError((error) {
        debugPrint('[Extractor] Mirror error: $error');
        pending--;
        if (pending == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
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
      tmdbId: tmdbId,
      isMovie: isMovie,
      season: season,
      episode: episode,
    );

    final completer = Completer<ExtractionResult?>();
    HeadlessInAppWebView? webView;
    Timer? timeoutTimer;
    Timer? deepInspectTimer;

    final List<ExtractionResult> foundStreams = [];

    try {
      timeoutTimer = Timer(Duration(seconds: _perMirrorTimeout), () {
        _cleanup(webView, completer, foundStreams, mirror.name, 'timeout');
      });

      webView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        initialSettings: _buildWebViewSettings(),

        // FIXED: Removed resource.type - now we just check the URL
        onLoadResource: (controller, resource) {
          if (completer.isCompleted) return;

          final resourceUrl = resource.url?.toString() ?? '';

          // Log iframe loads for debugging
          if (resourceUrl.isNotEmpty && resource.initiatorType != null) {
            debugPrint('[Extractor] ${mirror.name}: ${resource.initiatorType} - $resourceUrl');
          }

          // Check for media streams
          _checkForStream(resourceUrl, mirror.name, foundStreams, completer);
        },

        onLoadStop: (controller, url) async {
          if (completer.isCompleted) return;

          await _injectExtractionScripts(controller);

          deepInspectTimer = Timer(
            Duration(seconds: _deepInspectDelay),
                () => _performDeepInspection(controller, mirror.name, foundStreams, completer),
          );
        },

        onReceivedError: (controller, request, error) {
          if (!completer.isCompleted) {
            _cleanup(webView, completer, foundStreams, mirror.name, 'load error');
          }
        },
        onReceivedHttpError: (controller, request, errorResponse) {
          if ((errorResponse.statusCode ?? 0) >= 400 && !completer.isCompleted) {
            _cleanup(webView, completer, foundStreams, mirror.name, 'HTTP ${errorResponse.statusCode}');
          }
        },
      );

      await webView.run();
      return await completer.future;

    } catch (e) {
      debugPrint('[Extractor] ❌ ${mirror.name} exception: $e');
      if (!completer.isCompleted) {
        _cleanup(webView, completer, foundStreams, mirror.name, 'exception');
      }
      return null;
    } finally {
      timeoutTimer?.cancel();
      deepInspectTimer?.cancel();
    }
  }

  // ── WebView Configuration ──────────────────────────────────────────────────

  static InAppWebViewSettings _buildWebViewSettings() {
    return InAppWebViewSettings(
      mediaPlaybackRequiresUserGesture: false,
      javaScriptEnabled: true,

      userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/120.0.0.0 Safari/537.36',

      useHybridComposition: true,
      hardwareAcceleration: true,

      // FIXED: blockNetworkImage is available, removed blockNetworkFonts
      blockNetworkImage: true,

      useWideViewPort: true,
      loadWithOverviewMode: true,
      transparentBackground: true,

      cacheMode: CacheMode.LOAD_NO_CACHE,

      contentBlockers: _buildContentBlockers(),

      mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,

      disableDefaultErrorPage: true,
      supportMultipleWindows: true,
      javaScriptCanOpenWindowsAutomatically: true,
    );
  }

  // ── Stream Detection Logic ─────────────────────────────────────────────────

  static void _checkForStream(
      String url,
      String mirrorName,
      List<ExtractionResult> foundStreams,
      Completer<ExtractionResult?> completer,
      ) {
    if (completer.isCompleted || url.isEmpty) return;

    // Skip ad/tracking URLs
    if (_isAdUrl(url)) return;

    // Master playlist (highest quality) - immediate return
    if (_isMasterPlaylist(url)) {
      debugPrint('[Extractor] 🎯 Master playlist from $mirrorName: $url');
      if (!completer.isCompleted) {
        completer.complete(ExtractionResult(
          url: url,
          source: mirrorName,
          isMaster: true,
          isNative: true,
        ));
      }
      return;
    }

    // Regular M3U8 playlist
    if (_isM3U8Playlist(url)) {
      debugPrint('[Extractor] 📺 M3U8 from $mirrorName: $url');
      foundStreams.add(ExtractionResult(
        url: url,
        source: mirrorName,
        isMaster: false,
        isNative: true,
      ));
    }

    // MP4 direct link
    else if (_isMP4Stream(url)) {
      debugPrint('[Extractor] 🎬 MP4 from $mirrorName: $url');
      foundStreams.add(ExtractionResult(
        url: url,
        source: mirrorName,
        isMaster: false,
        isNative: true,
      ));
    }

    // DASH manifest (fallback)
    else if (_isDASHManifest(url)) {
      debugPrint('[Extractor] 📦 DASH from $mirrorName: $url');
      foundStreams.add(ExtractionResult(
        url: url,
        source: mirrorName,
        isMaster: false,
        isNative: true,
      ));
    }
  }

  static Future<void> _injectExtractionScripts(
      InAppWebViewController controller) async {
    await controller.evaluateJavascript(source: '''
      (function() {
        // Force play all videos to trigger network requests
        document.querySelectorAll('video').forEach(function(v) {
          v.muted = true;
          v.play().catch(function() {});
        });
        
        // Try to get source from JW Player
        if (typeof jwplayer === 'function') {
          try {
            var instances = jwplayer().getPlaylist();
            if (instances && instances.length > 0) {
              instances.forEach(function(item) {
                if (item.file) {
                  console.log('JWPlayer source:', item.file);
                }
              });
            }
          } catch(e) {}
        }
        
        // Try to get source from Plyr
        try {
          var players = document.querySelectorAll('.plyr');
          players.forEach(function(p) {
            var source = p.querySelector('source');
            if (source && source.src) {
              console.log('Plyr source:', source.src);
            }
          });
        } catch(e) {}
        
        // Try to get source from VideoJS
        if (typeof videojs !== 'undefined') {
          try {
            var players = document.querySelectorAll('.video-js');
            players.forEach(function(p) {
              var player = videojs(p.id);
              if (player && player.currentSrc()) {
                console.log('VideoJS source:', player.currentSrc());
              }
            });
          } catch(e) {}
        }
        
        // Click any "play" buttons to trigger video loading
        document.querySelectorAll('[class*="play"], [id*="play"], button').forEach(function(btn) {
          try { btn.click(); } catch(e) {}
        });
      })();
    ''');
  }

  static Future<void> _performDeepInspection(
      InAppWebViewController controller,
      String mirrorName,
      List<ExtractionResult> foundStreams,
      Completer<ExtractionResult?> completer,
      ) async {
    if (completer.isCompleted) return;

    // Get all video sources from the DOM
    try {
      final result = await controller.evaluateJavascript(source: '''
        (function() {
          var sources = [];
          
          // Get video element sources
          document.querySelectorAll('video source').forEach(function(source) {
            if (source.src && source.src.indexOf('blank') === -1) {
              sources.push(source.src);
            }
          });
          
          // Get video element direct src
          document.querySelectorAll('video').forEach(function(video) {
            if (video.src && video.src !== window.location.href && video.src.indexOf('blank') === -1) {
              sources.push(video.src);
            }
          });
          
          // Check for stored URLs in window object (common in embed players)
          if (window.videoUrl) sources.push(window.videoUrl);
          if (window.streamUrl) sources.push(window.streamUrl);
          if (window.playerUrl) sources.push(window.playerUrl);
          
          return JSON.stringify(sources);
        })();
      ''');

      if (result != null) {
        try {
          final List<dynamic> sources =
          (result is String) ? [] : [result];
          debugPrint('[Extractor] $mirrorName found sources: $sources');

          // Check each found source
          for (final source in sources) {
            if (source is String) {
              _checkForStream(source, mirrorName, foundStreams, completer);
            }
          }
        } catch (_) {}
      }
    } catch (_) {}

    // If we have found streams but no master, return the best available
    if (foundStreams.isNotEmpty && !completer.isCompleted) {
      final m3u8Streams = foundStreams.where((s) => s.url.contains('.m3u8'));
      if (m3u8Streams.isNotEmpty) {
        completer.complete(m3u8Streams.first);
      } else {
        completer.complete(foundStreams.first);
      }
    } else if (!completer.isCompleted) {
      _cleanup(null, completer, foundStreams, mirrorName, 'no streams found');
    }
  }

  // ── URL Validation ─────────────────────────────────────────────────────────

  static bool _isMasterPlaylist(String url) {
    return url.contains('master.m3u8') ||
        url.contains('index.m3u8') ||
        url.contains('playlist.m3u8?') ||
        (url.contains('/hls/') &&
            url.endsWith('.m3u8') &&
            !_isMediaSegment(url));
  }

  static bool _isM3U8Playlist(String url) {
    return url.contains('.m3u8') &&
        !_isMediaSegment(url) &&
        !url.contains('localhost');
  }

  static bool _isMP4Stream(String url) {
    return url.contains('.mp4') &&
        !url.contains('blank') &&
        !url.contains('thumbnail') &&
        !url.contains('preview') &&
        (url.contains('video') ||
            url.contains('stream') ||
            url.contains('media') ||
            url.contains('content') ||
            url.contains('/mp4/'));
  }

  static bool _isDASHManifest(String url) {
    return url.contains('.mpd') &&
        !url.contains('blank');
  }

  static bool _isMediaSegment(String url) {
    final segmentPatterns = [
      'seg-', 'chunk-', 'segment', '/ts/',
      'fragment', 'part-', '/media/',
    ];

    for (final pattern in segmentPatterns) {
      if (url.contains(pattern)) return true;
    }

    if (RegExp(r'[\-_\.]\d{3,}\.(ts|m4s|aac|m3u8)$').hasMatch(url)) {
      return true;
    }

    return false;
  }

  static bool _isAdUrl(String url) {
    final adPatterns = [
      'doubleclick', 'googlesyndication', 'adservice',
      'popads', 'exoclick', 'juicyads', 'trafficjunky',
      'propellerads', 'adsterra', 'hilltopads', 'popcash',
      'adcash', 'adnxs', 'rubicon', 'openx', 'pubmatic',
      'criteo', 'casalemedia', 'popunder', 'popmonetizer',
      'google-analytics', 'googletagmanager', 'facebook.com/tr',
      'hotjar', 'mixpanel', 'vast.', 'vpaid.', 'imasdk',
      'moatads', 'springserve', 'spotxchange',
    ];

    return adPatterns.any((pattern) => url.contains(pattern));
  }

  // ── Cleanup ────────────────────────────────────────────────────────────────

  static void _cleanup(
      HeadlessInAppWebView? webView,
      Completer<ExtractionResult?> completer,
      List<ExtractionResult> foundStreams,
      String mirrorName,
      String reason,
      ) {
    debugPrint('[Extractor] 🧹 Cleaning $mirrorName: $reason');

    if (foundStreams.isNotEmpty && !completer.isCompleted) {
      final m3u8 = foundStreams.where((s) => s.url.contains('.m3u8'));
      if (m3u8.isNotEmpty) {
        completer.complete(m3u8.first);
      } else {
        completer.complete(foundStreams.first);
      }
      return;
    }

    if (!completer.isCompleted) {
      completer.complete(null);
    }

    if (webView != null) {
      Future.microtask(() async {
        try {
          await webView.dispose();
        } catch (e) {
          debugPrint('[Extractor] WebView dispose error: $e');
        }
      });
    }
  }

  // ── Content Blockers ───────────────────────────────────────────────────────

  static List<ContentBlocker> _buildContentBlockers() {
    final adDomains = [
      // Google Ads
      'doubleclick.net', 'googlesyndication.com', 'googleadservices.com',
      'googleads.g.doubleclick.net', 'adservice.google.com',

      // Major Ad Networks
      'popads.net', 'exoclick.com', 'juicyads.com', 'trafficjunky.com',
      'propellerads.com', 'adsterra.com', 'hilltopads.net', 'popcash.net',
      'adcash.com', 'adreactor.com', 'adnxs.com', 'rubiconproject.com',
      'openx.net', 'pubmatic.com', 'criteo.com', 'casalemedia.com',

      // Pop-up & Malware
      'popunder.net', 'popmonetizer.com', 'popmyads.com',
      'redirect.com', 'onclickads.net', 'pushads.net',

      // Analytics & Tracking
      'google-analytics.com', 'googletagmanager.com',
      'hotjar.com', 'mixpanel.com',

      // Video Ad Specific
      'vast.', 'vpaid.', 'imasdk.googleapis.com',
      'moatads.com', 'springserve.com', 'spotxchange.com',
    ];

    return adDomains.map((domain) => ContentBlocker(
      trigger: ContentBlockerTrigger(
        urlFilter: '.*',
        ifDomain: [domain],
      ),
      action: ContentBlockerAction(
        type: ContentBlockerActionType.BLOCK,
      ),
    )).toList();
  }
}

// ── Models ─────────────────────────────────────────────────────────────────

class ExtractionResult {
  final String url;
  final String source;
  final bool isMaster;
  final bool isNative;
  final Map<String, String>? headers;

  const ExtractionResult({
    required this.url,
    required this.source,
    required this.isMaster,
    this.isNative = true,
    this.headers,
  });

  @override
  String toString() => 'ExtractionResult(source: $source, master: $isMaster, url: $url)';
}

class _MirrorDef {
  final String name;
  final String movie;
  final String tv;
  final int priority;

  const _MirrorDef({
    required this.name,
    required this.movie,
    required this.tv,
    required this.priority,
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