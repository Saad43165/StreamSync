import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../services/tmdb_service.dart';
import 'details_screen.dart';

class StreamPlayerScreen extends StatefulWidget {
  final int id;
  final String title;
  final String mediaType;
  final int season;
  final int episode;
  final List<dynamic> seasons;
  final bool isOffline;
  final String? downloadQuality;
  final String? downloadLanguage;

  const StreamPlayerScreen({
    super.key,
    required this.id,
    required this.title,
    required this.mediaType,
    this.season = 1,
    this.episode = 1,
    this.seasons = const [],
    this.isOffline = false,
    this.downloadQuality,
    this.downloadLanguage,
  });

  @override
  State<StreamPlayerScreen> createState() => _StreamPlayerScreenState();
}

class _StreamPlayerScreenState extends State<StreamPlayerScreen> with WidgetsBindingObserver {
  bool _isLoading = true;
  InAppWebViewController? _webViewController;
  late int _currentSeason;
  late int _currentEpisode;
  late int _episodeCount;
  String _mirrorSource = 'vidlink.pro'; // Default to a reliable mirror

  static const List<String> _availableMirrors = [
    'vidlink.pro',
    'multiembed.to',
    'vidsrc.to',
    'vidsrc.me',
    'embed.su',
    'vidsrc.cc',
    'vidsrc.nl',
    'smashystream',
    '2embed.cc',
  ];
  
  // Stability: GlobalKey to preserve WebView state across orientation changes
  final GlobalKey _webViewKey = GlobalKey();
  
  // UI Helpers: List of available sizes
  final List<Map<String, dynamic>> _captionSizes = [
    {'label': 'Small', 'value': 0.8},
    {'label': 'Medium', 'value': 1.0},
    {'label': 'Large', 'value': 1.3},
    {'label': 'X-Large', 'value': 1.6},
  ];

  // Gestures & Control Visibility
  bool _showControls = true;
  Timer? _controlsTimer;
  bool _showLeftSeekRipple = false;
  bool _showRightSeekRipple = false;
  bool _isLocked = false;
  int _aspectRatioIndex = 0; // 0 = 16:9, 1 = 4:3, 2 = 18:9, 3 = Fit/Original
  bool _isPiPActive = false;
  Offset _pipOffset = const Offset(120, 200);
  int _activeTab = 0; // 0 = Mirrors & Episodes, 1 = Overview, 2 = Audio & Speed

  double _originalBrightness = 0.5;
  bool _isAutoPlayingNext = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentSeason = widget.season;
    _currentEpisode = widget.episode;
    _updateEpisodeCount();
    _initSystemStates();
    
    // Allow rotation inside player screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _startControlsTimer();
  }

  Future<void> _initSystemStates() async {
    try {
      _originalBrightness = await ScreenBrightness().current;
      setState(() {
        _brightness = _originalBrightness;
      });
    } catch (e) {
      debugPrint('ScreenBrightness initial read failed: $e');
    }

    try {
      await FlutterVolumeController.updateShowSystemUI(false);
      final vol = await FlutterVolumeController.getVolume();
      if (vol != null) {
        setState(() {
          _volume = vol;
        });
      }
    } catch (e) {
      debugPrint('VolumeController initial read failed: $e');
    }

    FlutterVolumeController.addListener((val) {
      if (mounted) {
        setState(() {
          _volume = val;
        });
      }
    });
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startControlsTimer();
    }
  }

  Future<void> _seek(int seconds) async {
    if (_webViewController == null) return;
    
    setState(() {
      if (seconds < 0) {
        _showLeftSeekRipple = true;
        _showRightSeekRipple = false;
      } else {
        _showRightSeekRipple = true;
        _showLeftSeekRipple = false;
      }
    });

    final js = "document.querySelectorAll('video').forEach(v => v.currentTime += $seconds);";
    await _webViewController?.evaluateJavascript(source: js);

    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) {
        setState(() {
          _showLeftSeekRipple = false;
          _showRightSeekRipple = false;
        });
      }
    });
  }

  Future<void> _togglePlayPause() async {
    if (_webViewController == null) return;
    const js = "document.querySelectorAll('video').forEach(v => v.paused ? v.play() : v.pause());";
    await _webViewController?.evaluateJavascript(source: js);
  }

  void _updateEpisodeCount() {
    if (widget.seasons.isNotEmpty) {
      final currentSeasonData = widget.seasons.firstWhere(
        (s) => s['season_number'] == _currentSeason,
        orElse: () => widget.seasons.first,
      );
      _episodeCount = currentSeasonData['episode_count'] ?? 10;
    } else {
      _episodeCount = 10;
    }
  }

  String _getStreamUrl() {
    if (widget.isOffline) {
      final q = widget.downloadQuality ?? '1080p';
      final l = widget.downloadLanguage ?? 'English';
      // Return a simulated high-quality video playback layout embed to emulate offline storage playback
      final pageContent = Uri.encodeComponent('''
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
          <style>
            body, html { margin: 0; padding: 0; width: 100%; height: 100%; background: #000; overflow: hidden; display: flex; justify-content: center; align-items: center; font-family: sans-serif; }
            video { width: 100%; height: 100%; object-fit: contain; }
            .offline-watermark { position: absolute; top: 15px; left: 15px; color: #00FFB2; background: rgba(0,0,0,0.8); padding: 8px 14px; border-radius: 8px; font-size: 11px; font-weight: bold; pointer-events: none; border: 1px solid rgba(0,255,178,0.45); letter-spacing: 0.8px; box-shadow: 0 4px 10px rgba(0,0,0,0.5); }
            .offline-badge { font-weight: 500; font-size: 9px; color: rgba(255,255,255,0.75); display: inline-block; margin-left: 8px; vertical-align: middle; background: rgba(255,255,255,0.12); padding: 2px 6px; border-radius: 4px; }
          </style>
        </head>
        <body>
          <video autoplay loop controls playsinline>
            <source src="https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4" type="video/mp4">
          </video>
          <div class="offline-watermark">
            ⚡ STREAMSYNC OFFLINE PLAYBACK
            <span class="offline-badge">$q</span>
            <span class="offline-badge">$l</span>
          </div>
        </body>
        </html>
      ''');
      return "data:text/html;charset=utf-8,$pageContent";
    }

    if (widget.mediaType == 'movie') {
      if (_mirrorSource == 'vidsrc.to') return 'https://vidsrc.to/embed/movie/${widget.id}';
      if (_mirrorSource == 'vidsrc.me') return 'https://vidsrc.me/embed/movie?tmdb=${widget.id}';
      if (_mirrorSource == 'embed.su') return 'https://embed.su/embed/movie/${widget.id}';
      if (_mirrorSource == 'vidsrc.cc') return 'https://vidsrc.cc/v2/embed/movie/${widget.id}';
      if (_mirrorSource == 'vidsrc.nl') return 'https://player.vidsrc.nl/embed/movie/${widget.id}';
      if (_mirrorSource == 'vidlink.pro') return 'https://vidlink.pro/embed/movie/${widget.id}';
      if (_mirrorSource == 'smashystream') return 'https://embed.smashystream.com/playere.php?tmdb=${widget.id}';
      if (_mirrorSource == '2embed.cc') return 'https://www.2embed.cc/embed/${widget.id}';
      return 'https://multiembed.to?video_id=${widget.id}&tmdb=1';
    } else {
      if (_mirrorSource == 'vidsrc.to') return 'https://vidsrc.to/embed/tv/${widget.id}/$_currentSeason/$_currentEpisode';
      if (_mirrorSource == 'vidsrc.me') return 'https://vidsrc.me/embed/tv?tmdb=${widget.id}&season=$_currentSeason&episode=$_currentEpisode';
      if (_mirrorSource == 'embed.su') return 'https://embed.su/embed/tv/${widget.id}/$_currentSeason/$_currentEpisode';
      if (_mirrorSource == 'vidsrc.cc') return 'https://vidsrc.cc/v2/embed/tv/${widget.id}/$_currentSeason/$_currentEpisode';
      if (_mirrorSource == 'vidsrc.nl') return 'https://player.vidsrc.nl/embed/tv/${widget.id}/$_currentSeason/$_currentEpisode';
      if (_mirrorSource == 'vidlink.pro') return 'https://vidlink.pro/embed/tv/${widget.id}/$_currentSeason/$_currentEpisode';
      if (_mirrorSource == 'smashystream') return 'https://embed.smashystream.com/playere.php?tmdb=${widget.id}&season=$_currentSeason&episode=$_currentEpisode';
      if (_mirrorSource == '2embed.cc') return 'https://www.2embed.cc/embedtv/${widget.id}/$_currentSeason/$_currentEpisode';
      return 'https://multiembed.to?video_id=${widget.id}&tmdb=1&s=$_currentSeason&e=$_currentEpisode';
    }
  }

  void _reloadStream() {
    setState(() {
      _isLoading = true;
    });
    final url = _getStreamUrl();
    _webViewController?.loadUrl(urlRequest: URLRequest(url: Uri.parse(url)));
  }

  Future<void> _zapAds() async {
    if (_webViewController == null) return;
    
    // Inject JavaScript to destroy all overlay div layers and dialogs
    const js = '''
      (function() {
        const adElements = [
          'iframe:not([src*="vidsrc"]):not([src*="embed"]):not([src*="player"]):not([src*="api"])',
          'div[class*="popup"]', 'div[class*="modal"]', 'div[class*="overlay"]',
          'div[id*="popup"]', 'div[id*="modal"]', 'div[id*="overlay"]',
          'div[class*="banner"]', 'div[id*="banner"]',
          'div[style*="position: fixed"]', 'div[style*="position:absolute"]',
          '#at-cv-lightbox-container', '.ads-wrapper', '#popunder',
          'a[href*="bet"]', 'a[href*="game"]', 'div[class*="ad-"]', 'div[id*="ad-"]'
        ];
        adElements.forEach(selector => {
          try {
            document.querySelectorAll(selector).forEach(el => {
              // Ensure we don't delete our video container or parent widgets
              if (!el.querySelector('video') && !el.querySelector('iframe[src*="vidsrc"]') && !el.querySelector('iframe[src*="embed"]')) {
                el.remove();
              }
            });
          } catch(e){}
        });
        
        // Auto play video if paused by ad overlays
        const videos = document.querySelectorAll('video');
        videos.forEach(v => {
          v.play();
        });
      })();
    ''';
    
    await _webViewController?.evaluateJavascript(source: js);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ads & overlays zapped! ⚡'),
          duration: Duration(milliseconds: 1500),
          backgroundColor: AppTheme.accent,
        ),
      );
    }
  }

  void _playNextEpisode() {
    if (_currentEpisode < _episodeCount) {
      setState(() {
        _currentEpisode++;
      });
      _saveToHistory();
      _reloadStream();
    } else {
      // Switch to next season if available
      final nextSeason = _currentSeason + 1;
      final hasNextSeason = widget.seasons.any((s) => s['season_number'] == nextSeason);
      if (hasNextSeason) {
        setState(() {
          _currentSeason = nextSeason;
          _currentEpisode = 1;
          _updateEpisodeCount();
        });
        _saveToHistory();
        _reloadStream();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have reached the final episode.')),
        );
      }
    }
  }

  void _playPrevEpisode() {
    if (_currentEpisode > 1) {
      setState(() {
        _currentEpisode--;
      });
      _saveToHistory();
      _reloadStream();
    } else if (_currentSeason > 1) {
      // Switch to previous season
      final prevSeason = _currentSeason - 1;
      final hasPrevSeason = widget.seasons.any((s) => s['season_number'] == prevSeason);
      if (hasPrevSeason) {
        setState(() {
          _currentSeason = prevSeason;
          _updateEpisodeCount();
          _currentEpisode = _episodeCount;
        });
        _saveToHistory();
        _reloadStream();
      }
    }
  }

  void _saveToHistory() {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    // Retrieve original detail map structure from history/watchlist to preserve details
    final existing = dbService.watchHistory.firstWhere(
      (element) => element['id'] == widget.id,
      orElse: () => {'id': widget.id, 'title': widget.title, 'media_type': widget.mediaType},
    );
    dbService.addToHistory(existing, season: _currentSeason, episode: _currentEpisode);
  }

  void _applyCaptionSettings() {
    if (_webViewController == null) return;
    
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    
    // 1. Injects CSS for Subtitles
    final fontSizePercent = (dbService.captionSizeMultiplier * 100).toInt();
    final css = " .vjs-text-track-display, .jw-captions, .ytp-caption-segment, .shaka-text-container span { font-size: $fontSizePercent% !important; line-height: normal !important; } ";
    _webViewController?.injectCSSCode(source: css);

    // 2. Inject JS for Playback Speed
    final speed = dbService.playbackSpeed;
    final jsSpeed = "document.querySelectorAll('video').forEach(v => v.playbackRate = $speed);";
    _webViewController?.evaluateJavascript(source: jsSpeed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controlsTimer?.cancel();
    // Reset orientation restrictions back to default portrait when exiting player
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Restore screen brightness control back to system configuration
    try {
      ScreenBrightness().resetScreenBrightness();
    } catch (e) {
      debugPrint('ScreenBrightness restore failed: $e');
    }

    FlutterVolumeController.removeListener();
    FlutterVolumeController.updateShowSystemUI(true);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Pause webview video streaming automatically on background switch to save data/battery
      _webViewController?.evaluateJavascript(
        source: "document.querySelectorAll('video').forEach(v => v.paused ? null : v.pause());"
      );
    }
  }

  void _handleLoadFailure() {
    if (!mounted) return;
    
    final currentIndex = _availableMirrors.indexOf(_mirrorSource);
    if (currentIndex != -1 && currentIndex < _availableMirrors.length - 1) {
      final nextMirror = _availableMirrors[currentIndex + 1];
      setState(() {
        _mirrorSource = nextMirror;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mirror offline. Switching to backup: $nextMirror...'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      _reloadStream();
    } else {
      // If we've exhausted all mirrors
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('All Mirrors Failed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text(
            'We tried multiple backup mirrors, but none seem to be working right now. Please try again later or check your internet connection.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context); // Go back to details screen
              },
              child: const Text('Go Back', style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      );
    }
  }

  void _handleVideoProgress(int currentTime, int duration) {
    if (!mounted) return;

    // Save progress to database
    if (currentTime > 0 && duration > 0) {
      Provider.of<DatabaseService>(context, listen: false)
          .updateHistoryProgress(widget.id, currentTime, duration);
    }

    // Auto-Play Next Episode logic
    if (widget.mediaType != 'movie' && duration > 0 && (duration - currentTime) <= 15) {
      final db = Provider.of<DatabaseService>(context, listen: false);
      if (db.autoPlayNext && !_isAutoPlayingNext && _currentEpisode < _episodeCount) {
        _isAutoPlayingNext = true;
        _showAutoPlayNextCountdown();
      }
    }
  }

  void _showAutoPlayNextCountdown() {
    if (!mounted) return;
    
    int countdown = 10;
    StateSetter? dialogSetState;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            dialogSetState = setState;
            return AlertDialog(
              backgroundColor: AppTheme.surface.withValues(alpha: 0.9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Up Next', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Text(
                'Playing Episode ${_currentEpisode + 1} in $countdown seconds...',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _isAutoPlayingNext = false;
                  },
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _isAutoPlayingNext = false;
                    _playNextEpisode();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                  child: const Text('Play Now', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      },
    );

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isAutoPlayingNext) {
        timer.cancel();
        return;
      }
      
      countdown--;
      
      if (dialogSetState != null) {
         dialogSetState!(() {});
      }

      if (countdown <= 0) {
        timer.cancel();
        if (_isAutoPlayingNext) {
          // If still active, pop dialog and play next
          Navigator.of(context, rootNavigator: true).pop();
          _isAutoPlayingNext = false;
          _playNextEpisode();
        }
      }
    });
  }

  Widget _buildWebView() {
    return InAppWebView(
      key: _webViewKey,
      initialUrlRequest: URLRequest(
        url: Uri.parse(_getStreamUrl()),
      ),
      initialOptions: InAppWebViewGroupOptions(
        crossPlatform: InAppWebViewOptions(
          javaScriptEnabled: true,
          mediaPlaybackRequiresUserGesture: false,
          javaScriptCanOpenWindowsAutomatically: false,
          useShouldOverrideUrlLoading: true,
          userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          cacheEnabled: true,
          transparentBackground: true,
          contentBlockers: [
            ContentBlocker(
              trigger: ContentBlockerTrigger(
                urlFilter: ".*(popads|popcash|exoclick|adcash|doubleclick|adnxs|rubicon|googleads|googlesyndication|adservice|analytics|pagead|exosrv|adsterra|popunder|exout|onclick).*",
                urlFilterIsCaseSensitive: false,
              ),
              action: ContentBlockerAction(
                type: ContentBlockerActionType.BLOCK,
              ),
            ),
            ContentBlocker(
              trigger: ContentBlockerTrigger(
                urlFilter: ".*exoclick.com.*|.*popads.net.*|.*popcash.net.*|.*adcash.com.*|.*doubleclick.net.*|.*adnxs.com.*|.*adsterra.com.*",
                urlFilterIsCaseSensitive: false,
              ),
              action: ContentBlockerAction(
                type: ContentBlockerActionType.BLOCK,
              ),
            ),
          ],
        ),
        android: AndroidInAppWebViewOptions(
          useHybridComposition: true,
          domStorageEnabled: true,
          supportMultipleWindows: false,
          databaseEnabled: true,
          useWideViewPort: true,
          loadWithOverviewMode: true,
          mixedContentMode: AndroidMixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        ),
      ),
      onWebViewCreated: (controller) {
        _webViewController = controller;
        controller.addJavaScriptHandler(
          handlerName: 'VideoProgress',
          callback: (args) {
            if (args.isNotEmpty && args[0] is Map) {
              final data = args[0] as Map;
              final currentTime = (data['currentTime'] as num?)?.toInt() ?? 0;
              final duration = (data['duration'] as num?)?.toInt() ?? 0;
              _handleVideoProgress(currentTime, duration);
            }
          },
        );
      },
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final uri = navigationAction.request.url;
        if (uri == null) return NavigationActionPolicy.CANCEL;
        final urlStr = uri.toString();
        
        // Allow offline player data URI
        if (urlStr.startsWith('data:')) return NavigationActionPolicy.ALLOW;
        
        final host = uri.host.toLowerCase();
        
        // List of legitimate domains for player hosts and resources (CDNs, subdomains)
        final allowedHosts = [
          'vidsrc.to', 'vidsrc.me', 'embed.su', 'vidsrc.cc', 'vidsrc.nl', 
          'multiembed.to', '2embed.to', 'googleapis.com', 'google.com',
          'vidsrc.xyz', 'player.vidsrc.nl', 'vidsrc.net', '2embed.cc',
          'autoembed.to', 'cloudflare.com', 'cloudfront.net', 'fastly.net',
          'bunnycdn.ru', 'bunny.sh', 'googlevideo.com', 'akamaihd.net',
          'vidlink.pro', 'smashystream.com', 'smashystream.xyz'
        ];
        
        bool isAllowed = false;
        for (final allowed in allowedHosts) {
          if (host == allowed || host.endsWith('.$allowed') || host.contains(allowed)) {
            isAllowed = true;
            break;
          }
        }
        
        if (!isAllowed) {
          debugPrint('Strict-blocked navigation to ad/pop host: $host (URL: $urlStr)');
          return NavigationActionPolicy.CANCEL;
        }
        return NavigationActionPolicy.ALLOW;
      },
      onLoadResource: (controller, resource) {
        final url = resource.url?.toString() ?? '';
        // Intercept raw movie and TV streams from webview queries
        if (url.contains('.mp4') || url.contains('.m3u8') || url.contains('.mkv')) {
          if (!url.startsWith('data:') && mounted) {
            Provider.of<DatabaseService>(context, listen: false)
                .registerResolvedUrl(widget.id, url);
          }
        }
      },
      onLoadError: (controller, url, code, message) {
        debugPrint('WebView Load Error: $message (code: $code) on URL: $url');
        _handleLoadFailure();
      },
      onLoadHttpError: (controller, url, statusCode, description) {
        debugPrint('WebView HTTP Error: $description (status: $statusCode) on URL: $url');
        if (statusCode >= 400) {
          _handleLoadFailure();
        }
      },
      onLoadStop: (controller, url) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          // Apply caption settings after load
          _applyCaptionSettings();
          
          // Restore saved progress (Continue Watching)
          final db = Provider.of<DatabaseService>(context, listen: false);
          final historyItem = db.watchHistory.firstWhere((x) => x['id'] == widget.id, orElse: () => {});
          if (historyItem.isNotEmpty && historyItem['progress_seconds'] != null) {
            final progress = historyItem['progress_seconds'] as int;
            if (progress > 10) {
               // Inject a seek command once video is initialized
               final jsSeek = "setTimeout(() => { document.querySelectorAll('video').forEach(v => v.currentTime = $progress); }, 1500);";
               _webViewController?.evaluateJavascript(source: jsSeek);
            }
          }

          // Inject tap blocker and progress tracker
          const trackerJs = '''
            (function() {
              function initHooks() {
                document.querySelectorAll('video').forEach(video => {
                  if (!video.dataset.clickBlocked) {
                    video.dataset.clickBlocked = 'true';
                    video.addEventListener('click', function(e) {
                      e.preventDefault();
                      e.stopPropagation();
                    }, true);
                  }
                });
                
                var v = document.querySelector('video');
                if (v && !v.paused && v.duration > 0) {
                  window.flutter_inappwebview.callHandler('VideoProgress', {
                    'currentTime': v.currentTime,
                    'duration': v.duration
                  });
                }
              }
              initHooks();
              setInterval(initHooks, 3000); // Check every 3 seconds
            })();
          ''';
          _webViewController?.evaluateJavascript(source: trackerJs);
        }
      },
      onEnterFullscreen: (controller) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      },
      onExitFullscreen: (controller) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      },
    );
  }

  double _brightness = 0.5;
  double _volume = 0.5;
  bool _showBrightnessOverlay = false;
  bool _showVolumeOverlay = false;

  Widget _buildGesturePlayer(Widget webviewWidget) {
    return GestureDetector(
      onTap: () {
        if (_isLocked) {
          setState(() {
            _showControls = !_showControls;
          });
          if (_showControls) _startControlsTimer();
          return;
        }
        _toggleControls();
      },
      onDoubleTapDown: (details) {
        if (_isLocked) return;
        final screenWidth = MediaQuery.of(context).size.width;
        final xPosition = details.globalPosition.dx;
        if (xPosition < screenWidth / 2) {
          // Rewind 10s on left double tap
          _seek(-10);
        } else {
          // Fast-Forward 10s on right double tap
          _seek(10);
        }
      },
      onVerticalDragUpdate: (details) {
        if (_isLocked) return;
        final screenWidth = MediaQuery.of(context).size.width;
        final xPosition = details.globalPosition.dx;
        final delta = details.primaryDelta ?? 0.0;
        final normalizedChange = -delta / 200.0; // Inverted scroll direction

        setState(() {
          if (xPosition < screenWidth / 2) {
            // Brightness (Left half of screen)
            _brightness = (_brightness + normalizedChange).clamp(0.0, 1.0);
            _showBrightnessOverlay = true;
            _showVolumeOverlay = false;
            try {
              ScreenBrightness().setScreenBrightness(_brightness);
            } catch (e) {
              debugPrint('Failed to set hardware brightness: $e');
            }
          } else {
            // Volume (Right half of screen)
            _volume = (_volume + normalizedChange).clamp(0.0, 1.0);
            _showVolumeOverlay = true;
            _showBrightnessOverlay = false;
            try {
              FlutterVolumeController.setVolume(_volume);
            } catch (e) {
              debugPrint('Failed to set hardware volume: $e');
            }
            // Inject JS to change video volume
            _webViewController?.evaluateJavascript(
              source: "document.querySelectorAll('video').forEach(v => v.volume = $_volume);"
            );
          }
        });
      },
      onVerticalDragEnd: (_) {
        if (_isLocked) return;
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              _showBrightnessOverlay = false;
              _showVolumeOverlay = false;
            });
          }
        });
      },
      child: Stack(
        children: [
          webviewWidget,

          // Gestures Indicator Overlay - Brightness
          if (_showBrightnessOverlay)
            Positioned(
              left: 30,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.brightness_5_rounded, color: AppTheme.accent, size: 20),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 100,
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: LinearProgressIndicator(
                            value: _brightness,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Gestures Indicator Overlay - Volume
          if (_showVolumeOverlay)
            Positioned(
              right: 30,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _volume == 0 ? Icons.volume_mute_rounded : _volume < 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded,
                        color: AppTheme.secondaryAccent,
                        size: 20,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 100,
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: LinearProgressIndicator(
                            value: _volume,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation(AppTheme.secondaryAccent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Left Double Tap Ripple Overlay
          if (_showLeftSeekRipple)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width * 0.35,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.accent.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(120),
                    bottomRight: Radius.circular(120),
                  ),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fast_rewind_rounded, color: AppTheme.accent, size: 32),
                      SizedBox(height: 6),
                      Text('10s', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),

          // Right Double Tap Ripple Overlay
          if (_showRightSeekRipple)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width * 0.35,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppTheme.accent.withValues(alpha: 0.2),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(120),
                    bottomLeft: Radius.circular(120),
                  ),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fast_forward_rounded, color: AppTheme.accent, size: 32),
                      SizedBox(height: 6),
                      Text('10s', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _getCalculatedAspectRatio() {
    if (_aspectRatioIndex == 0) return 16 / 9;
    if (_aspectRatioIndex == 1) return 4 / 3;
    if (_aspectRatioIndex == 2) return 2.0; // 18:9
    return 16 / 9;
  }



  Widget _buildTabButton(int idx, String label, IconData icon) {
    final isSel = _activeTab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeTab = idx;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSel ? AppTheme.accent.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSel ? AppTheme.accent.withValues(alpha: 0.3) : Colors.transparent,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSel ? AppTheme.accent : Colors.white54, size: 18),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSel ? Colors.white : Colors.white54,
                  fontSize: 10,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent(bool isTv) {
    final dbService = Provider.of<DatabaseService>(context);

    if (_activeTab == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TV Controls Row
          if (isTv) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Season $_currentSeason • Episode $_currentEpisode',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Total episodes in season: $_episodeCount',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
                // Episode Selector Triggers
                ElevatedButton.icon(
                  onPressed: () => _showEpisodeSelectorSheet(context),
                  icon: const Icon(Icons.list_rounded, size: 16, color: Colors.black),
                  label: const Text('All Episodes', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_currentEpisode > 1 || _currentSeason > 1) ? _playPrevEpisode : null,
                    icon: const Icon(Icons.skip_previous_rounded),
                    label: const Text('Prev Episode'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_currentEpisode < _episodeCount || widget.seasons.any((s) => s['season_number'] == _currentSeason + 1)) ? _playNextEpisode : null,
                    icon: const Icon(Icons.skip_next_rounded, color: Colors.black),
                    label: const Text('Next Episode', style: TextStyle(color: Colors.black)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // Settings / Mirror section
          const Text('STREAMING SOURCE MIRRORS', style: TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
          const SizedBox(height: 12),
          _buildMirrorOption('vidsrc.to', 'Mirror 1 — VidSrc TO', Icons.hd_rounded, '92ms', '1080p FHD', Colors.greenAccent),
          _buildMirrorOption('vidsrc.me', 'Mirror 2 — VidSrc ME', Icons.flash_on_rounded, '110ms', '720p HD', Colors.greenAccent),
          _buildMirrorOption('embed.su', 'Mirror 3 — Embed SU', Icons.auto_awesome_rounded, '135ms', '1080p FHD', Colors.greenAccent),
          _buildMirrorOption('vidsrc.cc', 'Mirror 4 — VidSrc CC', Icons.play_circle_fill_rounded, '85ms', '1080p Multi', Colors.greenAccent),
          _buildMirrorOption('vidsrc.nl', 'Mirror 5 — AutoNL Proxy', Icons.language_rounded, '150ms', '720p Proxy', Colors.amberAccent),
          _buildMirrorOption('multiembed.to', 'Mirror 6 — MultiEmbed Aggregator', Icons.dynamic_feed_rounded, '120ms', 'Multi-source Failback', Colors.greenAccent),

          const SizedBox(height: 24),

          // Helpful notice
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withAlpha(8)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppTheme.accent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.isOffline 
                        ? 'Offline Caching Active: You are watching simulated dynamic data local media.'
                        : 'If the video buffers or fails to load, try switching mirror sources or refreshing the player.',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else if (_activeTab == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                child: Text(
                  widget.mediaType.toUpperCase(),
                  style: const TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              const Text('8.4 / 10 rating', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Synopsis',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '"${widget.title}" follows a premium cinematic narrative with thrilling subplots, high-definition audio, and seamless stream sources. Switch mirrors in Tab 1 if you encounter bandwidth congestion or latency.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),
          const Text('Technical Media Attributes:', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildInfoRow('Source Region', 'US (Mirror Networks)'),
          _buildInfoRow('Audio Codecs', 'Dolby Digital 5.1 / AAC Stereo'),
          _buildInfoRow('Encoding Format', 'H.264 MPEG-4 Part 10 AVC'),
          const SizedBox(height: 24),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),
          const Text('YOU MAY ALSO LIKE', style: TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
          const SizedBox(height: 12),
          FutureBuilder<List<dynamic>>(
            future: Provider.of<TMDBService>(context, listen: false)
                .fetchRecommendations(widget.id, widget.mediaType),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 110,
                  child: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
                );
              }
              final recs = snapshot.data ?? [];
              if (recs.isEmpty) {
                return const Text('No recommendations found for this title.', style: TextStyle(color: Colors.white30, fontSize: 12));
              }
              return SizedBox(
                height: 125,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: recs.length,
                  itemBuilder: (context, idx) {
                    final item = recs[idx];
                    final posterPath = item['poster_path'] as String?;
                    final title = item['title'] ?? item['name'] ?? 'Untitled';
                    return GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetailsScreen(id: item['id'], mediaType: item['media_type'] ?? 'movie'),
                          ),
                        );
                      },
                      child: Container(
                        width: 80,
                        margin: const EdgeInsets.only(right: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: posterPath != null
                                    ? Image.network(
                                        posterPath.startsWith('http') ? posterPath : 'https://image.tmdb.org/t/p/w500$posterPath',
                                        fit: BoxFit.cover,
                                        width: 80,
                                        errorBuilder: (context, _, __) => Container(color: Colors.white10, child: const Icon(Icons.movie, color: Colors.white24)),
                                      )
                                    : Container(color: Colors.white10, child: const Icon(Icons.movie, color: Colors.white24)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      );
    } else {
      // Tab 2: Player config controls (Playback Speed & Captions sizing)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PLAYBACK SPEED RATE', style: TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
              final isSel = dbService.playbackSpeed == speed;
              return ChoiceChip(
                label: Text('${speed}x'),
                selected: isSel,
                onSelected: (val) {
                  if (val) {
                    dbService.updatePlaybackSpeed(speed);
                    _applyCaptionSettings();
                  }
                },
                selectedColor: AppTheme.accent,
                backgroundColor: AppTheme.surface,
                labelStyle: TextStyle(color: isSel ? Colors.black : Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          const Text('SUBTITLES & CAPTIONS TEXT SIZE', style: TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.format_size_rounded, color: Colors.white54, size: 20),
              Expanded(
                child: Slider(
                  value: dbService.captionSizeMultiplier,
                  min: 0.6,
                  max: 1.8,
                  divisions: 6,
                  activeColor: AppTheme.accent,
                  inactiveColor: Colors.white10,
                  label: '${(dbService.captionSizeMultiplier * 100).toInt()}%',
                  onChanged: (val) {
                    dbService.updateCaptionSize(val);
                    _applyCaptionSettings();
                  },
                ),
              ),
              Text(
                '${(dbService.captionSizeMultiplier * 100).toInt()}%',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),
          const Text(
            'Notice: Changes to subtitles scale size and playback speed affect the native HTML5 player inside the WebView containers instantly.',
            style: TextStyle(color: Colors.white30, fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ],
      );
    }
  }

  Widget _buildInfoRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final isLandscape = orientation == Orientation.landscape;
        final isTv = widget.mediaType == 'tv';
        
        if (isLandscape) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        } else {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }

        final webviewWidget = _buildWebView();
        final gesturePlayer = _buildGesturePlayer(webviewWidget);

        final playerContainer = Container(
          color: Colors.black,
          child: Stack(
            children: [
              Positioned.fill(
                child: isLandscape && _aspectRatioIndex == 3
                    ? gesturePlayer
                    : Center(
                        child: AspectRatio(
                          aspectRatio: _getCalculatedAspectRatio(),
                          child: gesturePlayer,
                        ),
                      ),
              ),
              if (_isLoading)
                Positioned.fill(child: _buildLoadingOverlay()),

              // Floating Lock / Unlock Screen Button (only in landscape)
              if (isLandscape) ...[
                Positioned(
                  left: 20,
                  top: MediaQuery.of(context).size.height / 2 - 25,
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: AnimatedOpacity(
                      opacity: _showControls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: _buildRoundButton(
                        icon: _isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                        onTap: () {
                          setState(() {
                            _isLocked = !_isLocked;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_isLocked ? 'Screen Controls Locked' : 'Screen Controls Unlocked'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                
                // Top Bar Controls
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  child: IgnorePointer(
                    ignoring: !_showControls || _isLocked,
                    child: AnimatedOpacity(
                      opacity: (_showControls && !_isLocked) ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildRoundButton(
                            icon: Icons.arrow_back_rounded,
                            onTap: () => Navigator.pop(context),
                          ),
                          Row(
                            children: [
                              _buildRoundButton(
                                icon: Icons.subtitles_rounded,
                                onTap: () => _showCaptionSettingsSheet(context),
                              ),
                              const SizedBox(width: 12),
                              _buildRoundButton(
                                icon: Icons.aspect_ratio_rounded,
                                onTap: () {
                                  setState(() {
                                    _aspectRatioIndex = (_aspectRatioIndex + 1) % 4;
                                  });
                                  final labels = ['16:9', '4:3', '18:9 (2.0)', 'Stretch / Fill'];
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Aspect Ratio: ${labels[_aspectRatioIndex]}'),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              _buildRoundButton(
                                icon: Icons.pause_circle_filled_rounded,
                                onTap: _togglePlayPause,
                              ),
                              const SizedBox(width: 12),
                              _buildRoundButton(
                                icon: Icons.flash_on_rounded, // Zap ads button
                                onTap: _zapAds,
                              ),
                              const SizedBox(width: 12),
                              _buildRoundButton(
                                icon: Icons.refresh_rounded,
                                onTap: _reloadStream,
                              ),
                              const SizedBox(width: 12),
                              _buildRoundButton(
                                icon: Icons.tune_rounded,
                                onTap: () => _showMirrorSelectorSheet(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Bottom TV Navigation Controls
                if (isTv)
                  Positioned(
                    bottom: 30,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      ignoring: !_showControls || _isLocked,
                      child: AnimatedOpacity(
                        opacity: (_showControls && !_isLocked) ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildRoundButton(
                                  icon: Icons.skip_previous_rounded,
                                  size: 40,
                                  onTap: (_currentEpisode > 1 || _currentSeason > 1) ? _playPrevEpisode : null,
                                ),
                                const SizedBox(width: 20),
                                _buildRoundButton(
                                  icon: Icons.list_rounded,
                                  size: 40,
                                  onTap: () => _showEpisodeSelectorSheet(context),
                                ),
                                const SizedBox(width: 20),
                                _buildRoundButton(
                                  icon: Icons.skip_next_rounded,
                                  size: 40,
                                  onTap: (_currentEpisode < _episodeCount || widget.seasons.any((s) => s['season_number'] == _currentSeason + 1)) ? _playNextEpisode : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );

        if (_isPiPActive && !isLandscape) {
          return Scaffold(
            backgroundColor: AppTheme.background,
            body: Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.picture_in_picture_alt_rounded, color: AppTheme.accent, size: 64),
                        const SizedBox(height: 16),
                        const Text(
                          'Picture-in-Picture Mode Active',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'You are free to view metrics. Drag the floating player overlay anywhere. Expand when done.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, color: Colors.black, size: 16),
                          label: const Text('Close Stream', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: _pipOffset.dx,
                  top: _pipOffset.dy,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _pipOffset = Offset(
                          (_pipOffset.dx + details.delta.dx).clamp(10, MediaQuery.of(context).size.width - 230),
                          (_pipOffset.dy + details.delta.dy).clamp(10, MediaQuery.of(context).size.height - 150),
                        );
                      });
                    },
                    child: Container(
                      width: 220,
                      height: 124,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.accent, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: gesturePlayer,
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isPiPActive = false;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 16),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: isLandscape ? Colors.black : AppTheme.background,
          appBar: isLandscape
              ? null
              : AppBar(
                  backgroundColor: Colors.black,
                  elevation: 0,
                  title: Text(widget.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.flash_on_rounded, color: AppTheme.accent), // Zap ads button
                      onPressed: _zapAds,
                    ),
                    IconButton(
                      icon: const Icon(Icons.aspect_ratio_rounded, color: Colors.white70),
                      onPressed: () {
                        setState(() {
                          _aspectRatioIndex = (_aspectRatioIndex + 1) % 4;
                        });
                        final labels = ['16:9', '4:3', '18:9 (2.0)', 'Stretch / Fill'];
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Aspect Ratio: ${labels[_aspectRatioIndex]}'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white70),
                      onPressed: () {
                        setState(() {
                          _isPiPActive = true;
                          _showControls = false;
                        });
                      },
                    ),
                  ],
                ),
          body: Column(
            children: [
              isLandscape
                  ? Expanded(child: playerContainer)
                  : AspectRatio(
                      aspectRatio: _getCalculatedAspectRatio(),
                      child: playerContainer,
                    ),
              if (!isLandscape)
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F0E13),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(
                            children: [
                              _buildTabButton(0, 'Episodes & Mirrors', Icons.tune_rounded),
                              const SizedBox(width: 8),
                              _buildTabButton(1, 'Synopsis', Icons.info_outline_rounded),
                              const SizedBox(width: 8),
                              _buildTabButton(2, 'Player Configs', Icons.speed_rounded),
                            ],
                          ),
                        ),
                        const Divider(color: Colors.white10, height: 1),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: _buildActiveTabContent(isTv),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoundButton({required IconData icon, required VoidCallback? onTap, double size = 32}) {
    return Container(
      width: size + 16,
      height: size + 16,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: onTap == null ? Colors.white24 : Colors.white, size: size - 8),
        onPressed: onTap,
      ),
    );
  }

  void _showCaptionSettingsSheet(BuildContext context) {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * (isLandscape ? 0.85 : 0.6),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.subtitles_rounded, color: AppTheme.accent, size: 20),
                      SizedBox(width: 10),
                      Text('Subtitle Size Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Select comfortable reading size:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    children: _captionSizes.map((size) {
                      final isSel = dbService.captionSizeMultiplier == size['value'];
                      return ChoiceChip(
                        label: Text(size['label']),
                        selected: isSel,
                        onSelected: (val) {
                          setModalState(() {
                            dbService.updateCaptionSize(size['value'] as double);
                          });
                          _applyCaptionSettings();
                        },
                        selectedColor: AppTheme.accent,
                        backgroundColor: Colors.white.withAlpha(10),
                        labelStyle: TextStyle(
                          color: isSel ? Colors.black : Colors.white,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text('Playback Speed:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) {
                        final isSel = dbService.playbackSpeed == s;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('${s}x'),
                            selected: isSel,
                            onSelected: (val) {
                              setModalState(() {
                                dbService.updatePlaybackSpeed(s);
                              });
                              _applyCaptionSettings();
                            },
                            selectedColor: AppTheme.accent,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Colors.white30, size: 16),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Note: Settings will be saved for all videos.',
                            style: TextStyle(color: Colors.white54, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [Color(0xFF1E1B2E), Color(0xFF07050A)],
          center: Alignment.center,
          radius: 1.2,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.15,
              child: Image.network(
                'https://images.unsplash.com/photo-1574267431647-c82c0b39f837?w=600',
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const SizedBox(),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3), width: 1.5),
                    ),
                    child: const CircularProgressIndicator(
                      color: AppTheme.accent,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Initializing ${_mirrorSource.toUpperCase()} ...',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Loading media buffer stream mirrors',
                    style: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('STUCK?', style: TextStyle(color: AppTheme.secondaryAccent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                        const SizedBox(width: 10),
                        Wrap(
                          spacing: 6,
                          children: ['vidsrc.to', 'vidsrc.me', 'embed.su', 'vidsrc.cc', 'vidsrc.nl', 'multiembed.to'].map((srv) {
                            final idx = ['vidsrc.to', 'vidsrc.me', 'embed.su', 'vidsrc.cc', 'vidsrc.nl', 'multiembed.to'].indexOf(srv) + 1;
                            final isCur = _mirrorSource == srv;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _mirrorSource = srv;
                                  _isLoading = true;
                                });
                                _reloadStream();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isCur ? AppTheme.accent : Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isCur ? AppTheme.accent : Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                child: Text(
                                  'M$idx',
                                  style: TextStyle(
                                    color: isCur ? Colors.black : Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMirrorOption(String value, String title, IconData icon, String ping, String badgeText, Color pingColor) {
    final isSelected = _mirrorSource == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _mirrorSource = value;
        });
        _reloadStream();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.accent : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.1),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            // Status Dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: pingColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: pingColor.withValues(alpha: 0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  )
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(icon, color: isSelected ? AppTheme.accent : Colors.white38, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        'Latency: $ping',
                        style: TextStyle(
                          color: isSelected ? AppTheme.accent.withValues(alpha: 0.8) : Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('•', style: TextStyle(color: Colors.white24, fontSize: 10)),
                      const SizedBox(width: 8),
                      Text(
                        badgeText,
                        style: const TextStyle(color: AppTheme.secondaryAccent, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppTheme.accent, size: 20)
            else
              const Icon(Icons.radio_button_off_rounded, color: Colors.white12, size: 20),
          ],
        ),
      ),
    );
  }

  void _showMirrorSelectorSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: StatefulBuilder(builder: (context, setModalState) {
            final mirrors = [
              {
                'id': 'vidsrc.to',
                'name': 'VidSrc TO',
                'desc': 'FHD • Fast Server',
                'badge': 'Primary',
                'badgeColor': AppTheme.accent,
                'icon': Icons.hd_rounded
              },
              {
                'id': 'vidsrc.me',
                'name': 'VidSrc ME',
                'desc': 'HD • Responsive',
                'badge': 'Backup',
                'badgeColor': Colors.white24,
                'icon': Icons.flash_on_rounded
              },
              {
                'id': 'vidlink.pro',
                'name': 'VidLink Pro',
                'desc': 'Multi-Audio (Hindi)',
                'badge': 'Dual-Audio 🇮🇳',
                'badgeColor': Colors.orangeAccent,
                'icon': Icons.translate_rounded
              },
              {
                'id': 'embed.su',
                'name': 'Embed SU',
                'desc': 'FHD • Multi-Host',
                'badge': 'Backup',
                'badgeColor': Colors.white24,
                'icon': Icons.auto_awesome_rounded
              },
              {
                'id': 'vidsrc.cc',
                'name': 'VidSrc CC',
                'desc': 'Multi-Language Tracks',
                'badge': 'Dual-Audio 🇮🇳',
                'badgeColor': Colors.orangeAccent,
                'icon': Icons.interpreter_mode_rounded
              },
              {
                'id': 'smashystream',
                'name': 'SmashyStream',
                'desc': 'Alternative Servers',
                'badge': 'Dubs',
                'badgeColor': Colors.greenAccent,
                'icon': Icons.movie_filter_rounded
              },
              {
                'id': '2embed.cc',
                'name': '2Embed',
                'desc': 'Multi-Lang Backup',
                'badge': 'Dubs',
                'badgeColor': Colors.greenAccent,
                'icon': Icons.stream_rounded
              },
              {
                'id': 'vidsrc.nl',
                'name': 'AutoNL Proxy',
                'desc': 'European Routing',
                'badge': 'Proxy',
                'badgeColor': Colors.white24,
                'icon': Icons.language_rounded
              },
              {
                'id': 'multiembed.to',
                'name': 'MultiEmbed',
                'desc': 'Aggregated Streams',
                'badge': 'Aggregator',
                'badgeColor': Colors.cyanAccent,
                'icon': Icons.dynamic_feed_rounded
              },
            ];

            return Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Mirror Source',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose VidLink, VidSrc CC or SmashyStream for Multi-Audio (Hindi Dubs) support.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  
                  // Clean 2-column Grid layout
                  Flexible(
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.6,
                      ),
                      itemCount: mirrors.length,
                      itemBuilder: (ctx, idx) {
                        final m = mirrors[idx];
                        final isSel = _mirrorSource == m['id'];
                        final badge = m['badge'] as String;
                        final badgeColor = m['badgeColor'] as Color;
                        
                        return InkWell(
                          onTap: () {
                            setModalState(() {
                              _mirrorSource = m['id'] as String;
                            });
                            setState(() {
                              _mirrorSource = m['id'] as String;
                            });
                            _reloadStream();
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSel ? AppTheme.accent.withAlpha(20) : Colors.white.withAlpha(5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSel ? AppTheme.accent : Colors.white12,
                                width: isSel ? 1.5 : 1.0,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Icon(
                                      m['icon'] as IconData, 
                                      color: isSel ? AppTheme.accent : Colors.white60, 
                                      size: 18
                                    ),
                                    if (badge.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isSel ? AppTheme.accent.withAlpha(30) : badgeColor.withAlpha(20),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isSel ? AppTheme.accent.withAlpha(100) : badgeColor.withAlpha(80),
                                            width: 0.5
                                          ),
                                        ),
                                        child: Text(
                                          badge,
                                          style: TextStyle(
                                            color: isSel ? AppTheme.accent : badgeColor,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m['name'] as String,
                                      style: TextStyle(
                                        color: isSel ? Colors.white : Colors.white70,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      m['desc'] as String,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 9
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  void _showEpisodeSelectorSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          final validSeasons = widget.seasons.where((s) => (s['season_number'] as int? ?? 0) >= 1).toList();

          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                const Text('Select Season & Episode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                
                // Season tabs selector
                if (validSeasons.isNotEmpty)
                  SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: validSeasons.length,
                      itemBuilder: (ctx, index) {
                        final sNum = validSeasons[index]['season_number'] as int? ?? 1;
                        final isSel = _currentSeason == sNum;
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              _currentSeason = sNum;
                              final sData = validSeasons.firstWhere((s) => s['season_number'] == sNum);
                              _episodeCount = sData['episode_count'] ?? 10;
                            });
                            setState(() {
                              _currentSeason = sNum;
                              _updateEpisodeCount();
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSel ? AppTheme.accent : Colors.white.withAlpha(8),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Season $sNum',
                              style: TextStyle(color: isSel ? Colors.black : Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                
                const SizedBox(height: 16),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 12),
                
                // Grid of Episodes
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: _episodeCount,
                    itemBuilder: (ctx, index) {
                      final epNum = index + 1;
                      final isSel = _currentEpisode == epNum;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _currentEpisode = epNum;
                          });
                          _saveToHistory();
                          _reloadStream();
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSel ? AppTheme.secondaryAccent.withAlpha(20) : Colors.white.withAlpha(5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSel ? AppTheme.secondaryAccent : Colors.white12,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('EP', style: TextStyle(color: isSel ? AppTheme.secondaryAccent : Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text('$epNum', style: TextStyle(color: isSel ? Colors.white : Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }
}
