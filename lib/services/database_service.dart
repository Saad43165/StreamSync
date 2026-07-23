import 'dart:convert';
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
      await _loadProfileData();
    } catch (e) {
      debugPrint('Error loading initial config: $e');
    }
  }

  // Load watchlist and watch history specifically for the active profile or logged-in account
  Future<void> _loadProfileData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeScope = _isLoggedIn ? 'auth_user_${_username}' : _currentProfile;
      final watchlistKey = 'streamsync_${activeScope}_watchlist';
      final historyKey = 'streamsync_${activeScope}_history';
      final statsKey = 'streamsync_${activeScope}_watch_stats';

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
      final activeScope = _isLoggedIn ? 'auth_user_${_username}' : _currentProfile;
      final watchlistKey = 'streamsync_${activeScope}_watchlist';
      final statsKey = 'streamsync_${activeScope}_watch_stats';

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

      _totalHoursWatched += 2; // Simulated watch hours
      await prefs.setInt(statsKey, _totalHoursWatched);

      notifyListeners();
    } catch (e) {
      debugPrint('Error adding to watchlist: $e');
    }
  }

  // Remove item from watchlist
  Future<void> removeFromWatchlist(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeScope = _isLoggedIn ? 'auth_user_${_username}' : _currentProfile;
      final watchlistKey = 'streamsync_${activeScope}_watchlist';
      final statsKey = 'streamsync_${activeScope}_watch_stats';

      _watchlist.removeWhere((x) => x['id'] == id);

      final stringList = _watchlist.map((x) => json.encode(x)).toList();
      await prefs.setStringList(watchlistKey, stringList);

      if (_totalHoursWatched >= 2) {
        _totalHoursWatched -= 2;
        await prefs.setInt(statsKey, _totalHoursWatched);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error removing from watchlist: $e');
    }
  }

  // Add item to Watch History ("Continue Watching" tracker)
  Future<void> addToHistory(Map<String, dynamic> item, {int? season, int? episode}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeScope = _isLoggedIn ? 'auth_user_${_username}' : _currentProfile;
      final historyKey = 'streamsync_${activeScope}_history';

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

      notifyListeners();
    } catch (e) {
      debugPrint('Error adding to history: $e');
    }
  }

  // Remove single history item
  Future<void> removeFromHistory(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeScope = _isLoggedIn ? 'auth_user_${_username}' : _currentProfile;
      final historyKey = 'streamsync_${activeScope}_history';

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
      final activeScope = _isLoggedIn ? 'auth_user_${_username}' : _currentProfile;
      final watchlistKey = 'streamsync_${activeScope}_watchlist';
      final historyKey = 'streamsync_${activeScope}_history';
      final statsKey = 'streamsync_${activeScope}_watch_stats';

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

  bool isInWatchlist(int id) {
    return _watchlist.any((x) => x['id'] == id);
  }
}
