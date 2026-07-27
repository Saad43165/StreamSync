import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Ultra-fast concurrent provider checker.
/// Checks ALL providers simultaneously and returns the first reachable one.
class StreamResolverService {

  static final List<_EmbedProvider> _providers = [
    _EmbedProvider(
      name: 'VidSrc',
      movie: (id) => 'https://vidsrc.fyi/embed/movie/$id',
      tv: (id, s, e) => 'https://vidsrc.fyi/embed/tv/$id/$s/$e',
    ),
    _EmbedProvider(
      name: 'VidLink',
      movie: (id) => 'https://vidlink.pro/movie/$id?autoplay=true&primaryColor=6C63FF&secondaryColor=8B5CF6',
      tv: (id, s, e) => 'https://vidlink.pro/tv/$id/$s/$e?autoplay=true&primaryColor=6C63FF&secondaryColor=8B5CF6',
    ),
    _EmbedProvider(
      name: 'VidSrc.me',
      movie: (id) => 'https://vidsrc-embed.ru/embed/movie?tmdb=$id&autoplay=1',
      tv: (id, s, e) => 'https://vidsrc-embed.ru/embed/tv?tmdb=$id&season=$s&episode=$e&autoplay=1',
    ),
    _EmbedProvider(
      name: 'AutoEmbed',
      movie: (id) => 'https://autoembed.co/movie/tmdb/$id',
      tv: (id, s, e) => 'https://autoembed.co/tv/tmdb/$id-$s-$e',
    ),
    _EmbedProvider(
      name: '2Embed',
      movie: (id) => 'https://www.2embed.cc/embed/$id',
      tv: (id, s, e) => 'https://www.2embed.cc/embedtv/$id&s=$s&e=$e',
    ),
    _EmbedProvider(
      name: 'VidFast',
      movie: (id) => 'https://vidfast.pro/movie/$id?autoPlay=true',
      tv: (id, s, e) => 'https://vidfast.pro/tv/$id/$s/$e?autoPlay=true',
    ),
    _EmbedProvider(
      name: 'MultiEmbed',
      movie: (id) => 'https://multiembed.mov/?video_id=$id&tmdb=1',
      tv: (id, s, e) => 'https://multiembed.mov/?video_id=$id&tmdb=1&s=$s&e=$e',
    ),
    _EmbedProvider(
      name: 'VidSrc.cc',
      movie: (id) => 'https://vidsrc.cc/v2/embed/movie/$id',
      tv: (id, s, e) => 'https://vidsrc.cc/v2/embed/tv/$id/$s/$e',
    ),
  ];

  // ── getAllEmbedProviders ───────────────────────────────────────────────────
  static List<Map<String, String>> getAllEmbedProviders({
    required int tmdbId,
    required bool isMovie,
    int season = 1,
    int episode = 1,
  }) {
    return _providers.map((p) {
      final url = isMovie ? p.movie(tmdbId) : p.tv(tmdbId, season, episode);
      return {'name': p.name, 'url': url};
    }).toList();
  }

  // ── Ad-block domain list ──────────────────────────────────────────────────
  static const List<String> adBlockDomains = [
    'doubleclick.net', 'googlesyndication.com', 'adservice.google.com',
    'googleadservices.com', 'google-analytics.com', 'googletagmanager.com',
    'googletagservices.com', 'popads.net', 'popcash.net', 'propellerads.com',
    'adnxs.com', 'advertising.com', 'adblade.com', 'adsafeprotected.com',
    'adform.net', 'rubiconproject.com', 'openx.net', 'pubmatic.com',
    'smartadserver.com', 'criteo.com', 'taboola.com', 'outbrain.com',
    'revcontent.com', 'mgid.com', 'exoclick.com', 'trafficjunky.net',
    'adsterra.com', 'hilltopads.net', 'clickadu.com', 'juicyads.com',
    'plugrush.com', 'ero-advertising.com', 'traffichaus.com',
    'popunder.ru', 'onclickads.net', 'gotrackier.com', 'clicksor.com',
    'adcash.com', 'bidvertiser.com', 'yllix.com', 'valueclick.com',
    'zedo.com', 'undertone.com', 'hotjar.com', 'mixpanel.com',
    'segment.io', 'amplitude.com', 'fullstory.com',
  ];

  // ── JavaScript ad-block injection ─────────────────────────────────────────
  static const String adBlockScript = r"""
(function(){
  if(window.__ak)return; window.__ak=true;
  window.open=function(){return null;};
  window.alert=function(){};
  window.confirm=function(){return true;};
  window.prompt=function(){return null;};
  var BAD=['doubleclick','googlesyndication','popads','trafficjunky','adclick',
    'exoclick','juicyads','hilltopads','propellerads','adsterra','admaven',
    'popcash','adcash','taboola','outbrain','mgid','revcontent'];
  function bad(u){return u&&BAD.some(function(d){return u.indexOf(d)!==-1;});}
  var ox=XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open=function(m,u){if(bad(u)){this.__b=true;return;}return ox.apply(this,arguments);};
  var sx=XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.send=function(){if(this.__b)return;return sx.apply(this,arguments);};
  if(window.fetch){var of=window.fetch;window.fetch=function(i,n){
    var u=(typeof i==='string')?i:(i&&i.url)||'';
    if(bad(u))return new Promise(function(){});
    return of.apply(this,arguments);
  };}
  var SK=['vidlink','vidsrc','embed','multiembed','smash','autoembed','vidfast','2embed'];
  function safe(el){
    if(!el||!el.querySelector)return false;
    if(el.tagName==='VIDEO')return true;
    if(el.querySelector('video'))return true;
    var ifs=el.querySelectorAll('iframe');
    for(var i=0;i<ifs.length;i++){var s=ifs[i].src||'';if(SK.some(function(k){return s.indexOf(k)!==-1;}))return true;}
    return false;
  }
  var AD_SEL=[
    'ins.adsbygoogle','iframe[src*="doubleclick"]','iframe[src*="googlesyndication"]',
    'iframe[src*="popads"]','iframe[src*="exoclick"]','iframe[src*="juicyads"]',
    'iframe[src*="trafficjunky"]','iframe[src*="adsterra"]',
    'div[id^="div-gpt-ad"]','div[id*="google_ads"]','div[class*="adsbygoogle"]',
    'div[class*="popup"]','div[class*="pop-up"]','div[id*="popup"]',
    'div[class*="overlay"]:not([class*="player"])','div[class*="modal"]:not([class*="player"])',
    'div[class*="interstitial"]','div[class*="preroll"]',
  ];
  var AD_TXT=['advertisement','sponsored','buy now','claim prize','you won','lucky visitor'];
  function looksAd(el){
    try{var cs=window.getComputedStyle(el);var z=parseInt(cs.zIndex)||0;
      if((cs.position==='fixed'||cs.position==='absolute')&&z>100&&!safe(el))return true;}catch(e){}
    var t=(el.innerText||'').toLowerCase();
    return AD_TXT.some(function(h){return t.indexOf(h)!==-1;});
  }
  function kill(el){if(!el||!el.parentNode||safe(el))return;el.parentNode.removeChild(el);}
  function resume(){
    document.querySelectorAll('video').forEach(function(v){
      if(v.paused&&!v.ended&&v.readyState>1){v.play().catch(function(){});}
      v.muted=false;
    });
  }
  function sweep(){
    var killed=false;
    AD_SEL.forEach(function(sel){try{document.querySelectorAll(sel).forEach(function(el){kill(el);killed=true;});}catch(e){}});
    document.querySelectorAll('div[style*="z-index"],div[style*="position:fixed"],div[style*="position: fixed"]')
      .forEach(function(el){if(looksAd(el)){kill(el);killed=true;}});
    document.querySelectorAll('a').forEach(function(a){
      var h=a.href||'';if(BAD.some(function(d){return h.indexOf(d)!==-1;})){
        a.onclick=function(e){e.preventDefault();e.stopPropagation();};a.href='javascript:void(0)';}
    });
    if(killed)resume();
  }
  var SKIP=['skip','close','dismiss','got it','continue','\u00d7','\u2715','\u2716'];
  function autoSkip(){
    var sel='[class*="skip"],[id*="skip"],[aria-label*="skip"],[class*="close-ad"],[class*="closeBtn"],[class*="dismiss"]';
    var clicked=false;
    document.querySelectorAll(sel).forEach(function(el){
      var cs=window.getComputedStyle(el);
      if(cs.display!=='none'&&cs.visibility!=='hidden'&&cs.opacity!=='0'){el.click();clicked=true;}
    });
    if(!clicked){document.querySelectorAll('button,span,div,a').forEach(function(el){
      var t=(el.innerText||'').toLowerCase().trim();
      if(t.length<20&&SKIP.some(function(k){return t.indexOf(k)!==-1;})){
        var cs=window.getComputedStyle(el);
        if(cs.display!=='none'&&cs.visibility!=='hidden'){el.click();clicked=true;}
      }
    });}
    if(clicked)resume();
  }
  var observer=new MutationObserver(function(muts){
    muts.forEach(function(m){
      m.addedNodes.forEach(function(n){
        if(n.nodeType===1){
          if(looksAd(n))kill(n);
          if(n.querySelectorAll){AD_SEL.forEach(function(sel){try{n.querySelectorAll(sel).forEach(kill);}catch(e){}});}
        }
      });
    });
    resume();
  });
  observer.observe(document.documentElement,{childList:true,subtree:true});
  document.addEventListener('click',function(e){
    var el=e.target;
    while(el){
      var h=(el.href||(el.getAttribute&&el.getAttribute('href'))||'')+'';
      if(BAD.some(function(d){return h.indexOf(d)!==-1;})){e.preventDefault();e.stopPropagation();return;}
      el=el.parentElement;
    }
    if(window.flutter_inappwebview)window.flutter_inappwebview.callHandler('onTap');
  },true);
  sweep(); autoSkip();
  setInterval(sweep,800);
  setInterval(autoSkip,700);
  setInterval(function(){
    document.querySelectorAll('video').forEach(function(v){
      if(v.paused&&!v.ended&&v.readyState>2){v.play().catch(function(){});}
    });
  },5000);
})();
""";

  // ── Public API ────────────────────────────────────────────────────────────

  static Future<StreamResult?> resolveMovie(
      int tmdbId,
      String title, {
        void Function(String)? onStatus,
      }) =>
      _resolve(tmdbId: tmdbId, isMovie: true, onStatus: onStatus);

  static Future<StreamResult?> resolveTv(
      int tmdbId,
      int season,
      int episode,
      String title, {
        void Function(String)? onStatus,
      }) =>
      _resolve(
        tmdbId: tmdbId,
        isMovie: false,
        season: season,
        episode: episode,
        onStatus: onStatus,
      );

  // ── Core resolver - RACE ALL PROVIDERS SIMULTANEOUSLY ─────────────────────

  static Future<StreamResult?> _resolve({
    required int tmdbId,
    required bool isMovie,
    int season = 1,
    int episode = 1,
    void Function(String)? onStatus,
  }) async {
    onStatus?.call('Racing all ${_providers.length} sources...');

    // Build all URLs first
    final urls = _providers.map((p) {
      final url = isMovie ? p.movie(tmdbId) : p.tv(tmdbId, season, episode);
      return MapEntry(p.name, url);
    }).toList();

    // Race ALL providers simultaneously - first to respond wins!
    final result = await _raceAllProviders(urls, onStatus);

    if (result != null) {
      debugPrint('[StreamResolver] 🏆 Winner: ${result.key}');
      onStatus?.call('Connected to ${result.key}!');
      return StreamResult.webEmbed(result.value, sourceName: result.key);
    }

    // All failed — return first provider as fallback
    final fallback = isMovie
        ? _providers.first.movie(tmdbId)
        : _providers.first.tv(tmdbId, season, episode);
    debugPrint('[StreamResolver] ⚠️ All failed, fallback: $fallback');
    onStatus?.call('Using fallback source…');
    return StreamResult.webEmbed(fallback,
        sourceName: '${_providers.first.name} (fallback)');
  }

  // ── ULTRA-FAST: Race ALL providers concurrently ────────────────────────────

  /// Fires ALL HTTP checks at once.
  /// First provider to respond with 2xx/3xx wins instantly.
  /// Total time = slowest successful response (usually < 1 second).
  static Future<MapEntry<String, String>?> _raceAllProviders(
      List<MapEntry<String, String>> urls,
      void Function(String)? onStatus,
      ) async {
    final completer = Completer<MapEntry<String, String>?>();
    final stopwatch = Stopwatch()..start();

    // Track completion
    int completedCount = 0;
    final totalCount = urls.length;
    bool winnerFound = false;

    // Fire ALL requests simultaneously
    for (final entry in urls) {
      _fastCheck(entry.key, entry.value).then((isReachable) {
        completedCount++;

        // First reachable provider wins immediately!
        if (isReachable && !winnerFound && !completer.isCompleted) {
          winnerFound = true;
          stopwatch.stop();
          debugPrint('[StreamResolver] ⚡ Found in ${stopwatch.elapsedMilliseconds}ms: ${entry.key}');
          completer.complete(entry);
          onStatus?.call('Found ${entry.key} in ${stopwatch.elapsedMilliseconds}ms!');
        }

        // If all failed
        if (!winnerFound && completedCount >= totalCount && !completer.isCompleted) {
          completer.complete(null);
        }

        // Progress update
        if (!winnerFound && completedCount % 2 == 0) {
          onStatus?.call('Checking... (${completedCount}/${totalCount})');
        }
      }).catchError((_) {
        completedCount++;
        if (!winnerFound && completedCount >= totalCount && !completer.isCompleted) {
          completer.complete(null);
        }
      });
    }

    // Global safety timeout (3 seconds max)
    Timer(const Duration(seconds: 3), () {
      if (!completer.isCompleted) {
        debugPrint('[StreamResolver] ⏱ Race timeout after ${stopwatch.elapsedMilliseconds}ms');
        completer.complete(null);
      }
    });

    return completer.future;
  }

  // ── Ultra-fast single check ───────────────────────────────────────────────

  /// Checks reachability with minimal latency.
  /// Uses raw socket connection for fastest possible check.
  static Future<bool> _fastCheck(String name, String url) async {
    try {
      final uri = Uri.parse(url);
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 2); // Ultra-short timeout

      try {
        // Use HEAD first (fastest)
        final request = await client.openUrl('HEAD', uri)
            .timeout(const Duration(seconds: 2));

        request.headers.set('User-Agent',
            'Mozilla/5.0 (Linux; Android 12; Pixel 6) AppleWebKit/537.36');
        request.headers.set('Accept', '*/*');
        request.headers.set('Connection', 'keep-alive');

        final response = await request.close()
            .timeout(const Duration(seconds: 2));

        final statusCode = response.statusCode;
        await response.drain<void>();

        return statusCode >= 200 && statusCode < 500; // Accept 4xx too (server exists)
      } on TimeoutException {
        // Fallback to GET if HEAD fails
        return await _fallbackGetCheck(client, uri);
      } catch (e) {
        // Try GET as fallback
        return await _fallbackGetCheck(client, uri);
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      return false;
    }
  }

  /// Fallback GET check if HEAD fails
  static Future<bool> _fallbackGetCheck(HttpClient client, Uri uri) async {
    try {
      final request = await client.openUrl('GET', uri)
          .timeout(const Duration(seconds: 2));

      request.headers.set('User-Agent',
          'Mozilla/5.0 (Linux; Android 12; Pixel 6) AppleWebKit/537.36');
      request.headers.set('Range', 'bytes=0-0');
      request.headers.set('Accept', '*/*');

      final response = await request.close()
          .timeout(const Duration(seconds: 2));

      final statusCode = response.statusCode;
      await response.drain<void>();

      return statusCode >= 200 && statusCode < 500;
    } catch (e) {
      return false;
    }
  }
}

// ── Provider model ────────────────────────────────────────────────────────

class _EmbedProvider {
  final String name;
  final String Function(int tmdbId) movie;
  final String Function(int tmdbId, int season, int episode) tv;

  const _EmbedProvider({
    required this.name,
    required this.movie,
    required this.tv,
  });
}

// ── Result model ──────────────────────────────────────────────────────────

class StreamResult {
  final String url;
  final String source;
  final bool isNative;
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
  }) =>
      StreamResult(url: url, source: source, isNative: true, subtitles: subtitles);

  factory StreamResult.webEmbed(String url, {String sourceName = 'Web Embed'}) =>
      StreamResult(url: url, source: sourceName, isNative: false);

  factory StreamResult.webFallback(String url, {String sourceName = 'Web Embed'}) =>
      StreamResult(url: url, source: sourceName, isNative: false);
}

class SubtitleTrack {
  final String url;
  final String language;
  const SubtitleTrack({required this.url, required this.language});
}