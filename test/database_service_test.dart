import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamsync/services/database_service.dart';

Future<DatabaseService> _freshDb() async {
  SharedPreferences.setMockInitialValues({});
  final db = DatabaseService();
  // The constructor loads saved state asynchronously.
  while (db.isLoading) {
    await Future<void>.delayed(Duration.zero);
  }
  return db;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('movie and TV ids sharing a number', () {
    final movie = {'id': 1399, 'title': 'Some Movie', 'media_type': 'movie'};
    final show = {'id': 1399, 'name': 'Some Show', 'media_type': 'tv'};

    test('watchlist tracks them separately', () async {
      final db = await _freshDb();
      await db.addToWatchlist(show);

      expect(db.isInWatchlist(1399, mediaType: 'tv'), isTrue);
      expect(db.isInWatchlist(1399, mediaType: 'movie'), isFalse);

      await db.addToWatchlist(movie);
      expect(db.watchlist, hasLength(2));

      await db.removeFromWatchlist(1399, mediaType: 'movie');
      expect(db.isInWatchlist(1399, mediaType: 'movie'), isFalse);
      expect(db.isInWatchlist(1399, mediaType: 'tv'), isTrue);
    });

    test('history keeps both entries', () async {
      final db = await _freshDb();
      await db.addToHistory(movie);
      await db.addToHistory(show, season: 1, episode: 2);

      expect(db.watchHistory, hasLength(2));

      await db.removeFromHistory(1399, mediaType: 'tv');
      expect(db.watchHistory.single['media_type'], 'movie');
    });

    test('ratings are stored per media type', () async {
      final db = await _freshDb();
      await db.setRating(1399, 5, mediaType: 'movie');
      await db.setRating(1399, 2, mediaType: 'tv');

      expect(db.getRating(1399, mediaType: 'movie'), 5);
      expect(db.getRating(1399, mediaType: 'tv'), 2);
    });
  });

  test('watchlist survives a reload', () async {
    final db = await _freshDb();
    await db.addToWatchlist({'id': 42, 'title': 'Saved', 'media_type': 'movie'});

    final reloaded = DatabaseService();
    while (reloaded.isLoading) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(reloaded.isInWatchlist(42, mediaType: 'movie'), isTrue);
  });

  test('legacy ratings saved by bare id are still read', () async {
    SharedPreferences.setMockInitialValues({
      'streamsync_Enthusiast_ratings': '{"77": 4}',
    });
    final db = DatabaseService();
    while (db.isLoading) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(db.getRating(77, mediaType: 'movie'), 4);
  });

  test('data from the old local sign-in moves into the active profile', () async {
    SharedPreferences.setMockInitialValues({
      'streamsync_logged_in': true,
      'streamsync_username': 'saad',
      'streamsync_premium': true,
      'streamsync_auth_user_saad_watchlist': [
        '{"id": 7, "title": "Old", "media_type": "tv"}',
      ],
    });
    final db = DatabaseService();
    while (db.isLoading) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(db.isInWatchlist(7, mediaType: 'tv'), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('streamsync_logged_in'), isFalse);
    expect(prefs.containsKey('streamsync_premium'), isFalse);
  });
}
