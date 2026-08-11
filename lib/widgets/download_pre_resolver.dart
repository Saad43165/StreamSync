import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../services/stream_resolver_service.dart';
import '../theme/app_theme.dart';

/// Shows a bottom sheet with a hidden 1×1 WebView.
/// Loads the first embed URL, injects the JS interceptor, and calls
/// [onResolved] with the direct video URL once captured.
/// Returns via Navigator.pop(true) on success, pop(false) on failure/timeout.
class DownloadPreResolver extends StatefulWidget {
  final int tmdbId;
  final String title;
  final String mediaType;
  final int season;
  final int episode;
  final void Function(String videoUrl) onResolved;
  final VoidCallback onFailed;

  const DownloadPreResolver({
    super.key,
    required this.tmdbId,
    required this.title,
    required this.mediaType,
    required this.onResolved,
    required this.onFailed,
    this.season = 1,
    this.episode = 1,
  });

  @override
  State<DownloadPreResolver> createState() => _DownloadPreResolverState();
}

class _DownloadPreResolverState extends State<DownloadPreResolver>
    with SingleTickerProviderStateMixin {
  InAppWebViewController? _wvc;
  String _statusText = 'Preparing download…';
  double _progress = 0.0;
  bool _resolved = false;
  bool _timedOut = false;
  Timer? _timeoutTimer;
  Timer? _progressTimer;
  late AnimationController _dotCtrl;
  int _dotCount = 0;

  // Pull the first embed URL from the resolver (no network call needed)
  String get _embedUrl {
    final mirrors = StreamResolverService.getAllEmbedProviders(
      tmdbId: widget.tmdbId,
      isMovie: widget.mediaType == 'movie',
      season: widget.season,
      episode: widget.episode,
    );
    return mirrors.isNotEmpty ? mirrors.first['url']! : '';
  }

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();
    _dotCtrl.addListener(() {
      if (mounted) setState(() => _dotCount = (_dotCtrl.value * 4).floor() % 4);
    });

    // Simulate subtle progress bar movement while waiting
    _progressTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted || _resolved) return;
      setState(() {
        if (_progress < 0.85) _progress = (_progress + 0.015).clamp(0.0, 0.85);
      });
    });

    // 75-second hard timeout
    _timeoutTimer = Timer(const Duration(seconds: 75), _onTimeout);
  }

  void _onTimeout() {
    if (_resolved || !mounted) return;
    _timedOut = true;
    widget.onFailed();
    if (mounted) Navigator.of(context).pop(false);
  }

  void _onVideoUrl(String url) {
    if (_resolved || !mounted) return;
    _resolved = true;
    _timeoutTimer?.cancel();
    _progressTimer?.cancel();
    setState(() {
      _progress = 1.0;
      _statusText = 'Source found — starting download…';
    });
    // Brief pause so user sees the success state
    Future.delayed(const Duration(milliseconds: 600), () {
      widget.onResolved(url);
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _progressTimer?.cancel();
    _dotCtrl.dispose();
    _wvc?.stopLoading();
    super.dispose();
  }

  // ── JS injected on every page load ──────────────────────────────────────
  static const String _interceptorJs = r"""
(function() {
  'use strict';
  if (window.__svDlInterceptor) return;
  window.__svDlInterceptor = true;

  let reported = false;

  function isDirectVideo(url) {
    if (!url || typeof url !== 'string') return false;
    if (url.startsWith('blob:') || url.startsWith('data:') || url.startsWith('javascript:')) return false;
    const u = url.toLowerCase().split('?')[0];
    return u.endsWith('.m3u8') || u.endsWith('.mp4') || u.endsWith('.mkv') ||
           u.endsWith('.webm') || u.endsWith('.ts') || u.endsWith('.mpd') ||
           url.includes('.m3u8') || url.includes('manifest') ||
           url.includes('googlevideo.com') || url.includes('akamaized.net') ||
           url.includes('hwcdn.net') || url.includes('fastly.net');
  }

  function report(url) {
    if (reported || !url) return;
    reported = true;
    try { window.flutter_inappwebview.callHandler('dlVideoUrl', url); } catch(e) {}
  }

  try {
    const desc = Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype, 'src');
    if (desc && desc.set) {
      Object.defineProperty(HTMLMediaElement.prototype, 'src', {
        set(val) { if (isDirectVideo(val)) report(val); desc.set.call(this, val); },
        get() { return desc.get.call(this); },
        configurable: true,
      });
    }
  } catch(e) {}

  document.addEventListener('loadedmetadata', function(e) {
    if (e.target && e.target.tagName === 'VIDEO') {
      const src = e.target.currentSrc || e.target.src;
      if (src && isDirectVideo(src)) report(src);
    }
  }, true);

  const origOpen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function(method, url) {
    if (typeof url === 'string' && isDirectVideo(url)) report(url);
    return origOpen.apply(this, arguments);
  };

  const origFetch = window.fetch;
  if (origFetch) {
    window.fetch = function(input, init) {
      const url = typeof input === 'string' ? input : (input && input.url);
      if (url && isDirectVideo(url)) report(url);
      return origFetch.apply(this, arguments);
    };
  }

  function checkVideos() {
    document.querySelectorAll('video').forEach(function(v) {
      const s = v.currentSrc || v.src;
      if (s && isDirectVideo(s)) report(s);
    });
  }

  const obs = new MutationObserver(checkVideos);
  function startObs() {
    obs.observe(document.body, {subtree:true,childList:true,attributes:true,attributeFilter:['src']});
    checkVideos();
  }
  if (document.body) startObs();
  else document.addEventListener('DOMContentLoaded', startObs);

  let polls = 0;
  const t = setInterval(function() {
    checkVideos();
    if (reported || ++polls > 40) clearInterval(t);
  }, 1500);
})();
""";

  @override
  Widget build(BuildContext context) {
    final dots = '.' * _dotCount + ' ' * (3 - _dotCount);
    final isDone = _progress >= 1.0;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 16, 24, MediaQuery.of(context).padding.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Icon
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone
                  ? Colors.greenAccent.withValues(alpha: 0.12)
                  : AppTheme.accent.withValues(alpha: 0.12),
              border: Border.all(
                color: isDone
                    ? Colors.greenAccent.withValues(alpha: 0.5)
                    : AppTheme.accent.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Icon(
              isDone ? Icons.check_rounded : Icons.download_rounded,
              color: isDone ? Colors.greenAccent : AppTheme.accent,
              size: 30,
            ),
          ),
          const SizedBox(height: 18),

          // Title
          Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),

          // Status
          Text(
            isDone ? _statusText : '$_statusText$dots',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDone ? Colors.greenAccent : AppTheme.accent,
              ),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            isDone
                ? 'Download will begin shortly'
                : 'This may take up to a minute',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),

          // The actual hidden WebView — 1×1, invisible to user
          if (_embedUrl.isNotEmpty)
            SizedBox(
              width: 1,
              height: 1,
              child: InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri(_embedUrl),
                  headers: {
                    'User-Agent':
                        'Mozilla/5.0 (Linux; Android 12; Pixel 6) '
                        'AppleWebKit/537.36 (KHTML, like Gecko) '
                        'Chrome/120.0.0.0 Mobile Safari/537.36',
                    'Referer': 'https://www.google.com/',
                  },
                ),
                initialSettings: InAppWebViewSettings(
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  javaScriptEnabled: true,
                  transparentBackground: true,
                  disableVerticalScroll: true,
                  disableHorizontalScroll: true,
                  supportZoom: false,
                ),
                onWebViewCreated: (controller) {
                  _wvc = controller;
                  controller.addJavaScriptHandler(
                    handlerName: 'dlVideoUrl',
                    callback: (args) {
                      final url = args.isNotEmpty ? args[0] as String? : null;
                      if (url != null && url.isNotEmpty) _onVideoUrl(url);
                    },
                  );
                },
                onLoadStop: (controller, url) async {
                  // Unmute and auto-play so the player starts buffering
                  await controller.evaluateJavascript(source: r"""
                    try {
                      document.querySelectorAll('video,audio').forEach(function(m) {
                        m.muted = true;
                        m.volume = 0;
                        if (m.paused) m.play().catch(function(){});
                      });
                    } catch(e) {}
                  """);
                  await controller.evaluateJavascript(source: _interceptorJs);
                },
                shouldOverrideUrlLoading: (controller, action) async {
                  // Allow all navigations inside this hidden resolver
                  return NavigationActionPolicy.ALLOW;
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Convenience function — shows the pre-resolver sheet and returns
/// the captured video URL, or null on failure/timeout.
Future<String?> showDownloadPreResolver({
  required BuildContext context,
  required int tmdbId,
  required String title,
  required String mediaType,
  int season = 1,
  int episode = 1,
}) {
  final completer = Completer<String?>();

  showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    builder: (_) => DownloadPreResolver(
      tmdbId: tmdbId,
      title: title,
      mediaType: mediaType,
      season: season,
      episode: episode,
      onResolved: (url) => completer.complete(url),
      onFailed: () => completer.complete(null),
    ),
  ).then((_) {
    if (!completer.isCompleted) completer.complete(null);
  });

  return completer.future;
}
