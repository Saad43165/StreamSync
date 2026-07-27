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
import '../services/mini_player_service.dart';

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
  State<NativeStreamPlayerScreen> createState() =>
      _NativeStreamPlayerScreenState();
}

class _NativeStreamPlayerScreenState extends State<NativeStreamPlayerScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {

  // ── Core state ─────────────────────────────────────────────────────────────
  int _currentSeason  = 1;
  int _currentEpisode = 1;
  int _episodeCount   = 10;

  bool    _isResolving     = true;
  String  _resolvingStatus = 'Looking for stream…';
  bool    _isNativeMode    = false;
  bool    _isUnavailable   = false;
  String? _streamUrl;
  String? _streamSource;

  // Controls
  bool _isControlsVisible     = true;
  bool _isLocked              = false;
  bool _isEpisodePanelVisible = false;

  // Timers
  Timer? _controlsTimer;
  Timer? _loadingTimeout;
  Timer? _resizeDebounce;
  Timer? _progressTimer;
  Timer? _videoDetectionTimer;

  // Gesture overlays
  double _brightness            = 0.5;
  double _volume                = 1.0;
  bool   _showBrightnessOverlay = false;
  bool   _showVolumeOverlay     = false;

  // Animations
  late AnimationController _controlsAnimController;
  late Animation<double>   _controlsFade;
  late AnimationController _episodePanelController;
  late Animation<Offset>   _episodePanelSlide;

  // Native player
  late final Player          _player          = Player();
  late final VideoController _videoController = VideoController(_player);

  // WebView
  InAppWebViewController? _webController;
  bool _webLoading          = false;
  int  _webMirrorIndex      = 0;
  bool _autoSwitchTriggered = false;
  bool _videoPlayingDetected = false;
  final Map<int, bool?> _mirrorHealth = {};
  Key  _webViewKey = UniqueKey();

  List<Map<String, String>> _mirrors = [];

  // ── Mini Player Service ────────────────────────────────────────────────────
  late final MiniPlayerService _miniPlayerService;

  // ── JavaScript ─────────────────────────────────────────────────────────────

  static const String _layoutFixScript = r'''
(function(){
  var m=document.querySelector('meta[name="viewport"]');
  if(!m){m=document.createElement('meta');m.name='viewport';document.head.appendChild(m);}
  m.setAttribute('content','width=device-width,initial-scale=1.0,maximum-scale=1.0,user-scalable=no,viewport-fit=cover');
  var s=document.getElementById('__fsp__');
  if(!s){s=document.createElement('style');s.id='__fsp__';document.head.appendChild(s);}
  s.textContent=`
    html,body{margin:0!important;padding:0!important;width:100vw!important;
      height:100vh!important;overflow:hidden!important;background:#000!important;
      position:relative!important;}
    video{display:block!important;width:100%!important;height:100%!important;
      max-width:100vw!important;max-height:100vh!important;object-fit:contain!important;
      position:absolute!important;inset:0!important;margin:auto!important;}
    iframe{display:block!important;width:100%!important;height:100%!important;
      border:0!important;position:absolute!important;inset:0!important;}
    #player,.jw-wrapper,.jwplayer,.plyr,.plyr__video-wrapper,.video-container,
    .player-container,.video-js,#video-container,.jw-media,.jw-video,
    [class*="player"],[id*="player"],[class*="video-wrap"]{
      width:100%!important;height:100%!important;max-width:100vw!important;
      max-height:100vh!important;position:absolute!important;inset:0!important;}
  `;
  window.dispatchEvent(new Event('resize'));
  window.dispatchEvent(new Event('orientationchange'));
})();
''';

  static const String _videoPlaybackWatcherScript = r'''
(function() {
  if (window.__vpw) return;
  window.__vpw = true;
  
  let videoPlayingDetected = false;

  function notifyFlutter() {
    if (!videoPlayingDetected && window.flutter_inappwebview) {
      videoPlayingDetected = true;
      window.flutter_inappwebview.callHandler('onVideoPlaying');
    }
  }

  function checkVideoStatus() {
    const videos = document.querySelectorAll('video');
    for (let v of videos) {
      if (!v.paused && !v.ended && v.readyState > 2 && v.currentTime > 0) {
        notifyFlutter();
        return true;
      }
    }
    return false;
  }

  function attachWatcher() {
    document.querySelectorAll('video').forEach(function(v) {
      if (v.__watched) return;
      v.__watched = true;
      
      ['playing', 'play', 'timeupdate', 'progress'].forEach(eventName => {
        v.addEventListener(eventName, function() {
          if (!v.paused && v.currentTime > 0) {
            notifyFlutter();
          }
        });
      });
      
      if (!v.paused && !v.ended && v.readyState > 2 && v.currentTime > 0) {
        notifyFlutter();
      }
    });
  }

  attachWatcher();
  if (checkVideoStatus()) return;

  let attempts = 0;
  const maxAttempts = 40;
  const interval = setInterval(function() {
    attempts++;
    attachWatcher();
    if (checkVideoStatus() || attempts >= maxAttempts) {
      clearInterval(interval);
      if (!videoPlayingDetected && attempts >= maxAttempts && window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler('onVideoDetectionFailed');
      }
    }
  }, 500);
})();
''';

  String get _adKillerScript => StreamResolverService.adBlockScript;

  // ── Init ───────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _miniPlayerService = MiniPlayerService();

    _currentSeason  = widget.season;
    _currentEpisode = widget.episode;
    _calculateEpisodeCount();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _controlsAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _controlsFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _controlsAnimController, curve: Curves.easeInOut));
    _controlsAnimController.forward();

    _episodePanelController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _episodePanelSlide =
        Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _episodePanelController, curve: Curves.easeOut));

    _startControlsTimer();
    _resolveAndPlay();
    _progressTimer = Timer.periodic(
        const Duration(seconds: 10), (_) => _saveProgress());
  }

  // ── Resolution ─────────────────────────────────────────────────────────────
  Future<void> _resolveAndPlay(
      {int? overrideSeason, int? overrideEpisode}) async {
    final s = overrideSeason ?? _currentSeason;
    final e = overrideEpisode ?? _currentEpisode;

    setState(() {
      _isResolving     = true;
      _isUnavailable   = false;
      _isNativeMode    = false;
      _streamUrl       = null;
      _resolvingStatus = 'Looking for stream…';
      _webMirrorIndex  = 0;
      _videoPlayingDetected = false;
      _mirrorHealth.clear();
    });

    _mirrors = StreamResolverService.getAllEmbedProviders(
      tmdbId:  widget.id,
      isMovie: widget.mediaType == 'movie',
      season:  s,
      episode: e,
    );

    StreamResult? result;
    try {
      if (widget.mediaType == 'movie') {
        result = await StreamResolverService.resolveMovie(
          widget.id,
          widget.title,
          onStatus: (msg) {
            if (mounted) setState(() => _resolvingStatus = msg);
          },
        );
      } else {
        result = await StreamResolverService.resolveTv(
          widget.id,
          s,
          e,
          widget.title,
          onStatus: (msg) {
            if (mounted) setState(() => _resolvingStatus = msg);
          },
        );
      }
    } catch (_) {
      result = null;
    }

    if (!mounted) return;

    if (result != null && result.isNative) {
      setState(() {
        _isResolving  = false;
        _isNativeMode = true;
        _streamUrl    = result!.url;
        _streamSource = result.source;
      });
      await _player.open(Media(_streamUrl!));
      _addToHistory();
    } else if (result != null && !result.isNative) {
      final resolvedIndex = _mirrors.indexWhere(
              (m) => m['name'] == result!.source.replaceAll(' (fallback)', ''));
      setState(() {
        _isResolving    = false;
        _isNativeMode   = false;
        _streamUrl      = result!.url;
        _streamSource   = result.source;
        _webMirrorIndex = resolvedIndex >= 0 ? resolvedIndex : 0;
        _webLoading     = true;
        _webViewKey     = UniqueKey();
      });
      _startWebLoadingTimeout();
      _addToHistory();
    } else {
      setState(() {
        _isResolving   = false;
        _isUnavailable = true;
      });
    }
  }

  void _addToHistory() {
    if (!mounted) return;
    Provider.of<DatabaseService>(context, listen: false).addToHistory(
      {
        'id': widget.id,
        'title': widget.title,
        'poster_path': null,
        'media_type': widget.mediaType,
      },
      season:  widget.mediaType == 'tv' ? _currentSeason  : null,
      episode: widget.mediaType == 'tv' ? _currentEpisode : null,
    );
  }

  // ── Mirror helpers ─────────────────────────────────────────────────────────
  String _mirrorUrl(int index) {
    if (_mirrors.isEmpty) return '';
    if (index >= _mirrors.length) index = 0;
    return _mirrors[index]['url'] ?? '';
  }

  void _switchMirror(int index) {
    if (index == _webMirrorIndex && !_webLoading) return;
    _loadingTimeout?.cancel();
    _videoDetectionTimer?.cancel();

    setState(() {
      _webMirrorIndex      = index;
      _webLoading          = true;
      _videoPlayingDetected = false;
      _mirrorHealth[index] = null;
      _autoSwitchTriggered = false;
      _webViewKey          = UniqueKey();
    });
    _startWebLoadingTimeout();
  }

  void _startWebLoadingTimeout() {
    _loadingTimeout?.cancel();
    _videoDetectionTimer?.cancel();
    _autoSwitchTriggered = false;
    _videoPlayingDetected = false;

    // Increased to 60s for slow embed players that load via iframes
    _loadingTimeout = Timer(const Duration(seconds: 60), () {
      if (!mounted || _autoSwitchTriggered || _videoPlayingDetected) return;
      _checkVideoStatusBeforeSwitch();
    });

    _startVideoDetectionPolling();
  }

  void _startVideoDetectionPolling() {
    _videoDetectionTimer?.cancel();
    _videoDetectionTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || _videoPlayingDetected || _webController == null) {
        timer.cancel();
        return;
      }

      _webController?.evaluateJavascript(source: r'''
        (function() {
          var videos = document.querySelectorAll('video');
          for (var i = 0; i < videos.length; i++) {
            var v = videos[i];
            // More lenient: accept readyState > 0 and playing
            if (!v.paused && !v.ended && v.readyState > 0) {
              return 'playing';
            }
            // Accept video that has loaded metadata
            if (v.readyState >= 2 && v.duration > 0) {
              return 'ready';
            }
          }
          // Check for iframes (common in embed players)
          var iframes = document.querySelectorAll('iframe');
          if (iframes.length > 0) return 'hasIframe';
          return 'none';
        })();
      ''').then((result) {
        if (!mounted || _videoPlayingDetected) {
          timer.cancel();
          return;
        }
        // Accept playing, ready, or hasIframe states
        if (result == 'playing' || result == 'ready' || result == 'hasIframe') {
          _onVideoPlayingDetected();
          timer.cancel();
        }
      }).catchError((_) {
        // Ignore polling errors
      });
    });
  }

  void _checkVideoStatusBeforeSwitch() {
    if (_webController == null || !mounted || _videoPlayingDetected || _autoSwitchTriggered) return;

    _webController?.evaluateJavascript(source: r'''
      (function() {
        var videos = document.querySelectorAll('video');
        for (var i = 0; i < videos.length; i++) {
          var v = videos[i];
          // Check if video has any content loaded
          if (v.readyState > 0 && v.duration > 0) {
            return 'hasVideo';
          }
          if (v.readyState > 0) {
            return 'loading';
          }
        }
        // Check for iframes - many embed players use nested iframes
        var iframes = document.querySelectorAll('iframe');
        if (iframes.length > 0) {
          return 'hasIframe';
        }
        // Check for any media-related elements
        var mediaEls = document.querySelectorAll('[class*="player"], [id*="player"], [class*="video"], .jwplayer, .plyr');
        if (mediaEls.length > 0) {
          return 'hasPlayer';
        }
        return 'none';
      })();
    ''').then((status) {
      if (!mounted || _videoPlayingDetected || _autoSwitchTriggered) return;

      // If page has ANY content (video, iframe, player element), don't switch
      if (status == 'hasVideo' || status == 'loading' || status == 'hasIframe' || status == 'hasPlayer') {
        // Page has media content - extend timeout and keep waiting
        _loadingTimeout?.cancel();
        _loadingTimeout = Timer(const Duration(seconds: 20), () {
          if (!mounted || _videoPlayingDetected || _autoSwitchTriggered) return;
          _finalVideoCheck();
        });
      } else {
        // Truly no media content - safe to switch
        _switchToNextMirror();
      }
    }).catchError((_) {
      if (!mounted || _videoPlayingDetected || _autoSwitchTriggered) return;
      // On error, give benefit of doubt and wait longer
      _loadingTimeout?.cancel();
      _loadingTimeout = Timer(const Duration(seconds: 15), () {
        if (!mounted || _videoPlayingDetected || _autoSwitchTriggered) return;
        _switchToNextMirror();
      });
    });
  }
  void _finalVideoCheck() {
    if (_webController == null || !mounted || _videoPlayingDetected || _autoSwitchTriggered) return;

    _webController?.evaluateJavascript(source: r'''
      (function() {
        var videos = document.querySelectorAll('video');
        for (var i = 0; i < videos.length; i++) {
          var v = videos[i];
          if (!v.paused && !v.ended && v.currentTime > 0) {
            return 'playing';
          }
        }
        // Any video element at all?
        if (videos.length > 0) return 'hasVideo';
        // Any iframe?
        if (document.querySelectorAll('iframe').length > 0) return 'hasIframe';
        return 'none';
      })();
    ''').then((status) {
      if (!mounted || _videoPlayingDetected || _autoSwitchTriggered) return;

      if (status == 'playing' || status == 'hasVideo' || status == 'hasIframe') {
        // Content exists - mark as playing detected
        _onVideoPlayingDetected();
      } else {
        // Truly nothing - switch
        _switchToNextMirror();
      }
    }).catchError((_) {
      if (!mounted || _videoPlayingDetected || _autoSwitchTriggered) return;
      _switchToNextMirror();
    });
  }

  // REPLACE this method:
  void _onVideoPlayingDetected() {
    if (!mounted || _videoPlayingDetected) return;

    _videoPlayingDetected = true;
    _loadingTimeout?.cancel();
    _videoDetectionTimer?.cancel();

    setState(() {
      _webLoading = false;
      _mirrorHealth[_webMirrorIndex] = true;
    });

    // FIXED: Change ScaffoldMessenger.of(context).mounted → mounted
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '✓ ${_mirrors.isNotEmpty ? _mirrors[_webMirrorIndex]["name"] : "Mirror"} - Playing',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green.withOpacity(0.8),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _switchToNextMirror() {
    if (_autoSwitchTriggered || _videoPlayingDetected || _mirrors.isEmpty) return;

    final next = (_webMirrorIndex + 1) % _mirrors.length;
    _autoSwitchTriggered = true;

    // FIXED: Use context.mounted, not ScaffoldMessenger.of(context).mounted
    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '${_mirrors[_webMirrorIndex]["name"]} unavailable — trying ${_mirrors[next]["name"]}…',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black87,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
    }
    _switchMirror(next);
  }
  void _switchEpisode(int ep) {
    setState(() {
      _currentEpisode        = ep;
      _isEpisodePanelVisible = false;
    });
    _episodePanelController.reverse();
    _resolveAndPlay(overrideSeason: _currentSeason, overrideEpisode: ep);
  }

  void _switchSeason(int s) {
    setState(() {
      _currentSeason  = s;
      _currentEpisode = 1;
    });
    _calculateEpisodeCount();
    _resolveAndPlay(overrideSeason: s, overrideEpisode: 1);
  }

  void _calculateEpisodeCount() {
    if (widget.seasons.isNotEmpty) {
      final s = widget.seasons.firstWhere(
            (s) => s['season_number'] == _currentSeason,
        orElse: () => widget.seasons.first,
      );
      _episodeCount = (s['episode_count'] as int?) ?? 10;
    }
  }

  // ── Controls ───────────────────────────────────────────────────────────────
  void _startControlsTimer() {
    _controlsTimer?.cancel();
    if (_isLocked) return;
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _isControlsVisible = false);
        _controlsAnimController.reverse();
      }
    });
  }

  void _toggleControls() {
    if (_isLocked) return;
    setState(() => _isControlsVisible = !_isControlsVisible);
    if (_isControlsVisible) {
      _controlsAnimController.forward();
      _startControlsTimer();
    } else {
      _controlsAnimController.reverse();
      _controlsTimer?.cancel();
    }
  }

  void _handleVerticalDrag(DragUpdateDetails d, bool isLeft) async {
    final delta = -d.primaryDelta! / 250.0;
    if (isLeft) {
      setState(() {
        _brightness            = (_brightness + delta).clamp(0.0, 1.0);
        _showBrightnessOverlay = true;
      });
      try { await ScreenBrightness().setScreenBrightness(_brightness); } catch (_) {}
    } else {
      setState(() {
        _volume            = (_volume + delta).clamp(0.0, 1.0);
        _showVolumeOverlay = true;
      });
      if (_isNativeMode) {
        _player.setVolume(_volume * 100);
      } else {
        _webController?.evaluateJavascript(
            source:
            'var v=document.querySelector("video");if(v)v.volume=${_volume.toStringAsFixed(2)};');
      }
    }
  }

  void _handleVerticalDragEnd(bool _) {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _showBrightnessOverlay = false;
          _showVolumeOverlay     = false;
        });
      }
    });
  }

  void _seekRelative(int seconds) {
    if (_isNativeMode) {
      _player.seek(_player.state.position + Duration(seconds: seconds));
    } else {
      _webController?.evaluateJavascript(
          source:
          'var v=document.querySelector("video");if(v)v.currentTime+=$seconds;');
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
      _webController?.evaluateJavascript(
          source:
          'var v=document.querySelector("video");if(v){v.paused?v.play():v.pause();}');
    }
  }

  void _toggleEpisodePanel() {
    setState(() => _isEpisodePanelVisible = !_isEpisodePanelVisible);
    _isEpisodePanelVisible
        ? _episodePanelController.forward()
        : _episodePanelController.reverse();
  }

  // ── FIX: Stop playback and close properly ──────────────────────────────────
  void _stopPlaybackAndClose() {
    // Save progress before stopping
    _saveProgress();

    // Stop the native player if active
    if (_isNativeMode) {
      try { _player.stop(); } catch (_) {}
    }

    // Stop webview video if active
    if (_webController != null) {
      try {
        _webController?.evaluateJavascript(
            source: 'var v=document.querySelector("video");if(v)v.pause();');
      } catch (_) {}
    }

    // Cancel all timers
    _controlsTimer?.cancel();
    _loadingTimeout?.cancel();
    _videoDetectionTimer?.cancel();
    _progressTimer?.cancel();
    _resizeDebounce?.cancel();

    // Close mini player if active
    _miniPlayerService.close();

    // Reset system UI
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Navigate back
    if (mounted) Navigator.pop(context);
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_isNativeMode && _streamUrl != null && !_isResolving) {
        _miniPlayerService.startMiniPlayer(
          title: widget.mediaType == 'tv'
              ? '${widget.title} S${widget.season}E${widget.episode}'
              : widget.title,
          streamUrl: _streamUrl!,
          mediaType: widget.mediaType,
          season: widget.season,
          episode: widget.episode,
          tmdbId: widget.id,
          position: _player.state.position,
          duration: _player.state.duration,
        );
      } else if (!_isNativeMode && _streamUrl != null && !_isResolving) {
        _miniPlayerService.startMiniPlayer(
          title: widget.mediaType == 'tv'
              ? '${widget.title} S${widget.season}E${widget.episode}'
              : widget.title,
          streamUrl: _streamUrl!,
          mediaType: widget.mediaType,
          season: widget.season,
          episode: widget.episode,
          tmdbId: widget.id,
          position: Duration.zero,
          duration: Duration.zero,
        );
      }

      try { SimplePip().enterPipMode(); } catch (_) {}
    } else if (state == AppLifecycleState.resumed) {
      if (_miniPlayerService.isMiniPlayerActive) {
        _miniPlayerService.stopMiniPlayer();
      }
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (_isNativeMode || _webController == null) return;
    _resizeDebounce?.cancel();
    _resizeDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _webController?.evaluateJavascript(source: _layoutFixScript);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controlsTimer?.cancel();
    _loadingTimeout?.cancel();
    _videoDetectionTimer?.cancel();
    _progressTimer?.cancel();
    _resizeDebounce?.cancel();
    _controlsAnimController.dispose();
    _episodePanelController.dispose();
    _player.dispose();
    _miniPlayerService.close();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    try { ScreenBrightness().resetScreenBrightness(); } catch (_) {}
    super.dispose();
  }

  void _saveProgress() {
    if (!mounted || !_isNativeMode) return;
    final db  = Provider.of<DatabaseService>(context, listen: false);
    final pos = _player.state.position.inSeconds;
    final dur = _player.state.duration.inSeconds;
    if (dur > 0) {
      db.updateHistoryProgress(widget.id, pos, dur);
      _miniPlayerService.updatePosition(
        _player.state.position,
        _player.state.duration,
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if ((_isNativeMode || !_isNativeMode) && _streamUrl != null && !_isResolving && !_isUnavailable) {
          _miniPlayerService.startMiniPlayer(
            title: widget.mediaType == 'tv'
                ? '${widget.title} S${widget.season}E${widget.episode}'
                : widget.title,
            streamUrl: _streamUrl!,
            mediaType: widget.mediaType,
            season: widget.season,
            episode: widget.episode,
            tmdbId: widget.id,
            position: _isNativeMode ? _player.state.position : Duration.zero,
            duration: _isNativeMode ? _player.state.duration : Duration.zero,
          );
        }

        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [

          SizedBox.expand(child: _buildVideoArea()),

          if (_isNativeMode && !_isResolving && !_isUnavailable)
            _buildGestureLayer(),

          if (_isResolving) _buildResolvingOverlay(),

          if (_isUnavailable) _buildUnavailableOverlay(),

          if (!_isLocked && !_isResolving && !_isUnavailable)
            Positioned.fill(
              child: FadeTransition(
                opacity: _controlsFade,
                child: SizedBox.expand(
                    child: Stack(children: [_buildControlsOverlay()])),
              ),
            ),

          if (_isLocked) _buildLockIndicator(),

          if (_showBrightnessOverlay)
            Positioned(
              left: 40, top: 0, bottom: 0,
              child: Center(
                  child: _buildSliderIndicator(
                      Icons.brightness_6, _brightness, Colors.yellowAccent)),
            ),
          if (_showVolumeOverlay)
            Positioned(
              right: 40, top: 0, bottom: 0,
              child: Center(
                  child: _buildSliderIndicator(
                      Icons.volume_up, _volume, Colors.white)),
            ),

          if (widget.mediaType == 'tv')
            SlideTransition(
              position: _episodePanelSlide,
              child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildEpisodePanel()),
            ),

          if (!_isNativeMode && !_isResolving && !_isUnavailable &&
              !_isControlsVisible)
            Positioned(
              top: 44, left: 16,
              child: _floatingPill(
                onTap: _toggleControls,
                color: Colors.black.withOpacity(0.72),
                borderColor: Colors.white24,
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.menu_rounded, color: Colors.white, size: 15),
                  SizedBox(width: 6),
                  Text('Menu',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  // ── Video area ─────────────────────────────────────────────────────────────
  Widget _buildVideoArea() {
    if (_isResolving || _isUnavailable) {
      return const ColoredBox(color: Colors.black);
    }

    if (_isNativeMode && _streamUrl != null) {
      return Video(controller: _videoController);
    }

    return SizedBox.expand(
      child: Stack(fit: StackFit.expand, children: [
        InAppWebView(
          key: _webViewKey,
          initialUrlRequest:
          URLRequest(url: WebUri(_mirrorUrl(_webMirrorIndex))),
          initialSettings: InAppWebViewSettings(
            mediaPlaybackRequiresUserGesture: false,
            javaScriptEnabled: true,
            transparentBackground: true,
            disableContextMenu: true,
            supportZoom: false,
            userAgent: 'Mozilla/5.0 (Linux; Android 12; Pixel 6) '
                'AppleWebKit/537.36 (KHTML, like Gecko) '
                'Chrome/115.0.0.0 Mobile Safari/537.36',
            useHybridComposition: true,
            hardwareAcceleration: true,
            useWideViewPort: true,
            loadWithOverviewMode: true,
            contentBlockers: _buildContentBlockers(),
          ),
          onWebViewCreated: (ctrl) {
            _webController = ctrl;

            ctrl.addJavaScriptHandler(
              handlerName: 'onVideoPlaying',
              callback: (_) {
                _onVideoPlayingDetected();
              },
            );

            ctrl.addJavaScriptHandler(
              handlerName: 'onVideoDetectionFailed',
              callback: (_) {
                if (!mounted || _videoPlayingDetected || _autoSwitchTriggered) return;
                _switchToNextMirror();
              },
            );

            ctrl.addJavaScriptHandler(
              handlerName: 'onTap',
              callback: (_) {
                if (mounted && !_isControlsVisible) _toggleControls();
              },
            );
          },
          onCreateWindow: (_, __) async => false,
          onLoadStart: (_, __) {
            if (mounted) setState(() => _webLoading = true);
          },
          onLoadStop: (ctrl, _) async {
            if (mounted) {
              setState(() {
                _webLoading = false;
                _mirrorHealth[_webMirrorIndex] = true;
              });
            }

            await ctrl.evaluateJavascript(source: _layoutFixScript);
            await ctrl.evaluateJavascript(source: _adKillerScript);
            await ctrl.evaluateJavascript(
                source: _videoPlaybackWatcherScript);
            await Future.delayed(const Duration(milliseconds: 800));

            if (mounted) {
              await ctrl.evaluateJavascript(source: _layoutFixScript);
              if (!_videoPlayingDetected) {
                _checkVideoStatusAfterLoad(ctrl);
              }
            }
          },
          onReceivedError: (_, __, ___) {
            if (!mounted || _videoPlayingDetected) return;
            setState(() {
              _webLoading                    = false;
              _mirrorHealth[_webMirrorIndex] = false;
            });
            if (!_autoSwitchTriggered) {
              _switchToNextMirror();
            }
          },
          onReceivedHttpError: (_, __, response) {
            if (!mounted || _videoPlayingDetected) return;
            if ((response.statusCode ?? 0) >= 400) {
              setState(() {
                _webLoading                    = false;
                _mirrorHealth[_webMirrorIndex] = false;
              });
              if (!_autoSwitchTriggered) {
                _switchToNextMirror();
              }
            }
          },
          shouldOverrideUrlLoading: (ctrl, action) async {
            final url     = action.request.url?.toString() ?? '';
            final navHost = Uri.tryParse(url)?.host ?? '';

            if (action.isForMainFrame == true) {
              final currentHost =
                  Uri.tryParse(_mirrorUrl(_webMirrorIndex))?.host ?? '';
              if (navHost == currentHost ||
                  navHost.endsWith('.$currentHost')) {
                return NavigationActionPolicy.ALLOW;
              }

              const safeHosts = [
                'vidlink.pro', 'vidsrc.fyi', 'vidsrc.to', 'vidsrc.cc',
                'vidsrc-embed.ru', 'vidsrc.me', 'embed.su', 'autoembed.co',
                'smashystream.com', '2embed.cc', 'multiembed.mov',
                'vidfast.pro', 'jwplatform.com', 'jwpcdn.com',
                'filemoon.sx', 'streamtape.com', 'doodstream.com',
                'mixdrop.co', 'upstream.to', 'fembed.com',
              ];
              if (safeHosts
                  .any((h) => navHost == h || navHost.endsWith('.$h'))) {
                return NavigationActionPolicy.ALLOW;
              }

              return NavigationActionPolicy.CANCEL;
            }

            return NavigationActionPolicy.ALLOW;
          },
        ),

        if (_webLoading) _buildWebLoadingOverlay(),
      ]),
    );
  }

  void _checkVideoStatusAfterLoad(InAppWebViewController ctrl) {
    ctrl.evaluateJavascript(source: r'''
      (function() {
        var videos = document.querySelectorAll('video');
        for (var i = 0; i < videos.length; i++) {
          var v = videos[i];
          if (!v.paused && !v.ended && v.readyState > 0 && v.currentTime > 0) {
            return 'playing';
          }
          if (v.readyState > 0) {
            return 'loaded';
          }
        }
        // Check for iframes
        if (document.querySelectorAll('iframe').length > 0) return 'hasIframe';
        return 'none';
      })();
    ''').then((status) {
      if (!mounted || _videoPlayingDetected) return;

      if (status == 'playing' || status == 'hasIframe') {
        _onVideoPlayingDetected();
      }
    });
  }

  List<ContentBlocker> _buildContentBlockers() {
    return StreamResolverService.adBlockDomains.map((domain) => ContentBlocker(
      trigger: ContentBlockerTrigger(
        urlFilter: '.*',
        ifDomain: [domain],
      ),
      action: ContentBlockerAction(
        type: ContentBlockerActionType.BLOCK,
      ),
    )).toList();
  }

  // ── Resolving overlay ──────────────────────────────────────────────────────
  Widget _buildResolvingOverlay() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 56, height: 56,
            child: CircularProgressIndicator(
                color: AppTheme.accent, strokeWidth: 2.5),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _resolvingStatus,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Finding the best available source…',
            style: TextStyle(color: Colors.white30, fontSize: 11),
          ),
        ]),
      ),
    );
  }

  // ── Unavailable overlay ────────────────────────────────────────────────────
  Widget _buildUnavailableOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.96),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withOpacity(0.12),
                border: Border.all(
                    color: Colors.redAccent.withOpacity(0.5), width: 2),
              ),
              child: const Icon(Icons.movie_filter_outlined,
                  color: Colors.redAccent, size: 36),
            ),
            const SizedBox(height: 20),
            const Text('Not Available',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
              'This title couldn\'t be found on any source.\nTry a mirror directly:',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white54, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8, runSpacing: 8,
              alignment: WrapAlignment.center,
              children: List.generate(_mirrors.length, (i) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _isUnavailable  = false;
                      _isNativeMode   = false;
                      _webMirrorIndex = i;
                      _streamUrl      = _mirrorUrl(i);
                      _webLoading     = true;
                      _videoPlayingDetected = false;
                      _webViewKey     = UniqueKey();
                    });
                    _startWebLoadingTimeout();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(_mirrors[i]['name']!,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _resolveAndPlay,
              icon: const Icon(Icons.refresh_rounded, color: Colors.black),
              label: const Text('Try Again',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _stopPlaybackAndClose, // FIXED: Use stop method
              icon: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white70),
              label: const Text('Go Back',
                  style: TextStyle(color: Colors.white70)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Web loading overlay ────────────────────────────────────────────────────
  Widget _buildWebLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.92),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 52, height: 52,
            child: CircularProgressIndicator(
                color: AppTheme.accent, strokeWidth: 2.5),
          ),
          const SizedBox(height: 18),
          Text(
            'Loading ${_mirrors.isNotEmpty ? _mirrors[_webMirrorIndex]["name"] : ""}…',
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text('Mirror ${_webMirrorIndex + 1} of ${_mirrors.length}',
              style: const TextStyle(color: Colors.white30, fontSize: 11)),
          const SizedBox(height: 24),
          if (_mirrors.isNotEmpty)
            SizedBox(
              height: 34,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _mirrors.length,
                itemBuilder: (_, i) {
                  final sel = i == _webMirrorIndex;
                  return GestureDetector(
                    onTap: () => _switchMirror(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppTheme.accent
                            : Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: sel ? AppTheme.accent : Colors.white12),
                      ),
                      child: Text(_mirrors[i]['name']!,
                          style: TextStyle(
                            color: sel ? Colors.black : Colors.white60,
                            fontSize: 11,
                            fontWeight:
                            sel ? FontWeight.bold : FontWeight.normal,
                          )),
                    ),
                  );
                },
              ),
            ),
        ]),
      ),
    );
  }

  // ── Gesture layer (native) ─────────────────────────────────────────────────
  Widget _buildGestureLayer() {
    return Row(children: [
      Expanded(
        child: Listener(
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
        ),
      ),
      Expanded(
        child: Listener(
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
        ),
      ),
    ]);
  }

  // ── Controls overlay ───────────────────────────────────────────────────────
  Widget _buildControlsOverlay() {
    final title = widget.mediaType == 'tv'
        ? '${widget.title}  •  S$_currentSeason E$_currentEpisode'
        : widget.title;

    if (!_isNativeMode) {
      return Positioned(
        top: 0, left: 0, right: 0,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xEE000000), Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                    onPressed: _stopPlaybackAndClose, // FIXED: Use stop method
                  ),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    icon: const Icon(Icons.screen_rotation_rounded,
                        color: Colors.white70, size: 20),
                    onPressed: _toggleOrientation,
                  ),
                  if (widget.mediaType == 'tv')
                    IconButton(
                      icon: const Icon(Icons.list_rounded,
                          color: Colors.white70, size: 20),
                      onPressed: _toggleEpisodePanel,
                    ),
                ]),
              ),
              if (_mirrors.isNotEmpty)
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(
                        left: 14, right: 14, bottom: 8),
                    itemCount: _mirrors.length,
                    itemBuilder: (_, i) => _buildMirrorPill(i),
                  ),
                ),
            ]),
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: Stack(children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xCC000000),
                Colors.transparent,
                Color(0xCC000000),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),
        SafeArea(
          child: Stack(children: [

            Positioned(
              top: 0, left: 0, right: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                    onPressed: _stopPlaybackAndClose, // FIXED: Use stop method
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                        if (_streamSource != null)
                          Text('via $_streamSource',
                              style: TextStyle(
                                  color: AppTheme.accent.withOpacity(0.8),
                                  fontSize: 10)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppTheme.accent.withOpacity(0.55)),
                    ),
                    child: Text('🎬 Native',
                        style: TextStyle(
                            color: AppTheme.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.lock_open_rounded,
                        color: Colors.white70, size: 20),
                    onPressed: () {
                      setState(() => _isLocked = true);
                      _controlsTimer?.cancel();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.screen_rotation_rounded,
                        color: Colors.white70, size: 20),
                    onPressed: _toggleOrientation,
                  ),
                  IconButton(
                    icon: const Icon(Icons.picture_in_picture_alt,
                        color: Colors.white70, size: 20),
                    onPressed: () async {
                      try {
                        await SimplePip().enterPipMode();
                      } catch (_) {
                        if (mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                            content: Text(
                                'PiP not supported on this device'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      }
                    },
                  ),
                ]),
              ),
            ),

            Center(
              child: GestureDetector(
                onTap: _togglePlayPause,
                child: StreamBuilder<bool>(
                  stream: _player.stream.playing,
                  initialData: false,
                  builder: (_, snap) {
                    final playing = snap.data ?? false;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppTheme.accent.withOpacity(0.6),
                            width: 2),
                      ),
                      child: Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 36),
                    );
                  },
                ),
              ),
            ),

            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _circleButton(Icons.replay_10_rounded,
                              () => _seekRelative(-10)),
                      if (widget.mediaType == 'tv') ...[
                        const SizedBox(width: 16),
                        _episodesButton(),
                        const SizedBox(width: 16),
                      ] else
                        const SizedBox(width: 32),
                      _circleButton(Icons.forward_10_rounded,
                              () => _seekRelative(10)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<Duration>(
                    stream: _player.stream.position,
                    builder: (_, snapshot) {
                      final pos = snapshot.data ?? Duration.zero;
                      final dur = _player.state.duration;
                      final progress = dur.inMilliseconds > 0
                          ? (pos.inMilliseconds / dur.inMilliseconds)
                          .clamp(0.0, 1.0)
                          : 0.0;
                      return Column(children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12),
                            activeTrackColor: AppTheme.accent,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: progress,
                            onChanged: (v) {
                              _player.seek(Duration(
                                  milliseconds:
                                  (v * dur.inMilliseconds).round()));
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16),
                          child: Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_fmt(pos),
                                  style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11)),
                              Text(_fmt(dur),
                                  style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                      ]);
                    },
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Mirror pill ────────────────────────────────────────────────────────────
  Widget _buildMirrorPill(int i) {
    final sel    = i == _webMirrorIndex;
    final health = _mirrorHealth[i];
    final dot = health == null
        ? Colors.white38
        : health
        ? Colors.greenAccent
        : Colors.redAccent;

    return GestureDetector(
      onTap: () => _switchMirror(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? AppTheme.accent : Colors.black.withOpacity(0.65),
          borderRadius: BorderRadius.circular(20),
          border:
          Border.all(color: sel ? AppTheme.accent : Colors.white24),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 6, height: 6,
              decoration:
              BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(_mirrors[i]['name']!,
              style: TextStyle(
                color: sel ? Colors.black : Colors.white,
                fontSize: 11,
                fontWeight: sel ? FontWeight.bold : FontWeight.w500,
              )),
        ]),
      ),
    );
  }

  Widget _episodesButton() {
    return GestureDetector(
      onTap: _toggleEpisodePanel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: const Row(children: [
          Icon(Icons.video_library_rounded,
              color: Colors.white, size: 17),
          SizedBox(width: 6),
          Text('Episodes',
              style: TextStyle(color: Colors.white, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _floatingPill({
    required VoidCallback onTap,
    required Color color,
    required Color borderColor,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50, height: 50,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildSliderIndicator(
      IconData icon, double value, Color color) {
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.72),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 10),
        RotatedBox(
          quarterTurns: -1,
          child: LinearProgressIndicator(
            value: value,
            color: color,
            backgroundColor: Colors.white24,
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 6),
        Text('${(value * 100).round()}%',
            style: TextStyle(color: color, fontSize: 10)),
      ]),
    );
  }

  Widget _buildLockIndicator() {
    return Positioned(
      top: 20, left: 20,
      child: GestureDetector(
        onTap: () => setState(() => _isLocked = false),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: AppTheme.accent.withOpacity(0.5)),
          ),
          child: Row(children: [
            Icon(Icons.lock_rounded,
                color: AppTheme.accent, size: 15),
            const SizedBox(width: 7),
            const Text('Tap to unlock',
                style:
                TextStyle(color: Colors.white, fontSize: 12)),
          ]),
        ),
      ),
    );
  }

  // ── Episode panel ──────────────────────────────────────────────────────────
  Widget _buildEpisodePanel() {
    return Container(
      height: 260, width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xF00D0D1A),
        borderRadius:
        const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 20,
              offset: const Offset(0, -4))
        ],
      ),
      child: Column(children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          width: 36, height: 4,
          decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2)),
        ),
        if (widget.seasons.length > 1)
          SizedBox(
            height: 42,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: widget.seasons.length,
              itemBuilder: (_, i) {
                final sn =
                    (widget.seasons[i]['season_number'] as int?) ?? i + 1;
                final sel = sn == _currentSeason;
                return GestureDetector(
                  onTap: () => _switchSeason(sn),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppTheme.accent : Colors.white10,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text('Season $sn',
                        style: TextStyle(
                          color: sel ? Colors.black : Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 10),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            scrollDirection: Axis.horizontal,
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8, crossAxisSpacing: 8,
              childAspectRatio: 0.55,
            ),
            itemCount: _episodeCount,
            itemBuilder: (_, i) {
              final ep  = i + 1;
              final sel = ep == _currentEpisode;
              return GestureDetector(
                onTap: () => _switchEpisode(ep),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: sel ? AppTheme.accent : Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: sel ? AppTheme.accent : Colors.white12),
                  ),
                  child: Center(
                    child: Text('E$ep',
                        style: TextStyle(
                          color: sel ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        )),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  void _toggleOrientation() {
    if (MediaQuery.of(context).orientation == Orientation.portrait) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations(
          [DeviceOrientation.portraitUp]);
    }
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    });
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}