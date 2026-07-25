import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class StreamResolverService {
  static const Duration _timeout = Duration(seconds: 10);

  static final List<Map<String, String>> _webMirrors = [
    {'id': 'vidlink', 'name': 'VidLink'},
    {'id': 'vidsrc', 'name': 'VidSrc'},
  ];

  /// Try to get a real stream URL for a movie (TMDB ID)
  static Future<StreamResult?> resolveMovie(int tmdbId, String title) async {
    try {
      // Attempt 1: Native Extraction via Consumet API
      final res = await http.get(Uri.parse('https://consumet-api-clone.vercel.app/movies/flixhq/$title')).timeout(_timeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final id = data['results'][0]['id'];
          final infoRes = await http.get(Uri.parse('https://consumet-api-clone.vercel.app/movies/flixhq/info?id=$id')).timeout(_timeout);
          if (infoRes.statusCode == 200) {
            final infoData = jsonDecode(infoRes.body);
            final episodes = infoData['episodes'];
            if (episodes != null && episodes.isNotEmpty) {
              final epId = episodes[0]['id'];
              final watchRes = await http.get(Uri.parse('https://consumet-api-clone.vercel.app/movies/flixhq/watch?episodeId=$epId&mediaId=$id')).timeout(_timeout);
              if (watchRes.statusCode == 200) {
                final watchData = jsonDecode(watchRes.body);
                final sources = watchData['sources'] as List<dynamic>?;
                if (sources != null && sources.isNotEmpty) {
                  final autoSource = sources.firstWhere((s) => s['quality'] == 'auto', orElse: () => sources.first);
                  return StreamResult.native(url: autoSource['url'], source: 'FlixHQ (Native)');
                }
              }
            }
          }
        }
      }
    } catch (_) {}

    // Fallback: Web Mirror
    return StreamResult.webFallback('https://vidlink.pro/movie/$tmdbId?autoplay=true&primaryColor=6C63FF', sourceName: 'VidLink');
  }

  /// Try to get a real stream URL for a TV episode
  static Future<StreamResult?> resolveTv(int tmdbId, int season, int episode, String title) async {
    // Fallback directly for TV for stability
    return StreamResult.webFallback('https://vidlink.pro/tv/$tmdbId/$season/$episode?autoplay=true&primaryColor=6C63FF', sourceName: 'VidLink');
  }

  static Future<String?> _validateWebMirror(String mirrorId, int tmdbId, {required bool isMovie, int? season, int? episode}) async {
    String url = '';
    switch (mirrorId) {
      case 'vidlink': 
        url = isMovie ? 'https://vidlink.pro/movie/$tmdbId?autoplay=true&primaryColor=6C63FF' : 'https://vidlink.pro/tv/$tmdbId/$season/$episode?autoplay=true&primaryColor=6C63FF';
        break;
      case 'vidsrc': 
        url = isMovie ? 'https://vidsrc.to/embed/movie/$tmdbId' : 'https://vidsrc.to/embed/tv/$tmdbId/$season/$episode';
        break;
    }
    return url;
  }
}

class StreamResult {
  final String url;
  final String source;
  final bool isNative; // true = play in media_kit, false = load in WebView
  final List<SubtitleTrack>? subtitles;

  const StreamResult({
    required this.url,
    required this.source,
    required this.isNative,
    this.subtitles,
  });

  factory StreamResult.native({
    required String url,
    required String source,
    List<SubtitleTrack>? subtitles,
  }) => StreamResult(url: url, source: source, isNative: true, subtitles: subtitles);

  factory StreamResult.webFallback(String url, {String sourceName = 'Web Embed'}) =>
      StreamResult(url: url, source: sourceName, isNative: false);
}

class SubtitleTrack {
  final String url;
  final String language;
  const SubtitleTrack({required this.url, required this.language});
}
