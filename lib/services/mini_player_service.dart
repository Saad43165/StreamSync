// lib/services/mini_player_service.dart
import 'dart:async';
import 'package:flutter/material.dart';

class MiniPlayerService extends ChangeNotifier {
  // Remove singleton pattern - use Provider instead
  MiniPlayerService();

  bool _isPlaying = false;
  bool _isMiniPlayerActive = false;
  String? _currentTitle;
  String? _currentStreamUrl;
  String? _currentMediaType;
  int? _currentSeason;
  int? _currentEpisode;
  int? _currentTmdbId;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  bool get isPlaying => _isPlaying;
  bool get isMiniPlayerActive => _isMiniPlayerActive;
  String? get currentTitle => _currentTitle;
  String? get currentStreamUrl => _currentStreamUrl;
  String? get currentMediaType => _currentMediaType;
  int? get currentSeason => _currentSeason;
  int? get currentEpisode => _currentEpisode;
  int? get currentTmdbId => _currentTmdbId;
  Duration get position => _position;
  Duration get duration => _duration;
  double get progress => _duration.inMilliseconds > 0
      ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
      : 0.0;

  void startMiniPlayer({
    required String title,
    required String streamUrl,
    required String mediaType,
    int? season,
    int? episode,
    int? tmdbId,
    Duration position = Duration.zero,
    Duration duration = Duration.zero,
  }) {
    _isPlaying = true;
    _isMiniPlayerActive = true;
    _currentTitle = title;
    _currentStreamUrl = streamUrl;
    _currentMediaType = mediaType;
    _currentSeason = season;
    _currentEpisode = episode;
    _currentTmdbId = tmdbId;
    _position = position;
    _duration = duration;

    notifyListeners();
  }

  void updatePosition(Duration position, Duration duration) {
    _position = position;
    _duration = duration;
    notifyListeners();
  }

  void pause() {
    _isPlaying = false;
    notifyListeners();
  }

  void resume() {
    _isPlaying = true;
    notifyListeners();
  }

  void close() {
    _isPlaying = false;
    _isMiniPlayerActive = false;
    _currentTitle = null;
    _currentStreamUrl = null;
    _currentMediaType = null;
    _currentSeason = null;
    _currentEpisode = null;
    _currentTmdbId = null;
    _position = Duration.zero;
    _duration = Duration.zero;

    notifyListeners();
  }

  void stopMiniPlayer() {
    _isMiniPlayerActive = false;
    notifyListeners();
  }
}