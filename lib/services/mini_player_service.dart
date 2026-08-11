import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

enum MiniPlayerState { inactive, active }

class MiniPlayerService extends ChangeNotifier {
  // Global player — outlives any individual screen so audio continues in mini player
  final Player player = Player();
  late final VideoController videoController = VideoController(player);

  MiniPlayerService() {
    // Keep _isPlaying in sync with the actual player state
    player.stream.playing.listen((playing) {
      if (_isPlaying != playing) {
        _isPlaying = playing;
        notifyListeners();
      }
    });
    player.stream.position.listen((pos) {
      if (_isNativeMode) {
        _position = pos;
        notifyListeners();
      }
    });
    player.stream.duration.listen((dur) {
      if (_isNativeMode) {
        _duration = dur;
        notifyListeners();
      }
    });
  }

  // ── State ──────────────────────────────────────────────────────────────────
  MiniPlayerState _state = MiniPlayerState.inactive;
  bool _isPlaying = false;
  bool _isNativeMode = false; // true when media_kit has content

  // ── Content ────────────────────────────────────────────────────────────────
  String? _currentTitle;
  String? _currentStreamUrl;
  String? _currentMediaType;
  int? _currentSeason;
  int? _currentEpisode;
  int? _currentTmdbId;
  String? _posterPath;

  // ── Playback ───────────────────────────────────────────────────────────────
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // ── Getters ────────────────────────────────────────────────────────────────
  bool get isMiniPlayerActive => _state == MiniPlayerState.active;
  bool get isPlaying => _isPlaying;
  bool get isNativeMode => _isNativeMode;

  String? get currentTitle => _currentTitle;
  String? get currentStreamUrl => _currentStreamUrl;
  String? get currentMediaType => _currentMediaType;
  int? get currentSeason => _currentSeason;
  int? get currentEpisode => _currentEpisode;
  int? get currentTmdbId => _currentTmdbId;
  String? get posterPath => _posterPath;

  Duration get position => _position;
  Duration get duration => _duration;

  double get progress => _duration.inMilliseconds > 0
      ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
      : 0.0;

  String get episodeInfo {
    if (_currentMediaType != 'tv') return '';
    final s = _currentSeason != null ? 'S$_currentSeason' : '';
    final e = _currentEpisode != null ? 'E$_currentEpisode' : '';
    return '$s$e';
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void startMiniPlayer({
    required String title,
    required String streamUrl,
    required String mediaType,
    bool nativeMode = false,
    int? season,
    int? episode,
    int? tmdbId,
    String? posterPath,
    Duration position = Duration.zero,
    Duration duration = Duration.zero,
  }) {
    if (title.isEmpty || streamUrl.isEmpty) return;

    _state = MiniPlayerState.active;
    _isPlaying = true;
    _isNativeMode = nativeMode;
    _currentTitle = title;
    _currentStreamUrl = streamUrl;
    _currentMediaType = mediaType;
    _currentSeason = season;
    _currentEpisode = episode;
    _currentTmdbId = tmdbId;
    _posterPath = posterPath;

    if (!nativeMode) {
      // WebView mode — position tracking is manual
      _position = position;
      _duration = duration;
    }
    // In native mode, positions are driven by player.stream.position listener

    notifyListeners();
  }

  void setNativeMode(bool v) {
    _isNativeMode = v;
  }

  void updatePosition(Duration position, Duration duration) {
    if (_isNativeMode) return; // driven by player stream in native mode
    _position = position;
    _duration = duration;
    notifyListeners();
  }

  void pause() {
    if (_isNativeMode) {
      player.pause();
    } else {
      _isPlaying = false;
      notifyListeners();
    }
  }

  void resume() {
    if (_isNativeMode) {
      player.play();
    } else {
      _isPlaying = true;
      notifyListeners();
    }
  }

  void togglePlayPause() => _isPlaying ? pause() : resume();

  void seekForward() {
    if (_isNativeMode) {
      player.seek(player.state.position + const Duration(seconds: 10));
    } else {
      final newPos = _position + const Duration(seconds: 10);
      _position = newPos > _duration ? _duration : newPos;
      notifyListeners();
    }
  }

  void seekBack() {
    if (_isNativeMode) {
      final newPos = player.state.position - const Duration(seconds: 10);
      player.seek(newPos < Duration.zero ? Duration.zero : newPos);
    } else {
      final newPos = _position - const Duration(seconds: 10);
      _position = newPos < Duration.zero ? Duration.zero : newPos;
      notifyListeners();
    }
  }

  void stopMiniPlayer() {
    if (_isNativeMode) {
      player.stop();
    }
    _state = MiniPlayerState.inactive;
    _isNativeMode = false;
    _isPlaying = false;
    notifyListeners();
  }

  void close() => stopMiniPlayer();

  // Used by WebView JS interceptor to hand off the real URL
  String? _interceptedVideoUrl;
  String? get interceptedVideoUrl => _interceptedVideoUrl;
  void updateVideoUrl(String url) { _interceptedVideoUrl = url; }

  // Fullscreen tracking
  bool _wasFullscreen = false;
  bool get wasFullscreen => _wasFullscreen;
  void markFromFullscreen() { _wasFullscreen = true; }
  void clearFullscreen() { _wasFullscreen = false; }

  // Kept for back-compat callers
  void updateStreamUrl(String newUrl) {
    if (newUrl.isEmpty) return;
    _currentStreamUrl = newUrl;
    notifyListeners();
  }

  void updateMetadata({String? title, String? posterPath, int? season, int? episode}) {
    if (title != null) _currentTitle = title;
    if (posterPath != null) _posterPath = posterPath;
    if (season != null) _currentSeason = season;
    if (episode != null) _currentEpisode = episode;
    notifyListeners();
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}
