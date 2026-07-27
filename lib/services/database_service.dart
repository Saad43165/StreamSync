import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseService extends ChangeNotifier {
  List<Map<String, dynamic>> _watchlist = [];
  List<Map<String, dynamic>> get watchlist => List.unmodifiable(_watchlist);

  List<Map<String, dynamic>> _watchHistory = [];
  List<Map<String, dynamic>> get watchHistory => List.unmodifiable(_watchHistory);

  int _totalHoursWatched = 0;
  int get totalHoursWatched => _totalHoursWatched;

  String _selectedCountry = 'US';
  String get selectedCountry => _selectedCountry;

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  bool _notifNewRelease = true;
  bool get notifNewRelease => _notifNewRelease;

  bool _notifTrending = false;
  bool get notifTrending => _notifTrending;

  // Player Preferences
  double _captionSizeMultiplier = 1.0;
  double get captionSizeMultiplier => _captionSizeMultiplier;

  String _defaultQuality = 'Auto';
  String get defaultQuality => _defaultQuality;

  bool _autoPlayNext = true;
  bool get autoPlayNext => _autoPlayNext;

  double _playbackSpeed = 1.0;
  double get playbackSpeed => _playbackSpeed;

  List<Map<String, dynamic>> _downloads = [];
  List<Map<String, dynamic>> get downloads => List.unmodifiable(_downloads);

  final Map<int, String> _resolvedUrls = {};
  Map<int, String> get resolvedUrls => Map.unmodifiable(_resolvedUrls);

  // Multi-Profile & Auth system
  String _currentProfile = 'Enthusiast';
  String get currentProfile => _currentProfile;

  final List<String> _profiles = ['Enthusiast', 'Family', 'Kids'];
  List<String> get profiles => List.unmodifiable(_profiles);

  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  String _username = '';
  String get username => _username;

  String _email = '';
  String get email => _email;

  // NEW: Loading state
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  // NEW: Cache for isInWatchlist/isDownloaded checks
  final Set<int> _watchlistIds = {};
  final Set<int> _downloadIds = {};

  DatabaseService() {
    _loadInitialConfig();
  }

  // ── Helper: Get the active scope key ──────────────────────────────────────
  String get _activeScope => _isLoggedIn ? "auth_user_$username" : _currentProfile;

  // ── Helper: Save list to prefs ─────────────────────────────────────────────
  Future<void> _saveList(String key, List<Map<String, dynamic>> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stringList = list.map((x) => json.encode(x)).toList();
      await prefs.setStringList(key, stringList);
    } catch (e) {
      debugPrint('Error saving $key: $e');
    }
  }

  // ── Helper: Rebuild ID cache ──────────────────────────────────────────────
  void _rebuildIdCaches() {
    _watchlistIds.clear();
    _downloadIds.clear();
    for (final item in _watchlist) {
      _watchlistIds.add(item['id'] as int);
    }
    for (final item in _downloads) {
      _downloadIds.add(item['id'] as int);
    }
  }

  Future<void> _loadInitialConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentProfile = prefs.getString('streamsync_active_profile') ?? 'Enthusiast';
      _selectedCountry = prefs.getString('streamsync_country') ?? 'US';
      _isPremium = prefs.getBool('streamsync_premium') ?? false;
      _isLoggedIn = prefs.getBool('streamsync_logged_in') ?? false;
      _username = prefs.getString('streamsync_username') ?? '';
      _email = prefs.getString('streamsync_email') ?? '';
      _notifNewRelease = prefs.getBool('streamsync_notif_new_release') ?? true;
      _notifTrending = prefs.getBool('streamsync_notif_trending') ?? false;

      // Load Player Preferences
      _captionSizeMultiplier = prefs.getDouble('streamsync_caption_size') ?? 1.0;
      _defaultQuality = prefs.getString('streamsync_quality') ?? 'Auto';
      _autoPlayNext = prefs.getBool('streamsync_autoplay') ?? true;
      _playbackSpeed = prefs.getDouble('streamsync_speed') ?? 1.0;

      // Load resolved URLs from preferences cache
      for (final key in prefs.getKeys()) {
        if (key.startsWith('streamsync_resolved_url_')) {
          final idStr = key.substring('streamsync_resolved_url_'.length);
          final id = int.tryParse(idStr);
          final url = prefs.getString(key);
          if (id != null && url != null) {
            _resolvedUrls[id] = url;
          }
        }
      }

      await _loadProfileData();
      await _loadDownloads();

      _rebuildIdCaches();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading initial config: $e');
      _isLoading = false;
    }
  }

  Future<void> _loadProfileData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scope = _activeScope;
      final watchlistKey = "streamsync_${scope}_watchlist";
      final historyKey = "streamsync_${scope}_history";
      final statsKey = "streamsync_${scope}_watch_stats";

      final watchlistData = prefs.getStringList(watchlistKey) ?? [];
      _watchlist = watchlistData
          .map((item) => json.decode(item) as Map<String, dynamic>)
          .toList();

      final historyData = prefs.getStringList(historyKey) ?? [];
      _watchHistory = historyData
          .map((item) => json.decode(item) as Map<String, dynamic>)
          .toList();

      _totalHoursWatched = prefs.getInt(statsKey) ?? 0;
      _rebuildIdCaches();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading profile data: $e');
    }
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<void> login(String username, String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isLoggedIn = true;
      _username = username;
      _email = email;
      await prefs.setBool('streamsync_logged_in', true);
      await prefs.setString('streamsync_username', username);
      await prefs.setString('streamsync_email', email);
      await _loadProfileData();
    } catch (e) {
      debugPrint('Error logging in: $e');
    }
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isLoggedIn = false;
      _username = '';
      _email = '';
      await prefs.remove('streamsync_logged_in');
      await prefs.remove('streamsync_username');
      await prefs.remove('streamsync_email');
      await _loadProfileData();
    } catch (e) {
      debugPrint('Error logging out: $e');
    }
  }

  Future<void> selectProfile(String profileName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentProfile = profileName;
      await prefs.setString('streamsync_active_profile', profileName);
      await _loadProfileData();
    } catch (e) {
      debugPrint('Error switching profiles: $e');
    }
  }

  // ── Watchlist ─────────────────────────────────────────────────────────────

  Future<void> addToWatchlist(Map<String, dynamic> item) async {
    try {
      final id = item['id'] as int;
      if (_watchlistIds.contains(id)) return;

      _watchlist.add({
        'id': id,
        'title': item['title'] ?? item['name'] ?? 'Untitled',
        'poster_path': item['poster_path'],
        'media_type': item['media_type'] ?? 'movie',
        'rating': item['vote_average'],
        'overview': item['overview'],
        'release_date': item['release_date'],
        'genres': item['genres'] ?? [],
        'date_added': DateTime.now().toIso8601String(),
      });

      _watchlistIds.add(id);
      await _saveList("streamsync_${_activeScope}_watchlist", _watchlist);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding to watchlist: $e');
    }
  }

  Future<void> removeFromWatchlist(int id) async {
    try {
      _watchlist.removeWhere((x) => x['id'] == id);
      _watchlistIds.remove(id);
      await _saveList("streamsync_${_activeScope}_watchlist", _watchlist);
      notifyListeners();
    } catch (e) {
      debugPrint('Error removing from watchlist: $e');
    }
  }

  // NEW: Clear entire watchlist
  Future<void> clearWatchlist() async {
    try {
      _watchlist.clear();
      _watchlistIds.clear();
      await _saveList("streamsync_${_activeScope}_watchlist", _watchlist);
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing watchlist: $e');
    }
  }

  bool isInWatchlist(int id) => _watchlistIds.contains(id);

  // ── Watch History ─────────────────────────────────────────────────────────

  Future<void> addToHistory(Map<String, dynamic> item, {int? season, int? episode}) async {
    try {
      final id = item['id'] as int;
      final isNewEntry = !_watchHistory.any((x) => x['id'] == id);

      _watchHistory.removeWhere((x) => x['id'] == id);
      _watchHistory.insert(0, {
        'id': id,
        'title': item['title'] ?? item['name'] ?? 'Untitled',
        'poster_path': item['poster_path'],
        'media_type': item['media_type'] ?? 'movie',
        'overview': item['overview'],
        'vote_average': item['vote_average'],
        'season': season,
        'episode': episode,
        'progress_seconds': 0,
        'duration_seconds': 0,
        'last_watched': DateTime.now().toIso8601String(),
      });

      if (_watchHistory.length > 20) {
        _watchHistory.removeLast();
      }

      await _saveList("streamsync_${_activeScope}_history", _watchHistory);

      if (isNewEntry) {
        _totalHoursWatched += 2;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt("streamsync_${_activeScope}_watch_stats", _totalHoursWatched);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error adding to history: $e');
    }
  }

  Future<void> updateHistoryProgress(int id, int progress, int duration) async {
    try {
      final index = _watchHistory.indexWhere((x) => x['id'] == id);
      if (index != -1) {
        _watchHistory[index]['progress_seconds'] = progress;
        _watchHistory[index]['duration_seconds'] = duration;
        await _saveList("streamsync_${_activeScope}_history", _watchHistory);
        // Silent save - no notifyListeners to avoid UI rebuild during playback
      }
    } catch (e) {
      debugPrint('Error updating history progress: $e');
    }
  }

  Future<void> removeFromHistory(int id) async {
    try {
      _watchHistory.removeWhere((x) => x['id'] == id);
      await _saveList("streamsync_${_activeScope}_history", _watchHistory);
      notifyListeners();
    } catch (e) {
      debugPrint('Error removing from history: $e');
    }
  }

  // ── Downloads ─────────────────────────────────────────────────────────────

  Future<void> _loadDownloads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList("streamsync_${_activeScope}_downloads") ?? [];
      _downloads = data.map((d) => json.decode(d) as Map<String, dynamic>).toList();
      _rebuildIdCaches();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading downloads: $e');
    }
  }

  Future<void> addDownload(Map<String, dynamic> item) async {
    try {
      final id = item['id'] as int;
      if (_downloadIds.contains(id)) return;

      _downloads.add({
        'id': id,
        'title': item['title'] ?? item['name'] ?? 'Untitled',
        'poster_path': item['poster_path'],
        'media_type': item['media_type'] ?? 'movie',
        'seasons': item['seasons'] ?? [],
        'download_quality': item['download_quality'] ?? '1080p',
        'download_language': item['download_language'] ?? 'English',
        'download_date': DateTime.now().toIso8601String(),
        'local_file_path': item['local_file_path'],
        'file_size_bytes': item['file_size_bytes'],
      });

      _downloadIds.add(id);
      await _saveList("streamsync_${_activeScope}_downloads", _downloads);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving download: $e');
    }
  }

  Future<void> removeDownload(int id) async {
    try {
      final item = _downloads.firstWhere((d) => d['id'] == id, orElse: () => {});
      if (item.isNotEmpty && item['local_file_path'] != null) {
        try {
          final file = File(item['local_file_path'] as String);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('Error deleting local file: $e');
        }
      }

      _downloads.removeWhere((d) => d['id'] == id);
      _downloadIds.remove(id);
      await _saveList("streamsync_${_activeScope}_downloads", _downloads);
      notifyListeners();
    } catch (e) {
      debugPrint('Error removing download: $e');
    }
  }

  bool isDownloaded(int id) => _downloadIds.contains(id);

  // ── Settings ──────────────────────────────────────────────────────────────

  Future<void> registerResolvedUrl(int id, String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _resolvedUrls[id] = url;
      await prefs.setString('streamsync_resolved_url_$id', url);
      notifyListeners();
    } catch (e) {
      debugPrint('Error registering resolved URL: $e');
    }
  }

  Future<void> updateCountry(String countryCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _selectedCountry = countryCode;
      await prefs.setString('streamsync_country', countryCode);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating country: $e');
    }
  }

  Future<void> clearDatabase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scope = _activeScope;
      _watchlist.clear();
      _watchHistory.clear();
      _watchlistIds.clear();
      _totalHoursWatched = 0;

      await prefs.remove("streamsync_${scope}_watchlist");
      await prefs.remove("streamsync_${scope}_history");
      await prefs.remove("streamsync_${scope}_watch_stats");

      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing database: $e');
    }
  }

  Future<void> togglePremium() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isPremium = !_isPremium;
      await prefs.setBool('streamsync_premium', _isPremium);
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling premium: $e');
    }
  }

  Future<void> toggleNotifNewRelease(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _notifNewRelease = value;
      await prefs.setBool('streamsync_notif_new_release', value);
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling notification: $e');
    }
  }

  Future<void> toggleNotifTrending(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _notifTrending = value;
      await prefs.setBool('streamsync_notif_trending', value);
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling notification: $e');
    }
  }

  // ── Player Preferences ────────────────────────────────────────────────────

  Future<void> updateCaptionSize(double multiplier) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _captionSizeMultiplier = multiplier;
      await prefs.setDouble('streamsync_caption_size', multiplier);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating caption size: $e');
    }
  }

  Future<void> updateQuality(String quality) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _defaultQuality = quality;
      await prefs.setString('streamsync_quality', quality);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating quality: $e');
    }
  }

  Future<void> toggleAutoPlay(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoPlayNext = value;
      await prefs.setBool('streamsync_autoplay', value);
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling autoplay: $e');
    }
  }

  Future<void> updatePlaybackSpeed(double speed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _playbackSpeed = speed;
      await prefs.setDouble('streamsync_speed', speed);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating speed: $e');
    }
  }
}