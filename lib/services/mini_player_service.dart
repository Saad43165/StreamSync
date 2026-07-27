// lib/services/mini_player_service.dart
import 'package:flutter/material.dart';

enum MiniPlayerState {
  inactive,
  active,
  minimized,
  transitioning,
}

class MiniPlayerService extends ChangeNotifier {
  MiniPlayerService();

  // ── State ──────────────────────────────────────────────────────────────────
  MiniPlayerState _state = MiniPlayerState.inactive;
  bool _isPlaying = false;

  // ── Content Data ───────────────────────────────────────────────────────────
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
  double _volume = 0.5;
  double _playbackSpeed = 1.0;

  // ── Getters ────────────────────────────────────────────────────────────────
  MiniPlayerState get state => _state;
  bool get isPlaying => _isPlaying;
  bool get isMiniPlayerActive => _state == MiniPlayerState.active;
  bool get isMinimized => _state == MiniPlayerState.minimized;

  String? get currentTitle => _currentTitle;
  String? get currentStreamUrl => _currentStreamUrl;
  String? get currentMediaType => _currentMediaType;
  int? get currentSeason => _currentSeason;
  int? get currentEpisode => _currentEpisode;
  int? get currentTmdbId => _currentTmdbId;
  String? get posterPath => _posterPath;

  Duration get position => _position;
  Duration get duration => _duration;
  double get volume => _volume;
  double get playbackSpeed => _playbackSpeed;

  double get progress => _duration.inMilliseconds > 0
      ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
      : 0.0;

  String get formattedPosition {
    final h = _position.inHours;
    final m = _position.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _position.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String get formattedDuration {
    final h = _duration.inHours;
    final m = _duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String get episodeInfo {
    if (_currentMediaType != 'tv') return '';
    final season = _currentSeason != null ? 'S${_currentSeason}' : '';
    final episode = _currentEpisode != null ? 'E${_currentEpisode}' : '';
    return '$season$episode';
  }

  // ── Debug ──────────────────────────────────────────────────────────────────
  void debugPrintState() {
    debugPrint('═══════════════════════════════════════');
    debugPrint('🎵 MINI PLAYER SERVICE STATE');
    debugPrint('═══════════════════════════════════════');
    debugPrint('State: $_state');
    debugPrint('Playing: $_isPlaying');
    debugPrint('Title: $_currentTitle');
    debugPrint('Stream URL: ${_currentStreamUrl != null ? "SET" : "NULL"}');
    debugPrint('Media Type: $_currentMediaType');
    debugPrint('Season: $_currentSeason');
    debugPrint('Episode: $_currentEpisode');
    debugPrint('TMDB ID: $_currentTmdbId');
    debugPrint('Position: ${_position.inSeconds}s');
    debugPrint('Duration: ${_duration.inSeconds}s');
    debugPrint('Progress: ${(progress * 100).toStringAsFixed(1)}%');
    debugPrint('Volume: $_volume');
    debugPrint('Speed: ${_playbackSpeed}x');
    debugPrint('═══════════════════════════════════════');
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Start the mini player with the given content
  void startMiniPlayer({
    required String title,
    required String streamUrl,
    required String mediaType,
    int? season,
    int? episode,
    int? tmdbId,
    String? posterPath,
    Duration position = Duration.zero,
    Duration duration = Duration.zero,
    double volume = 0.5,
  }) {
    // Validate required fields
    if (title.isEmpty) {
      debugPrint('⚠️ MiniPlayerService: Title cannot be empty');
      return;
    }
    if (streamUrl.isEmpty) {
      debugPrint('⚠️ MiniPlayerService: Stream URL cannot be empty');
      return;
    }

    _state = MiniPlayerState.active;
    _isPlaying = true;
    _currentTitle = title;
    _currentStreamUrl = streamUrl;
    _currentMediaType = mediaType;
    _currentSeason = season;
    _currentEpisode = episode;
    _currentTmdbId = tmdbId;
    _posterPath = posterPath;
    _position = position;
    _duration = duration;
    _volume = volume.clamp(0.0, 1.0);

    debugPrint('✅ MiniPlayer started: $title');
    notifyListeners();
  }

  /// Update playback position
  void updatePosition(Duration position, Duration duration) {
    // Only update if there's a meaningful change
    if (position == _position && duration == _duration) return;

    _position = position;
    _duration = duration;
    notifyListeners();
  }

  /// Pause playback
  void pause() {
    if (!_isPlaying) return;
    _isPlaying = false;
    notifyListeners();
  }

  /// Resume playback
  void resume() {
    if (_isPlaying) return;
    _isPlaying = true;
    notifyListeners();
  }

  /// Toggle play/pause
  void togglePlayPause() {
    _isPlaying = !_isPlaying;
    notifyListeners();
  }

  /// Update volume
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    notifyListeners();
  }

  /// Update playback speed
  void setPlaybackSpeed(double speed) {
    _playbackSpeed = speed.clamp(0.5, 2.0);
    notifyListeners();
  }

  /// Seek to a specific position
  void seekTo(Duration position) {
    _position = position;
    notifyListeners();
  }

  /// Minimize (PiP mode or background)
  void minimize() {
    if (_state != MiniPlayerState.active) return;
    _state = MiniPlayerState.minimized;
    notifyListeners();
  }

  /// Expand from minimized
  void expand() {
    if (_state != MiniPlayerState.minimized) return;
    _state = MiniPlayerState.active;
    notifyListeners();
  }

  /// Stop the mini player (keep data but mark inactive)
  void stopMiniPlayer() {
    if (_state == MiniPlayerState.inactive) return;
    _state = MiniPlayerState.inactive;
    notifyListeners();
  }

  /// Close and clear all data
  void close() {
    _state = MiniPlayerState.inactive;
    _isPlaying = false;
    _currentTitle = null;
    _currentStreamUrl = null;
    _currentMediaType = null;
    _currentSeason = null;
    _currentEpisode = null;
    _currentTmdbId = null;
    _posterPath = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    _volume = 0.5;
    _playbackSpeed = 1.0;

    debugPrint('🗑️ MiniPlayer closed and cleared');
    notifyListeners();
  }

  /// Update the current stream URL (for mirror switching)
  void updateStreamUrl(String newUrl) {
    if (newUrl.isEmpty) return;
    _currentStreamUrl = newUrl;
    notifyListeners();
  }

  /// Update metadata
  void updateMetadata({
    String? title,
    String? posterPath,
    int? season,
    int? episode,
  }) {
    if (title != null) _currentTitle = title;
    if (posterPath != null) _posterPath = posterPath;
    if (season != null) _currentSeason = season;
    if (episode != null) _currentEpisode = episode;
    notifyListeners();
  }
}