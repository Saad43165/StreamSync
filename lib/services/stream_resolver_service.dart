import 'dart:async';
import 'package:flutter/foundation.dart';

class StreamResolverService {

  // ── ALL WORKING Providers (Verified 2025) ──────────────────────────────────

  static final List<_EmbedProvider> _providers = [
    // Tier 1 - Most Reliable
    _EmbedProvider(
      name: 'VidLink',
      movie: (id) => 'https://vidlink.pro/movie/$id?autoplay=true',
      tv: (id, s, e) => 'https://vidlink.pro/tv/$id/$s/$e?autoplay=true',
    ),
    _EmbedProvider(
      name: 'VidSrc PM',
      movie: (id) => 'https://vidsrc.pm/embed/movie/$id',
      tv: (id, s, e) => 'https://vidsrc.pm/embed/tv/$id/$s/$e',
    ),
    _EmbedProvider(
      name: 'VidFast',
      movie: (id) => 'https://vidfast.vc/movie/$id?autoPlay=true',
      tv: (id, s, e) => 'https://vidfast.vc/tv/$id/$s/$e?autoPlay=true',
    ),
    _EmbedProvider(
      name: 'AutoEmbed',
      movie: (id) => 'https://autoembed.co/movie/tmdb/$id',
      tv: (id, s, e) => 'https://autoembed.co/tv/tmdb/$id-$s-$e',
    ),
    _EmbedProvider(
      name: 'MultiEmbed',
      movie: (id) => 'https://multiembed.mov/?video_id=$id&tmdb=1',
      tv: (id, s, e) => 'https://multiembed.mov/?video_id=$id&tmdb=1&s=$s&e=$e',
    ),
    // Tier 2 - Good Coverage
    _EmbedProvider(
      name: '2Embed',
      movie: (id) => 'https://www.2embed.cc/embed/$id',
      tv: (id, s, e) => 'https://www.2embed.cc/embedtv/$id&s=$s&e=$e',
    ),
    _EmbedProvider(
      name: '2Embed Skin',
      movie: (id) => 'https://www.2embed.skin/embed/$id',
      tv: (id, s, e) => 'https://www.2embed.skin/embedtv/$id&s=$s&e=$e',
    ),
    _EmbedProvider(
      name: 'NontonGo',
      movie: (id) => 'https://www.nontongo.win/embed/movie/$id',
      tv: (id, s, e) => 'https://www.nontongo.win/embed/tv/$id/$s/$e',
    ),
    _EmbedProvider(
      name: 'MoviesAPI',
      movie: (id) => 'https://moviesapi.to/movie/$id',
      tv: (id, s, e) => 'https://moviesapi.to/tv/$id/$s/$e',
    ),
    _EmbedProvider(
      name: 'VidPhantom',
      movie: (id) => 'https://vidphantom.com/movie/$id',
      tv: (id, s, e) => 'https://vidphantom.com/tv/$id/$s/$e',
    ),
    // Tier 3 - Backup Mirrors
    _EmbedProvider(
      name: 'Filmu',
      movie: (id) => 'https://embed.filmu.in/movie/$id',
      tv: (id, s, e) => 'https://embed.filmu.in/tv/$id/$s/$e',
    ),
    _EmbedProvider(
      name: 'VidSrc Top',
      movie: (id) => 'https://vid-src.top/embed/movie/$id',
      tv: (id, s, e) => 'https://vid-src.top/embed/tv/$id/$s/$e',
    ),
  ];

  // ── getAllEmbedProviders ───────────────────────────────────────────────────

  static List<Map<String, String>> getAllEmbedProviders({
    required int tmdbId,
    required bool isMovie,
    int season = 1,
    int episode = 1,
  }) {
    final providers = _providers.map((p) {
      final url = isMovie ? p.movie(tmdbId) : p.tv(tmdbId, season, episode);
      return {'name': p.name, 'url': url};
    }).toList();

    debugPrint('📋 getAllEmbedProviders: ${providers.length} mirrors generated');
    for (final p in providers) {
      debugPrint('   ${p['name']}: ${p['url']}');
    }

    return providers;
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
    'popmonetizer.com', 'trafficjunky.com',
    'casalemedia.com', 'moatads.com', 'springserve.com', 'spotxchange.com',
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
    'popcash','adcash','taboola','outbrain','mgid','revcontent','popmonetizer'];
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
  var SK=['vidlink','vidsrc','embed','multiembed','smash','autoembed','vidfast','2embed','vsembed','vidphantom','nontongo','moviesapi','filmu','vid-src'];
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
      }) async {
    debugPrint('═══════════════════════════════════');
    debugPrint('🎬 RESOLVE MOVIE');
    debugPrint('   TMDB ID: $tmdbId');
    debugPrint('   Title: $title');
    final url = 'https://vidlink.pro/movie/$tmdbId?autoplay=true';
    debugPrint('   Generated URL: $url');
    debugPrint('═══════════════════════════════════');
    onStatus?.call('Loading stream...');
    return StreamResult.webEmbed(url, sourceName: 'VidLink');
  }

  static Future<StreamResult?> resolveTv(
      int tmdbId,
      int season,
      int episode,
      String title, {
        void Function(String)? onStatus,
      }) async {
    debugPrint('═══════════════════════════════════');
    debugPrint('📺 RESOLVE TV');
    debugPrint('   TMDB ID: $tmdbId');
    debugPrint('   Title: $title S${season}E${episode}');
    final url = 'https://vidlink.pro/tv/$tmdbId/$season/$episode?autoplay=true';
    debugPrint('   Generated URL: $url');
    debugPrint('═══════════════════════════════════');
    onStatus?.call('Loading stream...');
    return StreamResult.webEmbed(url, sourceName: 'VidLink');
  }
}

class _EmbedProvider {
  final String name;
  final String Function(int tmdbId) movie;
  final String Function(int tmdbId, int season, int episode) tv;
  const _EmbedProvider({required this.name, required this.movie, required this.tv});
}

class StreamResult {
  final String url;
  final String source;
  final bool isNative;
  const StreamResult({required this.url, required this.source, required this.isNative});
  factory StreamResult.webEmbed(String url, {String sourceName = 'Web Embed'}) =>
      StreamResult(url: url, source: sourceName, isNative: false);
}