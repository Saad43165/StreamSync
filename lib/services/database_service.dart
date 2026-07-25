import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseService extends ChangeNotifier {
  List<Map<String, dynamic>> _watchlist = [];
  List<Map<String, dynamic>> get watchlist => _watchlist;

  List<Map<String, dynamic>> _watchHistory = [];
  List<Map<String, dynamic>> get watchHistory => _watchHistory;

  int _totalHoursWatched = 0;
  int get totalHoursWatched => _totalHoursWatched;

  String _selectedCountry = 'US'; // Default country is US
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
  List<Map<String, dynamic>> get downloads => _downloads;

  final Map<int, String> _resolvedUrls = {};
  Map<int, String> get resolvedUrls => _resolvedUrls;

  // Multi-Profile & Auth system
  String _currentProfile = 'Enthusiast';
  String get currentProfile => _currentProfile;

  final List<String> _profiles = ['Enthusiast', 'Family', 'Kids'];
  List<String> get profiles => _profiles;

  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  String _username = '';
  String get username => _username;

  String _email = '';
  String get email => _email;

  DatabaseService() {
    _loadInitialConfig();
  }

  // Load the current active profile first
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
    } catch (e) {
      debugPrint('Error loading initial config: $e');
    }
  }

  // Load watchlist and watch history specifically for the active profile or logged-in account
  Future<void> _loadProfileData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeScope = _isLoggedIn ? "auth_user_$username" : _currentProfile;
      final watchlistKey = "streamsync_${activeScope}_watchlist";
      final historyKey = "streamsync_${activeScope}_history";
      final statsKey = "streamsync_${activeScope}_watch_stats";

      final watchlistData = prefs.getStringList(watchlistKey) ?? [];
      _watchlist = watchlistData
          .map((item) => json.decode(item) as Map<String, dynamic>)
          .toList();

      final historyData = prefs.getStringList(historyKey) ?? [];
      _watchHistory = historyData
          .map((item) => json.decode(item) as Map<String, dynamic>)
          .toList();

      _totalHoursWatched = prefs.getInt(statsKey) ?? 0;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading profile data: $e');
    }
  }

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

  // Switch between profiles
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

  // Add item to watchlist
  Future<void> addToWatchlist(Map<String, dynamic> item) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeScope = _isLoggedIn ? "auth_user_$username" : _currentProfile;
      final watchlistKey = "streamsync_${activeScope}_watchlist";

      final exists = _watchlist.any((x) => x['id'] == item['id']);
      if (exists) return;

      _watchlist.add({
        'id': item['id'],
        'title': item['title'],
        'poster_path': item['poster_path'],
        'media_type': item['media_type'] ?? 'movie',
        'rating': item['vote_average'],
        'genres': item['genres'] ?? [],
        'date_added': DateTime.now().toIso8601String(),
      });

      final stringList = _watchlist.map((x) => json.encode(x)).toList();
      await prefs.setStringList(watchlistKey, stringList);

      notifyListeners();
    } catch (e) {
      debugPrint('Error adding to watchlist: $e');
    }
  }

  // Remove item from watchlist
  Future<void> removeFromWatchlist(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeScope = _isLoggedIn ? "auth_user_$username" : _currentProfile;
      final watchlistKey = "streamsync_${activeScope}_watchlist";

      _watchlist.removeWhere((x) => x['id'] == id);

      final stringList = _watchlist.map((x) => json.encode(x)).toList();
      await prefs.setStringList(watchlistKey, stringList);

      notifyListeners();
    } catch (e) {
      debugPrint('Error removing from watchlist: $e');
    }
  }

  // Add item to Watch History ("Continue Watching" tracker)
  Future<void> addToHistory(Map<String, dynamic> item, {int? season, int? episode}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeScope = _isLoggedIn ? "auth_user_$username" : _currentProfile;
      final historyKey = "streamsync_${activeScope}_history";
      final statsKey = "streamsync_${activeScope}_watch_stats";

      _watchHistory.removeWhere((x) => x['id'] == item['id']); // Move to top of list if played again
      _watchHistory.insert(0, {
        'id': item['id'],
        'title': item['title'],
        'poster_path': item['poster_path'],
        'media_type': item['media_type'] ?? 'movie',
        'season': season,
        'episode': episode,
        'last_watched': DateTime.now().toIso8601String(),
      });

      if (_watchHistory.length > 10) {
        _watchHistory.removeLast(); // Limit history to last 10 titles
      }

      final stringList = _watchHistory.map((x) => json.encode(x)).toList();
      await prefs.setStringList(historyKey, stringList);

      // Increment watch stats when user actually streams the title
      _totalHoursWatched += 2; // Increments actual watch metrics
      await prefs.setInt(statsKey, _totalHoursWatched);

      notifyListeners();
    } catch (e) {
      debugPrint('Error adding to history: $e');
    }
  }

  // Save parsed streaming URL cache to disk dynamically
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

  // Remove single history item
  Future<void> removeFromHistory(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeScope = _isLoggedIn ? "auth_user_$username" : _currentProfile;
      final historyKey = "streamsync_${activeScope}_history";

      _watchHistory.removeWhere((x) => x['id'] == id);

      final stringList = _watchHistory.map((x) => json.encode(x)).toList();
      await prefs.setStringList(historyKey, stringList);

      notifyListeners();
    } catch (e) {
      debugPrint('Error removing from history: $e');
    }
  }

  // Update selected country
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

  // Reset profile database
  Future<void> clearDatabase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeScope = _isLoggedIn ? "auth_user_$username" : _currentProfile;
      final watchlistKey = "streamsync_${activeScope}_watchlist";
      final historyKey = "streamsync_${activeScope}_history";
      final statsKey = "streamsync_${activeScope}_watch_stats";

      _watchlist.clear();
      _watchHistory.clear();
      _totalHoursWatched = 0;

      await prefs.remove(watchlistKey);
      await prefs.remove(historyKey);
      await prefs.remove(statsKey);

      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing database: $e');
    }
  }

  // Toggle premium state (global across profiles)
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

  // Toggle notification preferences
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

  // Update Player Preferences
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

  bool isInWatchlist(int id) {
    return _watchlist.any((x) => x['id'] == id);
  }

  // Download actions
  Future<void> _loadDownloads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeScope = _isLoggedIn ? "auth_user_$username" : _currentProfile;
      final data = prefs.getStringList("streamsync_${activeScope}_downloads") ?? [];
      _downloads = data.map((d) => json.decode(d) as Map<String, dynamic>).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading downloads: $e');
    }
  }

  Future<void> addDownload(Map<String, dynamic> item) async {
    try {
      if (_downloads.any((d) => d['id'] == item['id'])) return;
      final prefs = await SharedPreferences.getInstance();
      final activeScope = _isLoggedIn ? "auth_user_$username" : _currentProfile;

      _downloads.add({
        'id': item['id'],
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

      final stringList = _downloads.map((d) => json.encode(d)).toList();
      await prefs.setStringList("streamsync_${activeScope}_downloads", stringList);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving download: $e');
    }
  }

  Future<void> removeDownload(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeScope = _isLoggedIn ? "auth_user_$username" : _currentProfile;
      
      // Attempt to physically delete the downloaded file from local storage
      final item = _downloads.firstWhere((d) => d['id'] == id, orElse: () => {});
      if (item.isNotEmpty && item['local_file_path'] != null) {
        try {
          final file = File(item['local_file_path'] as String);
          if (await file.exists()) {
            await file.delete();
            debugPrint('Physical download file deleted: ${item['local_file_path']}');
          }
        } catch (e) {
          debugPrint('Error deleting local file from storage: $e');
        }
      }

      _downloads.removeWhere((d) => d['id'] == id);
      final stringList = _downloads.map((d) => json.encode(d)).toList();
      await prefs.setStringList("streamsync_${activeScope}_downloads", stringList);
      notifyListeners();
    } catch (e) {
      debugPrint('Error removing download: $e');
    }
  }

  bool isDownloaded(int id) {
    return _downloads.any((d) => d['id'] == id);
  }
}
