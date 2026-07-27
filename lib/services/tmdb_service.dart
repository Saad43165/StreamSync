import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import '../config/config.dart';

class TMDBService extends ChangeNotifier {
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  // FIXED: Increased from w500 to w780 for sharper posters on retina displays
  static const String imageBaseUrl = 'https://image.tmdb.org/t/p/w780';
  static const String backdropBaseUrl = 'https://image.tmdb.org/t/p/original';

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<dynamic> _trending = [];
  List<dynamic> get trending => _trending;

  List<dynamic> _movies = [];
  List<dynamic> get movies => _movies;

  List<dynamic> _series = [];
  List<dynamic> get series => _series;

  List<dynamic> _netflix = [];
  List<dynamic> get netflix => _netflix;

  List<dynamic> _prime = [];
  List<dynamic> get prime => _prime;

  List<dynamic> _disney = [];
  List<dynamic> get disney => _disney;

  List<dynamic> _actionMovies = [];
  List<dynamic> get actionMovies => _actionMovies;

  List<dynamic> _comedyMovies = [];
  List<dynamic> get comedyMovies => _comedyMovies;

  List<dynamic> _scifiMovies = [];
  List<dynamic> get scifiMovies => _scifiMovies;

  List<dynamic> _horrorMovies = [];
  List<dynamic> get horrorMovies => _horrorMovies;

  List<dynamic> _upcoming = [];
  List<dynamic> get upcoming => _upcoming;

  List<dynamic> _bollywood = [];
  List<dynamic> get bollywood => _bollywood;

  List<dynamic> _pakistani = [];
  List<dynamic> get pakistani => _pakistani;

  List<dynamic> _searchResults = [];
  List<dynamic> get searchResults => _searchResults;

  bool get hasApiKey => AppConfig.tmdbApiKey.isNotEmpty;

  // ── Dedicated Upcoming Releases state (paginated, real API only) ─────────
  final List<dynamic> _upcomingMoviesFeed = [];
  List<dynamic> get upcomingMoviesFeed => _upcomingMoviesFeed;
  int _upcomingMoviesPage = 0;
  int _upcomingMoviesTotalPages = 1;
  bool _isLoadingUpcomingMovies = false;
  bool get isLoadingUpcomingMovies => _isLoadingUpcomingMovies;
  bool get hasMoreUpcomingMovies => _upcomingMoviesPage < _upcomingMoviesTotalPages;
  bool _upcomingMoviesErrored = false;
  bool get upcomingMoviesErrored => _upcomingMoviesErrored;

  final List<dynamic> _upcomingTvFeed = [];
  List<dynamic> get upcomingTvFeed => _upcomingTvFeed;
  int _upcomingTvPage = 0;
  int _upcomingTvTotalPages = 1;
  bool _isLoadingUpcomingTv = false;
  bool get isLoadingUpcomingTv => _isLoadingUpcomingTv;
  bool get hasMoreUpcomingTv => _upcomingTvPage < _upcomingTvTotalPages;
  bool _upcomingTvErrored = false;
  bool get upcomingTvErrored => _upcomingTvErrored;

  static const Map<int, String> _movieGenreNames = {
    28: 'Action', 12: 'Adventure', 16: 'Animation', 35: 'Comedy',
    80: 'Crime', 99: 'Documentary', 18: 'Drama', 10751: 'Family',
    14: 'Fantasy', 36: 'History', 27: 'Horror', 10402: 'Music',
    9648: 'Mystery', 10749: 'Romance', 878: 'Sci-Fi', 10770: 'TV Movie',
    53: 'Thriller', 10752: 'War', 37: 'Western',
  };
  static const Map<int, String> _tvGenreNames = {
    10759: 'Action & Adventure', 16: 'Animation', 35: 'Comedy', 80: 'Crime',
    99: 'Documentary', 18: 'Drama', 10751: 'Family', 10762: 'Kids',
    9648: 'Mystery', 10763: 'News', 10764: 'Reality',
    10765: 'Sci-Fi & Fantasy', 10766: 'Soap', 10767: 'Talk',
    10768: 'War & Politics', 37: 'Western',
  };

  static List<String> genreNamesFor(Map<String, dynamic> item) {
    final isTv = item['media_type'] == 'tv';
    final ids = (item['genre_ids'] as List<dynamic>? ?? []).cast<int>();
    final map = isTv ? _tvGenreNames : _movieGenreNames;
    return ids.map((id) => map[id]).whereType<String>().toList();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> fetchTrending() async {
    if (!hasApiKey) {
      _trending = _getMockTrending();
      _movies = _getMockMovies();
      _series = _getMockSeries();
      _netflix = _getMockNetflix();
      _prime = _getMockPrime();
      _disney = _getMockDisney();
      _actionMovies = _getMockAction();
      _comedyMovies = _getMockComedy();
      _scifiMovies = _getMockSciFi();
      _horrorMovies = _getMockHorror();
      _upcoming = _getMockUpcoming();
      _bollywood = _getMockMovies();
      _pakistani = _getMockSeries();
      notifyListeners();
      return;
    }

    try {
      final cacheBox = Hive.box('tmdb_cache_box');
      final cachedStr = cacheBox.get('categories_cache') as String?;
      if (cachedStr != null) {
        final decoded = json.decode(cachedStr) as Map<String, dynamic>;
        _trending = decoded['trending'] ?? [];
        _movies = decoded['movies'] ?? [];
        _series = decoded['series'] ?? [];
        _netflix = decoded['netflix'] ?? [];
        _prime = decoded['prime'] ?? [];
        _disney = decoded['disney'] ?? [];
        _actionMovies = decoded['actionMovies'] ?? [];
        _comedyMovies = decoded['comedyMovies'] ?? [];
        _scifiMovies = decoded['scifiMovies'] ?? [];
        _horrorMovies = decoded['horrorMovies'] ?? [];
        _upcoming = decoded['upcoming'] ?? [];
        _bollywood = decoded['bollywood'] ?? [];
        _pakistani = decoded['pakistani'] ?? [];
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error reading Hive categories cache: $e');
    }

    _setLoading(true);
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('$_baseUrl/trending/all/day?api_key=${AppConfig.tmdbApiKey}')).timeout(const Duration(seconds: 15)),
        http.get(Uri.parse('$_baseUrl/discover/movie?api_key=${AppConfig.tmdbApiKey}&sort_by=popularity.desc')).timeout(const Duration(seconds: 15)),
        http.get(Uri.parse('$_baseUrl/discover/tv?api_key=${AppConfig.tmdbApiKey}&sort_by=popularity.desc')).timeout(const Duration(seconds: 15)),
        http.get(Uri.parse('$_baseUrl/discover/movie?api_key=${AppConfig.tmdbApiKey}&with_watch_providers=8&watch_region=US&sort_by=popularity.desc')).timeout(const Duration(seconds: 15)),
        http.get(Uri.parse('$_baseUrl/discover/movie?api_key=${AppConfig.tmdbApiKey}&with_watch_providers=9&watch_region=US&sort_by=popularity.desc')).timeout(const Duration(seconds: 15)),
        http.get(Uri.parse('$_baseUrl/discover/movie?api_key=${AppConfig.tmdbApiKey}&with_watch_providers=337&watch_region=US&sort_by=popularity.desc')).timeout(const Duration(seconds: 15)),
        http.get(Uri.parse('$_baseUrl/discover/movie?api_key=${AppConfig.tmdbApiKey}&with_genres=28&sort_by=popularity.desc')).timeout(const Duration(seconds: 15)),
        http.get(Uri.parse('$_baseUrl/discover/movie?api_key=${AppConfig.tmdbApiKey}&with_genres=35&sort_by=popularity.desc')).timeout(const Duration(seconds: 15)),
        http.get(Uri.parse('$_baseUrl/discover/movie?api_key=${AppConfig.tmdbApiKey}&with_genres=878&sort_by=popularity.desc')).timeout(const Duration(seconds: 15)),
        http.get(Uri.parse('$_baseUrl/discover/movie?api_key=${AppConfig.tmdbApiKey}&with_genres=27&sort_by=popularity.desc')).timeout(const Duration(seconds: 15)),
        http.get(Uri.parse('$_baseUrl/movie/upcoming?api_key=${AppConfig.tmdbApiKey}')).timeout(const Duration(seconds: 15)),
        http.get(Uri.parse('$_baseUrl/discover/movie?api_key=${AppConfig.tmdbApiKey}&with_original_language=hi&sort_by=popularity.desc')).timeout(const Duration(seconds: 15)),
        http.get(Uri.parse('$_baseUrl/discover/tv?api_key=${AppConfig.tmdbApiKey}&with_original_language=ur&sort_by=popularity.desc')).timeout(const Duration(seconds: 15)),
      ]);

      final trendingRes = responses[0];
      if (trendingRes.statusCode == 200) {
        final data = json.decode(trendingRes.body);
        final results = data['results'] as List<dynamic>? ?? [];
        _trending = results.where((item) =>
        item['media_type'] == 'movie' || item['media_type'] == 'tv'
        ).toList();
      }

      final moviesRes = responses[1];
      if (moviesRes.statusCode == 200) {
        final data = json.decode(moviesRes.body);
        _movies = (data['results'] as List<dynamic>? ?? []).map((item) {
          item['media_type'] = 'movie';
          return item;
        }).toList();
      }

      final seriesRes = responses[2];
      if (seriesRes.statusCode == 200) {
        final data = json.decode(seriesRes.body);
        _series = (data['results'] as List<dynamic>? ?? []).map((item) {
          item['media_type'] = 'tv';
          return item;
        }).toList();
      }

      final netflixRes = responses[3];
      if (netflixRes.statusCode == 200) {
        final data = json.decode(netflixRes.body);
        _netflix = (data['results'] as List<dynamic>? ?? []).map((item) {
          item['media_type'] = 'movie';
          return item;
        }).toList();
      }

      final primeRes = responses[4];
      if (primeRes.statusCode == 200) {
        final data = json.decode(primeRes.body);
        _prime = (data['results'] as List<dynamic>? ?? []).map((item) {
          item['media_type'] = 'movie';
          return item;
        }).toList();
      }

      final disneyRes = responses[5];
      if (disneyRes.statusCode == 200) {
        final data = json.decode(disneyRes.body);
        _disney = (data['results'] as List<dynamic>? ?? []).map((item) {
          item['media_type'] = 'movie';
          return item;
        }).toList();
      }

      final actionRes = responses[6];
      if (actionRes.statusCode == 200) {
        final data = json.decode(actionRes.body);
        _actionMovies = (data['results'] as List<dynamic>? ?? []).map((item) {
          item['media_type'] = 'movie';
          return item;
        }).toList();
      }

      final comedyRes = responses[7];
      if (comedyRes.statusCode == 200) {
        final data = json.decode(comedyRes.body);
        _comedyMovies = (data['results'] as List<dynamic>? ?? []).map((item) {
          item['media_type'] = 'movie';
          return item;
        }).toList();
      }

      final scifiRes = responses[8];
      if (scifiRes.statusCode == 200) {
        final data = json.decode(scifiRes.body);
        _scifiMovies = (data['results'] as List<dynamic>? ?? []).map((item) {
          item['media_type'] = 'movie';
          return item;
        }).toList();
      }

      final horrorRes = responses[9];
      if (horrorRes.statusCode == 200) {
        final data = json.decode(horrorRes.body);
        _horrorMovies = (data['results'] as List<dynamic>? ?? []).map((item) {
          item['media_type'] = 'movie';
          return item;
        }).toList();
      }

      final upcomingRes = responses[10];
      if (upcomingRes.statusCode == 200) {
        final data = json.decode(upcomingRes.body);
        final results = data['results'] as List<dynamic>? ?? [];
        final nowStr = DateTime.now().toIso8601String().split('T').first;
        _upcoming = results.where((item) {
          final relDate = item['release_date'] as String? ?? '';
          return relDate.isNotEmpty && relDate.compareTo(nowStr) > 0;
        }).map((item) {
          item['media_type'] = 'movie';
          return item;
        }).toList();
        if (_upcoming.isEmpty) {
          _upcoming = results.map((item) {
            item['media_type'] = 'movie';
            return item;
          }).toList();
        }
      }

      final bollywoodRes = responses[11];
      if (bollywoodRes.statusCode == 200) {
        final data = json.decode(bollywoodRes.body);
        _bollywood = (data['results'] as List<dynamic>? ?? []).map((item) {
          item['media_type'] = 'movie';
          return item;
        }).toList();
      }

      final pakistaniRes = responses[12];
      if (pakistaniRes.statusCode == 200) {
        final data = json.decode(pakistaniRes.body);
        _pakistani = (data['results'] as List<dynamic>? ?? []).map((item) {
          item['media_type'] = 'tv';
          return item;
        }).toList();
      }

      final cacheBox = Hive.box('tmdb_cache_box');
      final payload = {
        'trending': _trending,
        'movies': _movies,
        'series': _series,
        'netflix': _netflix,
        'prime': _prime,
        'disney': _disney,
        'actionMovies': _actionMovies,
        'comedyMovies': _comedyMovies,
        'scifiMovies': _scifiMovies,
        'horrorMovies': _horrorMovies,
        'upcoming': _upcoming,
        'bollywood': _bollywood,
        'pakistani': _pakistani,
      };
      await cacheBox.put('categories_cache', json.encode(payload));
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching/saving parallel categories queries: $e');
      await _loadTrendingFromCache();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadTrendingFromCache() async {
    try {
      final cacheBox = Hive.box('tmdb_cache_box');
      final cachedStr = cacheBox.get('categories_cache') as String?;
      if (cachedStr != null) {
        final decoded = json.decode(cachedStr) as Map<String, dynamic>;
        _trending = decoded['trending'] ?? [];
        _movies = decoded['movies'] ?? [];
        _series = decoded['series'] ?? [];
        _netflix = decoded['netflix'] ?? [];
        _prime = decoded['prime'] ?? [];
        _disney = decoded['disney'] ?? [];
        _actionMovies = decoded['actionMovies'] ?? [];
        _comedyMovies = decoded['comedyMovies'] ?? [];
        _scifiMovies = decoded['scifiMovies'] ?? [];
        _horrorMovies = decoded['horrorMovies'] ?? [];
        _upcoming = decoded['upcoming'] ?? [];
        _bollywood = decoded['bollywood'] ?? [];
        _pakistani = decoded['pakistani'] ?? [];
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error parsing offline trending cache: $e');
    }
  }

  Future<void> fetchUpcomingMovies({bool loadMore = false}) async {
    if (_isLoadingUpcomingMovies) return;
    if (loadMore && !hasMoreUpcomingMovies) return;

    if (!loadMore) {
      _upcomingMoviesPage = 0;
      _upcomingMoviesTotalPages = 1;
      _upcomingMoviesFeed.clear();
      _upcomingMoviesErrored = false;
    }

    if (!hasApiKey) {
      _upcomingMoviesFeed
        ..clear()
        ..addAll(_getMockUpcoming());
      _upcomingMoviesPage = 1;
      _upcomingMoviesTotalPages = 1;
      notifyListeners();
      return;
    }

    _isLoadingUpcomingMovies = true;
    notifyListeners();

    final nextPage = _upcomingMoviesPage + 1;
    try {
      final res = await http
          .get(Uri.parse(
          '$_baseUrl/movie/upcoming?api_key=${AppConfig.tmdbApiKey}&page=$nextPage'))
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final results = (data['results'] as List<dynamic>? ?? []);
        final nowStr = DateTime.now().toIso8601String().split('T').first;

        final futureOnly = results.where((item) {
          final relDate = item['release_date'] as String? ?? '';
          return relDate.isNotEmpty && relDate.compareTo(nowStr) >= 0;
        }).map((item) {
          item['media_type'] = 'movie';
          return item;
        }).toList();

        _upcomingMoviesFeed.addAll(futureOnly);
        _upcomingMoviesFeed.sort((a, b) =>
            (a['release_date'] as String? ?? '').compareTo(b['release_date'] as String? ?? ''));

        _upcomingMoviesPage = nextPage;
        _upcomingMoviesTotalPages = data['total_pages'] as int? ?? nextPage;
        _upcomingMoviesErrored = false;
      } else {
        _upcomingMoviesErrored = true;
      }
    } catch (e) {
      debugPrint('Error fetching upcoming movies: $e');
      _upcomingMoviesErrored = true;
    } finally {
      _isLoadingUpcomingMovies = false;
      notifyListeners();
    }
  }

  Future<void> fetchUpcomingTv({bool loadMore = false}) async {
    if (_isLoadingUpcomingTv) return;
    if (loadMore && !hasMoreUpcomingTv) return;

    if (!loadMore) {
      _upcomingTvPage = 0;
      _upcomingTvTotalPages = 1;
      _upcomingTvFeed.clear();
      _upcomingTvErrored = false;
    }

    if (!hasApiKey) {
      _upcomingTvFeed
        ..clear()
        ..addAll(_getMockUpcomingTv());
      _upcomingTvPage = 1;
      _upcomingTvTotalPages = 1;
      notifyListeners();
      return;
    }

    _isLoadingUpcomingTv = true;
    notifyListeners();

    final nextPage = _upcomingTvPage + 1;
    final todayStr = DateTime.now().toIso8601String().split('T').first;
    try {
      final res = await http
          .get(Uri.parse(
          '$_baseUrl/discover/tv?api_key=${AppConfig.tmdbApiKey}'
              '&first_air_date.gte=$todayStr'
              '&sort_by=first_air_date.asc'
              '&page=$nextPage'))
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final results = (data['results'] as List<dynamic>? ?? []).map((item) {
          item['media_type'] = 'tv';
          return item;
        }).toList();

        _upcomingTvFeed.addAll(results);
        _upcomingTvFeed.sort((a, b) => (a['first_air_date'] as String? ?? '')
            .compareTo(b['first_air_date'] as String? ?? ''));

        _upcomingTvPage = nextPage;
        _upcomingTvTotalPages = data['total_pages'] as int? ?? nextPage;
        _upcomingTvErrored = false;
      } else {
        _upcomingTvErrored = true;
      }
    } catch (e) {
      debugPrint('Error fetching upcoming tv: $e');
      _upcomingTvErrored = true;
    } finally {
      _isLoadingUpcomingTv = false;
      notifyListeners();
    }
  }

  Future<List<dynamic>> fetchRecommendations(int id, String mediaType) async {
    if (!hasApiKey) {
      return _getMockTrending().take(4).toList();
    }
    try {
      final res = await http.get(Uri.parse('$_baseUrl/$mediaType/$id/recommendations?api_key=${AppConfig.tmdbApiKey}')).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final results = data['results'] as List<dynamic>? ?? [];
        return results.map((item) {
          item['media_type'] = mediaType;
          return item;
        }).toList();
      }
    } catch (e) {
      debugPrint('Error fetching TMDB recommendations: $e');
    }
    return [];
  }

  Future<void> search(String query) async {
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    if (!hasApiKey) {
      _searchResults = _getMockTrending().where((element) =>
          (element['title'] ?? element['name'] ?? '').toString().toLowerCase().contains(query.toLowerCase())
      ).toList();
      notifyListeners();
      return;
    }

    _setLoading(true);
    try {
      final response = await http.get(Uri.parse(
          '$_baseUrl/search/multi?api_key=${AppConfig.tmdbApiKey}&query=${Uri.encodeComponent(query)}'
      ));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>? ?? [];
        _searchResults = results.where((item) =>
        item['media_type'] == 'movie' || item['media_type'] == 'tv'
        ).toList();
      }
    } catch (e) {
      debugPrint('Error searching TMDB: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>?> fetchDetails(int id, String mediaType, String countryCode) async {
    if (!hasApiKey) {
      return _getMockDetails(id, mediaType, countryCode);
    }

    try {
      final response = await http.get(Uri.parse(
          '$_baseUrl/$mediaType/$id?api_key=${AppConfig.tmdbApiKey}&append_to_response=videos,watch/providers,credits'
      )).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        try {
          return _parseDetails(data, countryCode);
        } catch (e, st) {
          debugPrint('Error parsing details payload for id=$id ($mediaType): $e\n$st');
          return null;
        }
      } else {
        debugPrint('fetchDetails non-200 for id=$id: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching details for id=$id: $e');
    }
    return null;
  }

  List<Map<String, String>> _mapProviders(List<dynamic> list) {
    return list.whereType<Map>().map((p) {
      final rawLogo = p['logo_path'];
      final logoPath = (rawLogo is String && rawLogo.isNotEmpty)
          ? imageBaseUrl + rawLogo
          : '';
      final rawName = p['provider_name'];
      final name = (rawName is String && rawName.isNotEmpty)
          ? rawName
          : 'Provider';
      return <String, String>{
        'provider_name': name,
        'logo_path': logoPath,
      };
    }).toList();
  }

  Map<String, dynamic> _parseDetails(Map<String, dynamic> data, String countryCode) {
    final providersWrapper = data['watch/providers'];
    final Map<String, dynamic> providersData =
    (providersWrapper is Map<String, dynamic>) ? (providersWrapper['results'] ?? {}) : {};

    final regionProviders = providersData[countryCode];
    final Map<String, dynamic> regionMap =
    (regionProviders is Map<String, dynamic>) ? regionProviders : {};

    final List<dynamic> freeProviders = regionMap['free'] is List ? regionMap['free'] : [];
    final List<dynamic> adsProviders = regionMap['ads'] is List ? regionMap['ads'] : [];
    final List<dynamic> subscriptionProviders = regionMap['flatrate'] is List ? regionMap['flatrate'] : [];

    final videosWrapper = data['videos'];
    final List<dynamic> videos =
    (videosWrapper is Map<String, dynamic>) ? (videosWrapper['results'] ?? []) : [];

    final dynamic trailerVideo = videos.firstWhere(
          (video) => video is Map && video['type'] == 'Trailer' && video['site'] == 'YouTube',
      orElse: () => videos.isNotEmpty ? videos.first : null,
    );

    final creditsWrapper = data['credits'];
    final List<dynamic> rawCastList =
    (creditsWrapper is Map<String, dynamic>) ? (creditsWrapper['cast'] ?? []) : [];
    final List<dynamic> castList =
    rawCastList.whereType<Map>().map((c) => Map<String, dynamic>.from(c)).toList();

    double voteAverage = 0.0;
    if (data['vote_average'] is num) {
      voteAverage = (data['vote_average'] as num).toDouble();
    }

    final rawGenres = data['genres'];
    final List<String> genreNames = (rawGenres is List)
        ? rawGenres
        .whereType<Map>()
        .map((g) => g['name']?.toString())
        .whereType<String>()
        .toList()
        : <String>[];

    final rawSeasons = data['seasons'];
    final List<dynamic> safeSeasons = (rawSeasons is List) ? rawSeasons : <dynamic>[];

    return {
      'id': data['id'],
      'title': data['title'] ?? data['name'] ?? 'Untitled',
      'overview': data['overview'] ?? '',
      'backdrop_path': (data['backdrop_path'] is String)
          ? backdropBaseUrl + data['backdrop_path']
          : null,
      'poster_path': (data['poster_path'] is String)
          ? imageBaseUrl + data['poster_path']
          : null,
      'vote_average': voteAverage,
      'release_date': data['release_date'] ?? data['first_air_date'] ?? 'N/A',
      'genres': genreNames,
      'seasons': safeSeasons,
      'trailer_id': (trailerVideo is Map) ? trailerVideo['key'] : null,
      'cast': castList,
      'free_options': _mapProviders([...freeProviders, ...adsProviders]),
      'subscription_options': _mapProviders(subscriptionProviders),
    };
  }

  // --- Mock Generators for Demo Mode ---
  List<dynamic> _getMockTrending() {
    return [
      ..._getMockMovies(),
      ..._getMockSeries()
    ];
  }

  List<dynamic> _getMockMovies() {
    return [
      {
        'id': 1,
        'title': 'Gladiator II',
        'media_type': 'movie',
        'poster_path': 'https://images.unsplash.com/photo-1594909122845-11baa439b7bf?w=1000',
        'backdrop_path': 'https://images.unsplash.com/photo-1594909122845-11baa439b7bf?w=1200',
        'vote_average': 7.8,
        'release_date': '2024-11-22',
        'overview': 'Years after witnessing the death of the revered hero Maximus at the hands of his uncle, Lucius is forced to enter the Colosseum.'
      },
      {
        'id': 2,
        'title': 'Dune: Part Two',
        'media_type': 'movie',
        'poster_path': 'https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=1000',
        'backdrop_path': 'https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=1200',
        'vote_average': 8.5,
        'release_date': '2024-03-01',
        'overview': 'Paul Atreides unites with Chani and the Fremen while seeking revenge against the conspirators who destroyed his family.'
      },
      {
        'id': 4,
        'title': 'The Dark Knight',
        'media_type': 'movie',
        'poster_path': 'https://images.unsplash.com/photo-1478760329108-5c3ed9d495a0?w=1000',
        'backdrop_path': 'https://images.unsplash.com/photo-1478760329108-5c3ed9d495a0?w=1200',
        'vote_average': 9.0,
        'release_date': '2008-07-18',
        'overview': 'Batman raises the stakes in his war on crime. With the help of Lt. Jim Gordon and District Attorney Harvey Dent, Batman sets out to dismantle the remaining criminal organizations.'
      }
    ];
  }

  List<dynamic> _getMockSeries() {
    return [
      {
        'id': 3,
        'name': 'Stranger Things',
        'media_type': 'tv',
        'poster_path': 'https://images.unsplash.com/photo-1618336753974-aae8e04506aa?w=1000',
        'backdrop_path': 'https://images.unsplash.com/photo-1618336753974-aae8e04506aa?w=1200',
        'vote_average': 8.6,
        'first_air_date': '2016-07-15',
        'overview': 'When a young boy vanishes, a small town uncovers a mystery involving secret experiments, terrifying supernatural forces and one strange little girl.'
      },
      {
        'id': 5,
        'name': 'Breaking Bad',
        'media_type': 'tv',
        'poster_path': 'https://images.unsplash.com/photo-1594909122845-11baa439b7bf?w=1000',
        'backdrop_path': 'https://images.unsplash.com/photo-1594909122845-11baa439b7bf?w=1200',
        'vote_average': 9.5,
        'first_air_date': '2008-01-20',
        'overview': 'A high school chemistry teacher diagnosed with inoperable lung cancer turns to manufacturing and selling methamphetamine.'
      }
    ];
  }

  List<dynamic> _getMockNetflix() => _getMockSeries();
  List<dynamic> _getMockPrime() => _getMockMovies();
  List<dynamic> _getMockDisney() => _getMockMovies().reversed.toList();
  List<dynamic> _getMockAction() => _getMockMovies();
  List<dynamic> _getMockComedy() => _getMockMovies();
  List<dynamic> _getMockSciFi() => _getMockMovies().skip(1).toList();
  List<dynamic> _getMockHorror() => _getMockMovies().reversed.toList();
  List<dynamic> _getMockUpcoming() {
    return [
      {
        'id': 101,
        'title': 'Avatar 3: Fire and Ash',
        'media_type': 'movie',
        'poster_path': 'https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=1000',
        'backdrop_path': 'https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=1200',
        'vote_average': 0.0,
        'release_date': '2026-12-18',
        'overview': 'The upcoming epic science fiction film co-produced, co-written, co-edited and directed by James Cameron set on Pandora.'
      },
      {
        'id': 102,
        'title': 'Avengers: Doomsday',
        'media_type': 'movie',
        'poster_path': 'https://images.unsplash.com/photo-1478760329108-5c3ed9d495a0?w=1000',
        'backdrop_path': 'https://images.unsplash.com/photo-1478760329108-5c3ed9d495a0?w=1200',
        'vote_average': 0.0,
        'release_date': '2026-05-01',
        'overview': 'An upcoming American superhero film based on the Marvel Comics superhero team the Avengers, featuring Robert Downey Jr. as Doctor Doom.'
      }
    ];
  }

  List<dynamic> _getMockUpcomingTv() {
    return [
      {
        'id': 201,
        'name': 'Stranger Things: Season 5',
        'media_type': 'tv',
        'poster_path': 'https://images.unsplash.com/photo-1535016120720-40c646be5580?w=1000',
        'backdrop_path': 'https://images.unsplash.com/photo-1535016120720-40c646be5580?w=1200',
        'vote_average': 0.0,
        'first_air_date': '2026-11-26',
        'overview': 'The final season of the hit sci-fi horror series, demo mode placeholder — connect a TMDB API key for live data.'
      }
    ];
  }

  Map<String, dynamic> _getMockDetails(int id, String mediaType, String countryCode) {
    final mockList = _getMockTrending();
    final item = mockList.firstWhere((element) => element['id'] == id, orElse: () => mockList.first);

    String? trailerId;
    List<Map<String, dynamic>> freeList = [];
    List<Map<String, dynamic>> subList = [];
    List<String> genres = [];

    if (id == 1) {
      trailerId = 'g6z9S-5vAxs';
      genres = ['Action', 'Adventure', 'Drama'];
      freeList = [
        {'provider_name': 'Tubi TV', 'logo_path': 'https://placehold.co/100x100/orange/white?text=Tubi'},
      ];
    } else if (id == 2) {
      trailerId = 'Way9DexNy3w';
      genres = ['Sci-Fi', 'Adventure'];
      freeList = [
        {'provider_name': 'YouTube Free', 'logo_path': 'https://placehold.co/100x100/red/white?text=YouTube'},
      ];
    } else if (id == 3) {
      trailerId = 'b9EkMc79ZSU';
      genres = ['Drama', 'Sci-Fi', 'Mystery'];
      freeList = [];
    } else {
      trailerId = 'EXeTwQWrcwY';
      genres = ['Action', 'Crime', 'Drama'];
      freeList = [
        {'provider_name': 'Pluto TV', 'logo_path': 'https://placehold.co/100x100/yellow/black?text=Pluto'},
        {'provider_name': 'Tubi TV', 'logo_path': 'https://placehold.co/100x100/orange/white?text=Tubi'},
      ];
    }

    if (countryCode == 'IN') {
      subList = [
        {'provider_name': 'Disney+ Hotstar', 'logo_path': 'https://upload.wikimedia.org/wikipedia/commons/3/3e/Disney%2B_logo.png'},
        {'provider_name': 'JioCinema', 'logo_path': 'https://placehold.co/100x100/purple/white?text=Jio'},
        {'provider_name': 'Zee5', 'logo_path': 'https://placehold.co/100x100/black/white?text=Zee5'},
      ];
    } else if (countryCode == 'GB') {
      subList = [
        {'provider_name': 'BBC iPlayer', 'logo_path': 'https://placehold.co/100x100/black/white?text=BBC'},
        {'provider_name': 'Now TV', 'logo_path': 'https://placehold.co/100x100/cyan/white?text=Now'},
      ];
    } else if (countryCode == 'CA') {
      subList = [
        {'provider_name': 'Crave', 'logo_path': 'https://placehold.co/100x100/blue/white?text=Crave'},
        {'provider_name': 'Netflix Canada', 'logo_path': 'https://upload.wikimedia.org/wikipedia/commons/f/ff/Netflix-new-icon.png'},
      ];
    } else if (countryCode == 'AU') {
      subList = [
        {'provider_name': 'Stan', 'logo_path': 'https://placehold.co/100x100/blue/white?text=Stan'},
        {'provider_name': 'Binge', 'logo_path': 'https://placehold.co/100x100/black/white?text=Binge'},
      ];
    } else {
      subList = [
        {'provider_name': 'Netflix', 'logo_path': 'https://upload.wikimedia.org/wikipedia/commons/f/ff/Netflix-new-icon.png'},
        {'provider_name': 'Hulu', 'logo_path': 'https://upload.wikimedia.org/wikipedia/commons/3/3e/Disney%2B_logo.png'},
        {'provider_name': 'Amazon Prime', 'logo_path': 'https://upload.wikimedia.org/wikipedia/commons/d/de/Amazon_icon.png'},
      ];
    }

    double voteAverage = 0.0;
    if (item['vote_average'] is num) {
      voteAverage = (item['vote_average'] as num).toDouble();
    }

    return {
      'id': item['id'],
      'title': item['title'] ?? item['name'] ?? 'Untitled',
      'overview': item['overview'] ?? '',
      'backdrop_path': item['backdrop_path'],
      'poster_path': item['poster_path'],
      'vote_average': voteAverage,
      'release_date': item['release_date'] ?? item['first_air_date'] ?? 'N/A',
      'genres': genres,
      'trailer_id': trailerId,
      'free_options': freeList,
      'subscription_options': subList,
      'seasons': mediaType == 'tv' ? [
        {'season_number': 1, 'episode_count': 8, 'name': 'Season 1'}
      ] : [],
    };
  }
}