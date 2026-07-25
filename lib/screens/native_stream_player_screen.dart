import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:simple_pip_mode/simple_pip.dart';
import '../theme/app_theme.dart';
import '../services/stream_resolver_service.dart';
import '../services/database_service.dart';

class NativeStreamPlayerScreen extends StatefulWidget {
  final int id;
  final String title;
  final String mediaType;
  final int season;
  final int episode;
  final List<dynamic> seasons;
  final bool isOffline;
  final String? localFilePath;

  const NativeStreamPlayerScreen({
    super.key,
    required this.id,
    required this.title,
    required this.mediaType,
    required this.season,
    required this.episode,
    this.seasons = const [],
    this.isOffline = false,
    this.localFilePath,
  });

  @override
  State<NativeStreamPlayerScreen> createState() => _NativeStreamPlayerScreenState();
}

class _NativeStreamPlayerScreenState extends State<NativeStreamPlayerScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {

  // ── State ────────────────────────────────────────────────────────────────
  int _currentSeason = 1;
  int _currentEpisode = 1;
  int _episodeCount = 10;

  bool _isResolving = true;       // Looking up stream URL
  String _resolvingStatus = 'Finding best stream...';
  bool _isNativeMode = false;     // true = media_kit, false = WebView
  bool _isUnavailable = false;
  String? _streamUrl;
  String? _streamSource;

  // Controls
  bool _isControlsVisible = true;
  bool _isLocked = false;
  bool _isEpisodePanelVisible = false;

  // Timers
  Timer? _controlsTimer;
  Timer? _unavailableTimer;
  Timer? _loadingTimeout;

  // Gesture
  double _brightness = 0.5;
  double _volume = 1.0;
  bool _showBrightnessOverlay = false;
  bool _showVolumeOverlay = false;

  // Animations
  late AnimationController _controlsAnimController;
  late Animation<double> _controlsFade;
  late AnimationController _episodePanelController;
  late Animation<Offset> _episodePanelSlide;

  // Media Kit (native player)
  late final Player _player = Player();
  late final VideoController _videoController = VideoController(_player);

  // WebView (fallback)
  InAppWebViewController? _webController;
  bool _webLoading = false;
  int _webMirrorIndex = 0;
  bool _autoSwitchTriggered = false; // Guard against repeated auto-switches
  final Map<int, bool?> _mirrorHealth = {}; // null=unknown, true=good, false=bad

  // Progress tracking
  Timer? _progressTimer;

  // Web mirrors for fallback
  final List<Map<String, String>> _mirrors = [
    {'name': 'VidLink', 'id': 'vidlink'},
    {'name': 'VidSrc', 'id': 'vidsrc'},
    {'name': 'EmbedSU', 'id': 'embedsu'},
    {'name': 'VidSrc.cc', 'id': 'vidsrccc'},
    {'name': 'VidSrc.me', 'id': 'vidsrcme'},
    {'name': 'AutoEmbed', 'id': 'autoembed'},
    {'name': 'Smashy', 'id': 'smashy'},
    {'name': '2Embed', 'id': 'twoembed'},
    {'name': 'SuperEmbed', 'id': 'superembed'},
  ];

  // ── Ad Blocker JS ─────────────────────────────────────────────────────────
  static const String _adBlockerScript = '''
(function() {
  // Block all popup windows and new tab opens
  window.open = function() { return null; };
  window.alert = function() {};
  window.confirm = function() { return true; };
  window.prompt = function() { return null; };

  // Block all ad networks at domain level
  var adDomains = ['doubleclick','googlesyndication','popads','trafficjunky',
    'adclick','exoclick','juicyads','ero-advertising','hilltopads','propellerads',
    'plugrush','adsterra','yllix','admaven','popcash','adcash','revcontent'];

  // Override XMLHttpRequest to block ad requests
  var origOpen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function(method, url) {
    if (adDomains.some(d => url && url.includes(d))) return;
    return origOpen.apply(this, arguments);
  };

  // Deep-nuke ad overlays every second
  function nukeAds() {
    // Target ad-specific elements
    var adSelectors = [
      'div[id*="ad"]', 'div[class*="ad-"]', 'div[class*="ads-"]',
      'div[class*="popup"]', 'div[class*="overlay"]', 'div[class*="modal"]',
      'ins.adsbygoogle', 'iframe[src*="ads"]', 'iframe[src*="doubleclick"]',
      'iframe[src*="googlesyndication"]', 'iframe[src*="popads"]',
      'a[href*="doubleclick"]', 'a[href*="googlesyndication"]',
      'div[style*="z-index: 9"]', 'div[style*="z-index:9"]',
    ];
    adSelectors.forEach(function(sel) {
      document.querySelectorAll(sel).forEach(function(el) {
        // Never remove the actual video player iframe or video tag
        if (!el.querySelector('video') && !el.querySelector('iframe[src*="embed"]')
            && !el.querySelector('iframe[src*="vidlink"]') && !el.querySelector('iframe[src*="vidsrc"]')) {
          el.remove();
        }
      });
    });
    
    // Block link clicks that lead to ad domains
    document.querySelectorAll('a').forEach(function(a) {
      var href = a.href || '';
      if (adDomains.some(d => href.includes(d))) {
        a.addEventListener('click', function(e) { e.preventDefault(); e.stopPropagation(); }, true);
        a.href = '#';
      }
    });
  }
  
  // Run immediately and keep running
  nukeAds();
  setInterval(nukeAds, 800);
  
  // Intercept any click that could lead to an ad domain
  document.addEventListener('click', function(e) {
    var el = e.target;
    // Walk up the DOM tree to check parents
    while (el) {
      var href = (el.href || el.getAttribute && el.getAttribute('href') || '') + '';
      if (adDomains.some(d => href.includes(d))) {
        e.preventDefault();
        e.stopPropagation();
        return;
      }
      el = el.parentElement;
    }
    // Notify Flutter of the tap so it can reveal the menu
    if (window.flutter_inappwebview) {
      window.flutter_inappwebview.callHandler('onTap');
    }
  }, true);
})();
''';

  // ── Skip Ad JS (Nuclear Option) ────────────────────────────────────────────
  static const String _skipAdScript = '''
(function() {
  // Click any skip buttons
  ['skip','Skip','SKIP','skip-ad','skipAd','skip_ad','btn-skip'].forEach(function(kw) {
    document.querySelectorAll('[class*="' + kw + '"],[id*="' + kw + '"],[aria-label*="' + kw + '"]').forEach(function(el) {
      el.click();
    });
  });
  
  // Remove all overlay divs (except the real player)
  document.querySelectorAll('div, aside, section').forEach(function(el) {
    var style = window.getComputedStyle(el);
    var zIndex = parseInt(style.zIndex) || 0;
    var pos = style.position;
    if ((pos === "fixed" || pos === "absolute") && zIndex > 100) {
      if (!el.querySelector('video') && !el.querySelector('iframe[src*="embed"]')) {
        el.remove();
      }
    }
  });
  
  // Auto-play the video if paused
  document.querySelectorAll('video').forEach(function(v) {
    v.play();
    v.muted = false;
  });
})();
''';

  // ── Init ──────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentSeason = widget.season;
    _currentEpisode = widget.episode;
    _currentEpisode = widget.episode;
    _calculateEpisodeCount();

    // Do not force landscape on init, allow portrait initially
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _controlsAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _controlsFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controlsAnimController, curve: Curves.easeInOut));
    _controlsAnimController.forward();

    _episodePanelController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _episodePanelSlide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
      CurvedAnimation(parent: _episodePanelController, curve: Curves.easeOut));

    _startControlsTimer();
    _resolveAndPlay();
    // Start periodic progress saver every 10 seconds
    _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) => _saveProgress());
  }

  // ── Stream Resolution ─────────────────────────────────────────────────────
  Future<void> _resolveAndPlay({int? overrideSeason, int? overrideEpisode}) async {
    final s = overrideSeason ?? _currentSeason;
    final e = overrideEpisode ?? _currentEpisode;

    setState(() {
      _isResolving = true;
      _isUnavailable = false;
      _isNativeMode = false;
      _resolvingStatus = 'Searching Consumet for real stream...';
    });

    StreamResult? result;
    try {
      if (widget.mediaType == 'movie') {
        setState(() => _resolvingStatus = 'Searching FlixHQ for "${widget.title}"...');
        result = await StreamResolverService.resolveMovie(widget.id, widget.title);
      } else {
        setState(() => _resolvingStatus = 'Searching for S${s}E$e of "${widget.title}"...');
        result = await StreamResolverService.resolveTv(widget.id, s, e, widget.title);
      }
    } catch (_) {
      result = null;
    }

    if (!mounted) return;

    if (result != null && result.isNative) {
      // ✅ Got a real native stream — use media_kit
      setState(() {
        _isResolving = false;
        _isNativeMode = true;
        _streamUrl = result!.url;
        _streamSource = result.source;
      });
      await _player.open(Media(_streamUrl!));
      // Save to history
      if (mounted) {
        Provider.of<DatabaseService>(context, listen: false).addToHistory(
          {'id': widget.id, 'title': widget.title, 'poster_path': null, 'media_type': widget.mediaType},
          season: widget.mediaType == 'tv' ? _currentSeason : null,
          episode: widget.mediaType == 'tv' ? _currentEpisode : null,
        );
      }
    } else if (result != null && !result.isNative) {
      // ⚠️ Fallback to WebView with best embed URL
      setState(() {
        _isResolving = false;
        _isNativeMode = false;
        _streamUrl = result!.url;
        _streamSource = result.source;
        _webMirrorIndex = 0;
        _webLoading = true;
      });
      _startWebLoadingTimeout();
      // Save to history even for web embeds
      if (mounted) {
        Provider.of<DatabaseService>(context, listen: false).addToHistory(
          {'id': widget.id, 'title': widget.title, 'poster_path': null, 'media_type': widget.mediaType},
          season: widget.mediaType == 'tv' ? _currentSeason : null,
          episode: widget.mediaType == 'tv' ? _currentEpisode : null,
        );
      }
    } else {
      // ❌ Total failure
      setState(() {
        _isResolving = false;
        _isUnavailable = true;
      });
    }
  }

  String _buildWebUrl(int mirrorIndex) {
    final m = _mirrors[mirrorIndex]['id']!;
    final id = widget.id;
    final s = _currentSeason;
    final e = _currentEpisode;
    final isMovie = widget.mediaType == 'movie';

    switch (m) {
      case 'vidlink': return isMovie
          ? 'https://vidlink.pro/movie/$id?autoplay=true&primaryColor=6C63FF'
          : 'https://vidlink.pro/tv/$id/$s/$e?autoplay=true&primaryColor=6C63FF';
      case 'vidsrc': return isMovie
          ? 'https://vidsrc.to/embed/movie/$id'
          : 'https://vidsrc.to/embed/tv/$id/$s/$e';
      case 'embedsu': return isMovie
          ? 'https://embed.su/embed/movie/$id'
          : 'https://embed.su/embed/tv/$id/$s/$e';
      case 'vidsrccc': return isMovie
          ? 'https://vidsrc.cc/v2/embed/movie/$id'
          : 'https://vidsrc.cc/v2/embed/tv/$id/$s/$e';
      case 'vidsrcme': return isMovie
          ? 'https://vidsrc.me/embed/movie?tmdb=$id'
          : 'https://vidsrc.me/embed/tv?tmdb=$id&season=$s&episode=$e';
      case 'autoembed': return isMovie
          ? 'https://autoembed.co/movie/tmdb/$id'
          : 'https://autoembed.co/tv/tmdb/$id-$s-$e';
      case 'smashy': return isMovie
          ? 'https://embed.smashystream.com/playere.php?tmdb=$id'
          : 'https://embed.smashystream.com/playere.php?tmdb=$id&season=$s&episode=$e';
      case 'twoembed': return isMovie
          ? 'https://www.2embed.cc/embed/$id'
          : 'https://www.2embed.cc/embedtv/$id&s=$s&e=$e';
      case 'superembed': return isMovie
          ? 'https://multiembed.mov/?video_id=$id&tmdb=1'
          : 'https://multiembed.mov/?video_id=$id&tmdb=1&s=$s&e=$e';
      default: return 'https://vidlink.pro/movie/$id';
    }
  }

  void _switchWebMirror(int index) {
    setState(() {
      _webMirrorIndex = index;
      _webLoading = true;
      _mirrorHealth[index] = null; // Reset health on manual switch
    });
    _startWebLoadingTimeout();
    _webController?.loadUrl(urlRequest: URLRequest(url: Uri.parse(_buildWebUrl(index))));
  }

  void _startWebLoadingTimeout() {
    _loadingTimeout?.cancel();
    _autoSwitchTriggered = false;
    _loadingTimeout = Timer(const Duration(seconds: 12), () {
      // Auto-switch to next mirror if current one stalls
      if (mounted && _webLoading && !_autoSwitchTriggered) {
        final nextIndex = (_webMirrorIndex + 1) % _mirrors.length;
        _autoSwitchTriggered = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_mirrors[_webMirrorIndex]["name"]} timed out — switching to ${_mirrors[nextIndex]["name"]}...', 
                style: const TextStyle(color: Colors.white)),
              backgroundColor: Colors.black87,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        _switchWebMirror(nextIndex);
      }
    });
  }

  void _switchEpisode(int ep) {
    setState(() {
      _currentEpisode = ep;
      _isEpisodePanelVisible = false;
    });
    _episodePanelController.reverse();
    if (_isNativeMode) {
      _resolveAndPlay(overrideSeason: _currentSeason, overrideEpisode: ep);
    } else {
      _webController?.loadUrl(urlRequest: URLRequest(url: Uri.parse(_buildWebUrl(_webMirrorIndex))));
    }
  }

  void _switchSeason(int s) {
    setState(() { _currentSeason = s; _currentEpisode = 1; });
    _calculateEpisodeCount();
    if (_isNativeMode) {
      _resolveAndPlay(overrideSeason: s, overrideEpisode: 1);
    } else {
      _webController?.loadUrl(urlRequest: URLRequest(url: Uri.parse(_buildWebUrl(_webMirrorIndex))));
    }
  }

  void _calculateEpisodeCount() {
    if (widget.seasons.isNotEmpty) {
      final s = widget.seasons.firstWhere(
        (s) => s['season_number'] == _currentSeason,
        orElse: () => widget.seasons.first);
      _episodeCount = s['episode_count'] ?? 10;
    }
  }

  // ── Controls ──────────────────────────────────────────────────────────────
  void _startControlsTimer() {
    _controlsTimer?.cancel();
    if (_isLocked) return;
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) { setState(() => _isControlsVisible = false); _controlsAnimController.reverse(); }
    });
  }

  void _toggleControls() {
    if (_isLocked) return;
    setState(() => _isControlsVisible = !_isControlsVisible);
    if (_isControlsVisible) { _controlsAnimController.forward(); _startControlsTimer(); }
    else { _controlsAnimController.reverse(); _controlsTimer?.cancel(); }
  }

  void _handleVerticalDrag(DragUpdateDetails d, bool isLeft) async {
    final delta = -d.primaryDelta! / 250.0;
    if (isLeft) {
      setState(() { _brightness = (_brightness + delta).clamp(0.0, 1.0); _showBrightnessOverlay = true; });
      try { await ScreenBrightness().setScreenBrightness(_brightness); } catch (_) {}
    } else {
      setState(() { _volume = (_volume + delta).clamp(0.0, 1.0); _showVolumeOverlay = true; });
      if (_isNativeMode) {
        _player.setVolume(_volume * 100);
      } else {
        _webController?.evaluateJavascript(source:
          'var v=document.querySelector("video"); if(v) v.volume=${_volume.toStringAsFixed(2)};');
      }
    }
  }

  void _handleVerticalDragEnd(bool isLeft) {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() { _showBrightnessOverlay = false; _showVolumeOverlay = false; });
    });
  }

  void _seekRelative(int seconds) {
    if (_isNativeMode) {
      final pos = _player.state.position + Duration(seconds: seconds);
      _player.seek(pos);
    } else {
      _webController?.evaluateJavascript(source:
        'var v=document.querySelector("video"); if(v) v.currentTime+=$seconds;');
    }
    _showControlsBriefly();
  }

  void _showControlsBriefly() {
    setState(() => _isControlsVisible = true);
    _controlsAnimController.forward();
    _startControlsTimer();
  }

  void _togglePlayPause() {
    if (_isNativeMode) {
      _player.playOrPause();
    } else {
      _webController?.evaluateJavascript(source:
        'var v=document.querySelector("video"); if(v) { v.paused ? v.play() : v.pause(); }');
    }
  }

  void _toggleEpisodePanel() {
    setState(() => _isEpisodePanelVisible = !_isEpisodePanelVisible);
    _isEpisodePanelVisible ? _episodePanelController.forward() : _episodePanelController.reverse();
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      try { SimplePip().enterPipMode(); } catch (_) {}
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controlsTimer?.cancel();
    _unavailableTimer?.cancel();
    _loadingTimeout?.cancel();
    _progressTimer?.cancel();
    _controlsAnimController.dispose();
    _episodePanelController.dispose();
    _player.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    try { ScreenBrightness().resetScreenBrightness(); } catch (_) {}
    super.dispose();
  }

  void _saveProgress() {
    if (!mounted || !_isNativeMode) return;
    final db = Provider.of<DatabaseService>(context, listen: false);
    final pos = _player.state.position.inSeconds;
    final dur = _player.state.duration.inSeconds;
    if (dur > 0) {
      db.updateHistoryProgress(widget.id, pos, dur);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── 1. Video area ──────────────────────────────────────────────
            Positioned.fill(child: _buildVideoArea()),

            // ── 2. Gesture overlay (Native Mode Only) ──────────────────────
            if (_isNativeMode && !_isResolving && !_isUnavailable)
              _buildGestureLayer(),

            // ── 3. Resolving overlay ───────────────────────────────────────
            if (_isResolving) _buildResolvingOverlay(),

            // ── 4. Unavailable overlay ─────────────────────────────────────
            if (_isUnavailable) _buildUnavailableOverlay(),

            // ── 5. Controls ─────────────────────────────────────────────────
            if (!_isLocked && !_isResolving && !_isUnavailable)
              FadeTransition(opacity: _controlsFade, child: _buildControlsOverlay()),

            // ── 6. Lock indicator ──────────────────────────────────────────
            if (_isLocked) _buildLockIndicator(),

            // ── 7. Brightness/Volume overlays ──────────────────────────────
            if (_showBrightnessOverlay)
              Positioned(left: 40, top: 0, bottom: 0, child: Center(
                child: _buildSliderIndicator(Icons.brightness_6, _brightness, Colors.yellow))),
            if (_showVolumeOverlay)
              Positioned(right: 40, top: 0, bottom: 0, child: Center(
                child: _buildSliderIndicator(Icons.volume_up, _volume, Colors.white))),

            // ── 8. Episode panel ────────────────────────────────────────────
            if (widget.mediaType == 'tv')
              SlideTransition(position: _episodePanelSlide,
                child: Align(alignment: Alignment.bottomCenter, child: _buildEpisodePanel())),

            // ── 9. Web Mode: Tap-to-Wake Menu + Skip Ad Button ──────────────────
            if (!_isNativeMode && !_isResolving && !_isUnavailable) ...[
              // Menu button always visible in top-left corner
              if (!_isControlsVisible)
                Positioned(
                  top: 44,
                  left: 16,
                  child: GestureDetector(
                    onTap: _toggleControls,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text('Menu', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),

              // Skip Ad button always visible in top-right corner
              Positioned(
                top: 44,
                right: 16,
                child: GestureDetector(
                  onTap: () async {
                    await _webController?.evaluateJavascript(source: _skipAdScript);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('\u26a1 Ad Nuke fired!', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        backgroundColor: Color(0xFF6C63FF),
                        duration: Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.skip_next, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('Skip Ad', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Video Area ────────────────────────────────────────────────────────────
  Widget _buildVideoArea() {
    if (_isResolving || _isUnavailable) {
      return Container(color: Colors.black);
    }
    if (_isNativeMode && _streamUrl != null) {
      return Video(controller: _videoController);
    }
    // WebView fallback
    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(url: Uri.parse(_streamUrl ?? _buildWebUrl(0))),
          initialOptions: InAppWebViewGroupOptions(
            crossPlatform: InAppWebViewOptions(
              mediaPlaybackRequiresUserGesture: false,
              javaScriptEnabled: true,
              transparentBackground: true,
              disableContextMenu: true,
              supportZoom: false,
              userAgent: 'Mozilla/5.0 (Linux; Android 12; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Mobile Safari/537.36',
            ),
            android: AndroidInAppWebViewOptions(useHybridComposition: true, hardwareAcceleration: true),
          ),
          onWebViewCreated: (ctrl) {
            _webController = ctrl;
            ctrl.addJavaScriptHandler(handlerName: 'onTap', callback: (_) {
              if (mounted && !_isControlsVisible) _toggleControls();
            });
          },
          onCreateWindow: (_, __) async => false, // Block popup windows/new tabs
          onLoadStart: (_, __) => setState(() => _webLoading = true),
          onLoadStop: (ctrl, _) async {
            setState(() {
              _webLoading = false;
              _mirrorHealth[_webMirrorIndex] = true; // Mark current mirror as healthy
            });
            await ctrl.evaluateJavascript(source: _adBlockerScript);
          },
          shouldOverrideUrlLoading: (_, action) async {
            final url = action.request.url?.toString() ?? '';
            final allowed = ['vidsrc','vidlink','embed','multiembed','smash','autoembed','2embed'];
            if (!allowed.any((k) => url.contains(k))) return NavigationActionPolicy.CANCEL;
            return NavigationActionPolicy.ALLOW;
          },
        ),
        if (_webLoading)
          Container(color: Colors.black87, child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 3),
              const SizedBox(height: 16),
              Text('Loading ${_mirrors[_webMirrorIndex]['name']}...',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          )),
      ],
    );
  }

  // ── Gesture Layer ─────────────────────────────────────────────────────────
  Widget _buildGestureLayer() {
    return Row(children: [
      Expanded(child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          if (!_isControlsVisible) _toggleControls();
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _toggleControls,
          onDoubleTap: () => _seekRelative(-10),
          onVerticalDragUpdate: (d) => _handleVerticalDrag(d, true),
          onVerticalDragEnd: (_) => _handleVerticalDragEnd(true),
        ),
      )),
      Expanded(child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          if (!_isControlsVisible) _toggleControls();
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _toggleControls,
          onDoubleTap: () => _seekRelative(10),
          onVerticalDragUpdate: (d) => _handleVerticalDrag(d, false),
          onVerticalDragEnd: (_) => _handleVerticalDragEnd(false),
        ),
      )),
    ]);
  }

  // ── Resolving Overlay ─────────────────────────────────────────────────────
  Widget _buildResolvingOverlay() {
    return Container(color: Colors.black, child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 56, height: 56,
          child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2.5)),
        const SizedBox(height: 20),
        Text(_resolvingStatus,
          style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 8),
        Text('Trying Consumet → VidSrc.xyz → Web Embed',
          style: TextStyle(color: Colors.white38, fontSize: 11)),
      ]),
    ));
  }

  // ── Unavailable Overlay ───────────────────────────────────────────────────
  Widget _buildUnavailableOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.95),
      child: Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.withValues(alpha: 0.12),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5), width: 2),
            ),
            child: const Icon(Icons.movie_filter_outlined, color: Colors.redAccent, size: 36),
          ),
          const SizedBox(height: 20),
          const Text('Not Available', style: TextStyle(
            color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(
            '"${widget.title}" is not indexed on any of our streaming sources right now.\n\nThis usually means the content is very new, very old, or region-specific.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _resolveAndPlay,
            icon: const Icon(Icons.refresh_rounded, color: Colors.black),
            label: const Text('Try Again', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
            label: const Text('Go Back', style: TextStyle(color: Colors.white70)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ]),
      )),
    );
  }

  // ── Controls Overlay ──────────────────────────────────────────────────────
  Widget _buildControlsOverlay() {
    final title = widget.mediaType == 'tv'
        ? '${widget.title}  •  S$_currentSeason E$_currentEpisode'
        : widget.title;

    // ── WEB MODE: Slim top-strip only. Nothing else. ───────────────────────
    if (!_isNativeMode) {
      return Positioned(
        top: 0, left: 0, right: 0,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xDD000000), Colors.transparent],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Row 1: Back + Title
              Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                  onPressed: () {
                    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
                    Navigator.pop(context);
                  },
                ),
                Expanded(child: Text(title,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis)),
                IconButton(
                  icon: const Icon(Icons.screen_rotation, color: Colors.white70, size: 20),
                  onPressed: () {
                    if (MediaQuery.of(context).orientation == Orientation.portrait) {
                      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
                    } else {
                      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
                    }
                    Future.delayed(const Duration(seconds: 3), () {
                      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
                    });
                  },
                ),
              ]),
              // Row 2: Mirror pills scrollable
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 12, right: 12, bottom: 6),
                  itemCount: _mirrors.length,
                  itemBuilder: (_, i) {
                    final sel = i == _webMirrorIndex;
                    final health = _mirrorHealth[i];
                    final dot = health == null ? Colors.white38 : health ? Colors.greenAccent : Colors.redAccent;
                    return GestureDetector(
                      onTap: () => _switchWebMirror(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: sel ? AppTheme.accent : Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: sel ? AppTheme.accent : Colors.white24),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                          const SizedBox(width: 5),
                          Text(_mirrors[i]['name']!,
                            style: TextStyle(color: sel ? Colors.black : Colors.white,
                              fontSize: 11, fontWeight: sel ? FontWeight.bold : FontWeight.w500)),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ]),
          ),
        ),
      );
    }

    // ── NATIVE MODE: Full overlay with gradient + all controls ─────────────
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xCC000000), Colors.transparent, Color(0xCC000000)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: SafeArea(child: Stack(children: [
        // Top bar
        Positioned(top: 0, left: 0, right: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
                onPressed: () {
                  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(width: 4),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
                if (_streamSource != null)
                  Text('via $_streamSource',
                    style: TextStyle(color: AppTheme.accent.withValues(alpha: 0.8), fontSize: 11)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.6))),
                child: Text('🎬 Native',
                  style: TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.lock_open, color: Colors.white70, size: 20),
                onPressed: () { setState(() => _isLocked = true); _controlsTimer?.cancel(); },
              ),
              IconButton(
                icon: const Icon(Icons.screen_rotation, color: Colors.white70, size: 20),
                onPressed: () {
                  if (MediaQuery.of(context).orientation == Orientation.portrait) {
                    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
                  } else {
                    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
                  }
                  Future.delayed(const Duration(seconds: 3), () {
                    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.picture_in_picture_alt, color: Colors.white70, size: 20),
                onPressed: () { try { SimplePip().enterPipMode(); } catch (_) {} },
              ),
            ]),
          ),
        ),

        // Center play/pause
        Center(child: GestureDetector(
          onTap: _togglePlayPause,
          child: Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: Colors.black54, shape: BoxShape.circle,
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.6), width: 2)),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
          ),
        )),

        // Bottom bar (Native only — full controls)
        Positioned(bottom: 0, left: 0, right: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Progress bar
              StreamBuilder(
                stream: _player.stream.position,
                builder: (_, snapshot) {
                  final pos = snapshot.data ?? Duration.zero;
                  final dur = _player.state.duration;
                  final progress = dur.inMilliseconds > 0 ? pos.inMilliseconds / dur.inMilliseconds : 0.0;
                  return Column(children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                        activeTrackColor: AppTheme.accent,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: progress.clamp(0.0, 1.0),
                        onChanged: (v) {
                          final target = Duration(milliseconds: (v * dur.inMilliseconds).round());
                          _player.seek(target);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(_formatDuration(pos), style: const TextStyle(color: Colors.white60, fontSize: 11)),
                        Text(_formatDuration(dur), style: const TextStyle(color: Colors.white60, fontSize: 11)),
                      ]),
                    ),
                  ]);
                },
              ),
              const SizedBox(height: 4),
              // Seek + Episodes row
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _circleButton(Icons.replay_10, () => _seekRelative(-10)),
                if (widget.mediaType == 'tv')
                  GestureDetector(
                    onTap: _toggleEpisodePanel,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white12, borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24)),
                      child: const Row(children: [
                        Icon(Icons.list, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text('Episodes', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ]),
                    ),
                  ),
                _circleButton(Icons.forward_10, () => _seekRelative(10)),
              ]),
            ]),
          ),
        ),
      ])),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
          color: Colors.black54, shape: BoxShape.circle,
          border: Border.all(color: Colors.white24)),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildSliderIndicator(IconData icon, double value, Color color) {
    return Container(
      width: 50,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(30)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        RotatedBox(quarterTurns: -1,
          child: LinearProgressIndicator(
            value: value, color: color, backgroundColor: Colors.white24, minHeight: 4,
            borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 4),
        Text('${(value * 100).round()}%', style: TextStyle(color: color, fontSize: 10)),
      ]),
    );
  }

  Widget _buildLockIndicator() {
    return Positioned(top: 16, left: 16,
      child: GestureDetector(
        onTap: () => setState(() => _isLocked = false),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black87, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.5))),
          child: Row(children: [
            Icon(Icons.lock, color: AppTheme.accent, size: 16),
            const SizedBox(width: 6),
            const Text('Tap to Unlock', style: TextStyle(color: Colors.white, fontSize: 12)),
          ]),
        ),
      ),
    );
  }

  // ── Episode Panel ─────────────────────────────────────────────────────────
  Widget _buildEpisodePanel() {
    final seasonCount = widget.seasons.length;
    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xEE0D0D1A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Container(margin: const EdgeInsets.symmetric(vertical: 8),
          width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2))),
        if (seasonCount > 1)
          SizedBox(height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: seasonCount,
              itemBuilder: (_, i) {
                final sn = widget.seasons[i]['season_number'] as int? ?? i + 1;
                final sel = sn == _currentSeason;
                return GestureDetector(
                  onTap: () => _switchSeason(sn),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? AppTheme.accent : Colors.white10,
                      borderRadius: BorderRadius.circular(16)),
                    child: Text('Season $sn',
                      style: TextStyle(
                        color: sel ? Colors.black : Colors.white70,
                        fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        Expanded(child: GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          scrollDirection: Axis.horizontal,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 0.6),
          itemCount: _episodeCount,
          itemBuilder: (_, i) {
            final ep = i + 1;
            final sel = ep == _currentEpisode;
            return GestureDetector(
              onTap: () => _switchEpisode(ep),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: sel ? AppTheme.accent : Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? AppTheme.accent : Colors.white12)),
                child: Center(child: Text('E$ep',
                  style: TextStyle(
                    color: sel ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold, fontSize: 13))),
              ),
            );
          },
        )),
      ]),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
