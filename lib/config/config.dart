class AppConfig {
  // TMDB API key, supplied at build time so it stays out of source control:
  //   flutter run --dart-define=TMDB_API_KEY=your_key
  // Get a free key at themoviedb.org -> Account Settings -> API.
  // The default below is the key that was previously committed; it is public
  // now, so rotate it on TMDB and then delete this fallback.
  static const String tmdbApiKey = String.fromEnvironment(
    'TMDB_API_KEY',
    defaultValue: '8cff1ba156c2506739995d8e71f2b5dc',
  );

  // Default region for watching providers (US, IN, GB, etc.)
  static const String defaultRegion = 'US';

  // App version
  static const String appVersion = '3.0.0';
}
