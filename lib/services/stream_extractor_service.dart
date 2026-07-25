import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class StreamExtractorService {
  static final List<String> _mirrors = [
    'vidlink.pro',
    'vidsrc.to',
    'embed.su',
    'vidsrc.cc',
    'vidsrc.me',
    'smashystream.com',
    '2embed.cc',
  ];

  static Future<String?> extractM3u8({
    required int tmdbId,
    required String mediaType,
    int? season,
    int? episode,
  }) async {
    for (final mirror in _mirrors) {
      debugPrint('Attempting to extract stream from mirror: $mirror');
      final result = await _extractFromMirror(
        mirror: mirror,
        tmdbId: tmdbId,
        mediaType: mediaType,
        season: season,
        episode: episode,
      );
      if (result != null && result.isNotEmpty) {
        debugPrint('Successfully extracted raw stream: $result');
        return result;
      }
    }
    debugPrint('Failed to extract stream from all mirrors.');
    return null;
  }

  static Future<String?> _extractFromMirror({
    required String mirror,
    required int tmdbId,
    required String mediaType,
    int? season,
    int? episode,
  }) async {
    final completer = Completer<String?>();
    HeadlessInAppWebView? headlessWebView;
    Timer? timeoutTimer;

    String getUrl() {
      if (mediaType == 'movie') {
        if (mirror == 'vidsrc.to') return 'https://vidsrc.to/embed/movie/$tmdbId';
        if (mirror == 'vidsrc.me') return 'https://vidsrc.me/embed/movie?tmdb=$tmdbId';
        if (mirror == 'embed.su') return 'https://embed.su/embed/movie/$tmdbId';
        if (mirror == 'vidsrc.cc') return 'https://vidsrc.cc/v2/embed/movie/$tmdbId';
        if (mirror == 'vidlink.pro') return 'https://vidlink.pro/embed/movie/$tmdbId';
        if (mirror == 'smashystream.com') return 'https://embed.smashystream.com/playere.php?tmdb=$tmdbId';
        if (mirror == '2embed.cc') return 'https://www.2embed.cc/embed/$tmdbId';
      } else {
        if (mirror == 'vidsrc.to') return 'https://vidsrc.to/embed/tv/$tmdbId/$season/$episode';
        if (mirror == 'vidsrc.me') return 'https://vidsrc.me/embed/tv?tmdb=$tmdbId&season=$season&episode=$episode';
        if (mirror == 'embed.su') return 'https://embed.su/embed/tv/$tmdbId/$season/$episode';
        if (mirror == 'vidsrc.cc') return 'https://vidsrc.cc/v2/embed/tv/$tmdbId/$season/$episode';
        if (mirror == 'vidlink.pro') return 'https://vidlink.pro/embed/tv/$tmdbId/$season/$episode';
        if (mirror == 'smashystream.com') return 'https://embed.smashystream.com/playere.php?tmdb=$tmdbId&season=$season&episode=$episode';
        if (mirror == '2embed.cc') return 'https://www.2embed.cc/embedtv/$tmdbId&s=$season&e=$episode';
      }
      return 'https://$mirror';
    }

    final targetUrl = getUrl();

    headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: Uri.parse(targetUrl)),
      initialOptions: InAppWebViewGroupOptions(
        crossPlatform: InAppWebViewOptions(
          mediaPlaybackRequiresUserGesture: false,
          javaScriptEnabled: true,
        ),
      ),
      onLoadResource: (controller, resource) {
        final url = resource.url?.toString() ?? '';
        if (url.contains('.m3u8') || url.contains('.mp4')) {
          if (!url.contains('blank') && !completer.isCompleted) {
            completer.complete(url);
          }
        }
      },

      onLoadError: (controller, url, code, message) {
        if (url?.toString() == targetUrl && !completer.isCompleted) {
          completer.complete(null);
        }
      },
      onLoadHttpError: (controller, url, statusCode, description) {
        if (url?.toString() == targetUrl && statusCode >= 400 && !completer.isCompleted) {
          completer.complete(null);
        }
      },
    );

    // Timeout after 8 seconds
    timeoutTimer = Timer(const Duration(seconds: 8), () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    try {
      await headlessWebView!.run();
      final result = await completer.future;
      return result;
    } catch (e) {
      debugPrint('Error extracting from $mirror: $e');
      return null;
    } finally {
      timeoutTimer.cancel();
      await headlessWebView!.dispose();
    }
  }
}
