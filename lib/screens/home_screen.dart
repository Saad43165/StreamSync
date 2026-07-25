import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/tmdb_service.dart';
import '../services/database_service.dart';
import 'filtered_results_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/shimmer_loading.dart';
import 'details_screen.dart';
import 'see_all_screen.dart';
import 'upcoming_releases_screen.dart';
import 'watch_history_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'downloads_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isOffline = false;
  late PageController _pageController;
  Timer? _carouselTimer;
  int _currentPage = 0;

  // GlobalKeys for Section Navigation
  final GlobalKey _trendingKey = GlobalKey();
  final GlobalKey _moviesKey = GlobalKey();
  final GlobalKey _seriesKey = GlobalKey();
  final GlobalKey _netflixKey = GlobalKey();
  final GlobalKey _primeKey = GlobalKey();
  final GlobalKey _disneyKey = GlobalKey();
  final GlobalKey _actionKey = GlobalKey();
  final GlobalKey _comedyKey = GlobalKey();
  final GlobalKey _scifiKey = GlobalKey();
  final GlobalKey _horrorKey = GlobalKey();
  final GlobalKey _upcomingKey = GlobalKey();
  final GlobalKey _freeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _initApp();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _carouselTimer?.cancel();
    super.dispose();
  }

  Future<void> _initApp() async {
    await _checkConnection();
    if (mounted) {
      Provider.of<TMDBService>(context, listen: false).fetchTrending();
    }
  }

  Future<void> _checkConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 4));
      if (mounted) {
        setState(() {
          _isOffline = result.isEmpty || result[0].rawAddress.isEmpty;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isOffline = true;
        });
      }
    }
  }

  void _startCarouselTimer(int itemCount) {
    _carouselTimer?.cancel();
    if (itemCount <= 1) return;
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % itemCount;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.fastOutSlowIn,
        );
      }
    });
  }

  void _scrollToSection(GlobalKey key) {
    if (key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tmdbService = Provider.of<TMDBService>(context);
    final dbService = Provider.of<DatabaseService>(context);
    final trendingList = tmdbService.trending;
    final carouselItems = trendingList.take(5).toList();

    return Scaffold(
      extendBodyBehindAppBar: true, // Transparent overlay design
      drawer: _buildDrawer(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          'CineSync',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 20),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _checkConnection();
          if (mounted) {
            await tmdbService.fetchTrending();
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Offline warning banner
              if (_isOffline) _buildOfflineStrip(context),

              // API Key Warning Banner
              if (!tmdbService.hasApiKey && !_isOffline) _buildApiKeyWarning(context),

              // 2. Hero Carousel (Swiping top 5 trending movies)
              tmdbService.isLoading
                  ? ShimmerLoadingPresets.heroBannerSkeleton()
                  : trendingList.isEmpty
                      ? const SizedBox(
                          height: 300,
                          child: Center(child: Text('No trending titles found.')),
                        )
                      : _buildHeroCarousel(context, carouselItems),

              // 2.5 Dynamic Continue Watching System (Watch History)
              _buildContinueWatchingSection(context, dbService),

              const SizedBox(height: 16),

              // Genres Row
              _buildGenresRow(context),

              const SizedBox(height: 12),

              // Years Row
              _buildYearsRow(context),

              const SizedBox(height: 24),

              // 3. Dynamic Section Navigation Chips
              _buildNavigationPills(context),

              const SizedBox(height: 24),

              // 4. Trending Now Row
              _buildSectionTitle(context, 'Trending Today', key: _trendingKey, items: trendingList),
              const SizedBox(height: 12),
              tmdbService.isLoading
                  ? ShimmerLoadingPresets.horizontalPostersSkeleton()
                  : _buildHorizontalSection(context, items: trendingList),

              const SizedBox(height: 24),

              // 5. Movies Section
              _buildSectionTitle(context, 'Blockbuster Movies', key: _moviesKey, items: tmdbService.movies),
              const SizedBox(height: 12),
              tmdbService.isLoading
                  ? ShimmerLoadingPresets.horizontalPostersSkeleton()
                  : _buildHorizontalSection(context, items: tmdbService.movies),

              const SizedBox(height: 24),

              // 6. TV Series Section
              _buildSectionTitle(context, 'Trending TV Shows & Series', key: _seriesKey, items: tmdbService.series),
              const SizedBox(height: 12),
              tmdbService.isLoading
                  ? ShimmerLoadingPresets.horizontalPostersSkeleton()
                  : _buildHorizontalSection(context, items: tmdbService.series),

              const SizedBox(height: 24),

              // Bollywood Hits Section
              _buildSectionTitle(context, 'Bollywood Blockbusters', key: GlobalKey(), items: tmdbService.bollywood),
              const SizedBox(height: 12),
              tmdbService.isLoading
                  ? ShimmerLoadingPresets.horizontalPostersSkeleton()
                  : _buildHorizontalSection(context, items: tmdbService.bollywood),

              const SizedBox(height: 24),

              // Pakistani Dramas & Movies Section
              _buildSectionTitle(context, 'Pakistani Dramas & Movies', key: GlobalKey(), items: tmdbService.pakistani),
              const SizedBox(height: 12),
              tmdbService.isLoading
                  ? ShimmerLoadingPresets.horizontalPostersSkeleton()
                  : _buildHorizontalSection(context, items: tmdbService.pakistani),

              const SizedBox(height: 24),

              // 7. Upcoming Releases Section
              _buildUpcomingSection(context, tmdbService),

              const SizedBox(height: 24),

              // 8. Netflix Section
              _buildPlatformSectionTitle(context, 'Streaming on Netflix', Colors.redAccent, key: _netflixKey, items: tmdbService.netflix),
              const SizedBox(height: 12),
              tmdbService.isLoading
                  ? ShimmerLoadingPresets.horizontalPostersSkeleton()
                  : _buildHorizontalSection(context, items: tmdbService.netflix),

              const SizedBox(height: 24),

              // 9. Amazon Prime Section
              _buildPlatformSectionTitle(context, 'Streaming on Prime Video', Colors.lightBlueAccent, key: _primeKey, items: tmdbService.prime),
              const SizedBox(height: 12),
              tmdbService.isLoading
                  ? ShimmerLoadingPresets.horizontalPostersSkeleton()
                  : _buildHorizontalSection(context, items: tmdbService.prime),

              const SizedBox(height: 24),

              // 10. Disney+ Section
              _buildPlatformSectionTitle(context, 'Streaming on Disney+', Colors.blueAccent, key: _disneyKey, items: tmdbService.disney),
              const SizedBox(height: 12),
              tmdbService.isLoading
                  ? ShimmerLoadingPresets.horizontalPostersSkeleton()
                  : _buildHorizontalSection(context, items: tmdbService.disney),

              const SizedBox(height: 24),

              // 11. Action Movies Section
              _buildSectionTitle(context, 'Action-Packed Thrillers', key: _actionKey, items: tmdbService.actionMovies),
              const SizedBox(height: 12),
              tmdbService.isLoading
                  ? ShimmerLoadingPresets.horizontalPostersSkeleton()
                  : _buildHorizontalSection(context, items: tmdbService.actionMovies),

              const SizedBox(height: 24),

              // 12. Comedy Movies Section
              _buildSectionTitle(context, 'Hit Comedies & Laughs', key: _comedyKey, items: tmdbService.comedyMovies),
              const SizedBox(height: 12),
              tmdbService.isLoading
                  ? ShimmerLoadingPresets.horizontalPostersSkeleton()
                  : _buildHorizontalSection(context, items: tmdbService.comedyMovies),

              const SizedBox(height: 24),

              // 13. Sci-Fi Section
              _buildSectionTitle(context, 'Sci-Fi & Cyberpunk', key: _scifiKey, items: tmdbService.scifiMovies),
              const SizedBox(height: 12),
              tmdbService.isLoading
                  ? ShimmerLoadingPresets.horizontalPostersSkeleton()
                  : _buildHorizontalSection(context, items: tmdbService.scifiMovies),

              const SizedBox(height: 24),

              // 14. Horror Section
              _buildSectionTitle(context, 'Spooky Horror & Mystery', key: _horrorKey, items: tmdbService.horrorMovies),
              const SizedBox(height: 12),
              tmdbService.isLoading
                  ? ShimmerLoadingPresets.horizontalPostersSkeleton()
                  : _buildHorizontalSection(context, items: tmdbService.horrorMovies),

              const SizedBox(height: 24),

              // 15. Free to Watch Row
              Padding(
                key: _freeKey,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Free to Watch',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
                          ),
                          child: const Text(
                            'NO COST',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        final freeList = tmdbService.hasApiKey
                            ? trendingList
                            : trendingList.where((item) => item['id'] == 1 || item['id'] == 2 || item['id'] == 4).toList();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SeeAllScreen(
                              categoryTitle: 'Free Content',
                              initialItems: freeList,
                            ),
                          ),
                        );
                      },
                      child: const Row(
                        children: [
                          Text(
                            'See All',
                            style: TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios_rounded, color: Colors.greenAccent, size: 10),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              tmdbService.isLoading
                  ? ShimmerLoadingPresets.horizontalPostersSkeleton()
                  : _buildHorizontalSection(
                      context,
                      items: tmdbService.hasApiKey
                          ? trendingList
                          : trendingList.where((item) => item['id'] == 1 || item['id'] == 2 || item['id'] == 4).toList(),
                      showFreeBadge: true,
                    ),

              const SizedBox(height: 30),

              // 16. Premium sponsor promotional banner

              const SizedBox(height: 110),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContinueWatchingSection(BuildContext context, DatabaseService dbService) {
    final history = dbService.watchHistory;
    if (history.isEmpty) return const SizedBox.shrink();

    final isLive = Provider.of<TMDBService>(context, listen: false).hasApiKey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Continue Watching',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              GestureDetector(
                onTap: () {
                  dbService.clearDatabase(); // Resets history
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Watch history cleared.')),
                  );
                },
                child: Text(
                  'Clear All',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final item = history[index];
              final name = item['title'] ?? 'Untitled';
              final posterPath = item['poster_path'];
              final imageUrl = isLive && posterPath != null
                  ? (posterPath.toString().startsWith('http') ? posterPath : '${TMDBService.imageBaseUrl}$posterPath')
                  : (posterPath ?? 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=300');

              final episodeLabel = item['media_type'] == 'tv'
                  ? 'Season ${item['season'] ?? 1}, Episode ${item['episode'] ?? 1}'
                  : 'Movie Stream';

              final progress = item['progress_seconds'] as int? ?? 0;
              final duration = item['duration_seconds'] as int? ?? 0;
              final double percent = duration > 0 ? (progress / duration).clamp(0.0, 1.0) : 0.0;
              final int remaining = duration > progress ? duration - progress : 0;
              final String remainingLabel = remaining > 0
                  ? '${(remaining / 60).floor()}m left'
                  : percent > 0 ? 'Watched' : 'Start';

              return Dismissible(
                key: Key('continue_${item['id']}'),
                direction: DismissDirection.up,
                onDismissed: (_) => dbService.removeFromHistory(item['id']),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailsScreen(
                          id: item['id'],
                          mediaType: item['media_type'] ?? 'movie',
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 210,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(imageUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: AppTheme.surface)),
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.transparent, Colors.black87],
                                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                stops: [0.3, 1.0],
                              ),
                            ),
                          ),
                          // Play button
                          const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 40)),
                          // Info bar at bottom
                          Positioned(
                            bottom: percent > 0 ? 6 : 12,
                            left: 10, right: 10,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(episodeLabel,
                                    style: const TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.bold)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(remainingLabel,
                                      style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                            ]),
                          ),
                          // Progress bar
                          Positioned(
                            bottom: 0, left: 0, right: 0,
                            child: LinearProgressIndicator(
                              value: percent,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingSection(BuildContext context, TMDBService tmdbService) {
    final list = tmdbService.upcoming;
    if (list.isEmpty) return const SizedBox.shrink();

    final isLive = tmdbService.hasApiKey;

    return Column(
      key: _upcomingKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Upcoming Releases',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UpcomingReleasesScreen(),
                    ),
                  );
                },
                child: const Row(
                  children: [
                    Text(
                      'See All',
                      style: TextStyle(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.accent, size: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 250,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final item = list[index];
              final name = item['title'] ?? 'Upcoming Title';
              final posterPath = item['poster_path'];
              final imageUrl = isLive && posterPath != null
                  ? (posterPath.toString().startsWith('http') ? posterPath : '${TMDBService.imageBaseUrl}$posterPath')
                  : (posterPath ?? 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=300');

              final releaseDate = item['release_date'] ?? 'Coming Soon';

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailsScreen(
                        id: item['id'],
                        mediaType: 'movie',
                        posterUrl: imageUrl,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 130,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Hero(
                          tag: 'poster_${item['id']}',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.shade700,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'NEW',
                                    style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        'Releasing: $releaseDate',
                        style: const TextStyle(fontSize: 10, color: AppTheme.accent, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationPills(BuildContext context) {
    final List<Map<String, dynamic>> pills = [
      {'label': 'Trending', 'key': _trendingKey},
      {'label': 'Movies', 'key': _moviesKey},
      {'label': 'TV Shows', 'key': _seriesKey},
      {'label': 'Upcoming', 'key': _upcomingKey, 'color': Colors.amberAccent},
      {'label': 'Netflix', 'key': _netflixKey, 'color': Colors.redAccent},
      {'label': 'Prime', 'key': _primeKey, 'color': Colors.lightBlueAccent},
      {'label': 'Disney+', 'key': _disneyKey, 'color': Colors.blueAccent},
      {'label': 'Action', 'key': _actionKey},
      {'label': 'Comedy', 'key': _comedyKey},
      {'label': 'Sci-Fi', 'key': _scifiKey},
      {'label': 'Horror', 'key': _horrorKey},
      {'label': 'Free', 'key': _freeKey, 'color': Colors.greenAccent},
    ];

    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: pills.length,
        itemBuilder: (context, index) {
          final pill = pills[index];
          final accentColor = pill['color'] as Color? ?? AppTheme.accent;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              onPressed: () => _scrollToSection(pill['key'] as GlobalKey),
              avatar: _buildPillAvatar(pill['label'] as String, accentColor),
              label: Text(
                pill['label'] as String,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: Colors.white.withValues(alpha: 0.04),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPillAvatar(String label, Color defaultColor) {
    String url = '';
    switch (label.toLowerCase()) {
      case 'netflix':
        url = 'https://upload.wikimedia.org/wikipedia/commons/f/ff/Netflix-new-icon.png';
        break;
      case 'prime':
        url = 'https://upload.wikimedia.org/wikipedia/commons/d/de/Amazon_icon.png';
        break;
      case 'disney+':
        url = 'https://upload.wikimedia.org/wikipedia/commons/3/3e/Disney%2B_logo.png';
        break;
      case 'free':
        return Icon(Icons.card_giftcard_rounded, color: defaultColor, size: 14);
      case 'tv shows':
        return Icon(Icons.tv_rounded, color: defaultColor, size: 14);
      case 'movies':
        return Icon(Icons.movie_rounded, color: defaultColor, size: 14);
      case 'trending':
        return Icon(Icons.trending_up_rounded, color: defaultColor, size: 14);
      case 'upcoming':
        return Icon(Icons.event_note_rounded, color: defaultColor, size: 14);
      case 'action':
        return Icon(Icons.sports_martial_arts_rounded, color: defaultColor, size: 14);
      case 'comedy':
        return Icon(Icons.emoji_emotions_rounded, color: defaultColor, size: 14);
      case 'sci-fi':
        return Icon(Icons.rocket_launch_rounded, color: defaultColor, size: 14);
      case 'horror':
        return Icon(Icons.dangerous_rounded, color: defaultColor, size: 14);
    }

    if (url.isNotEmpty) {
      return Image.network(
        url,
        width: 14,
        height: 14,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(Icons.play_arrow_rounded, color: defaultColor, size: 14),
      );
    }
    return Icon(Icons.play_arrow_rounded, color: defaultColor, size: 14);
  }

  Widget _buildSectionTitle(BuildContext context, String text, {required GlobalKey key, required List<dynamic> items}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
          ),
          if (items.isNotEmpty)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SeeAllScreen(
                      categoryTitle: text,
                      initialItems: items,
                    ),
                  ),
                );
              },
              child: const Row(
                children: [
                  Text(
                    'See All',
                    style: TextStyle(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.accent, size: 10),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlatformSectionTitle(BuildContext context, String text, Color accentColor, {required GlobalKey key, required List<dynamic> items}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          if (items.isNotEmpty)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SeeAllScreen(
                      categoryTitle: text,
                      initialItems: items,
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  Text(
                    'See All',
                    style: TextStyle(color: accentColor, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios_rounded, color: accentColor, size: 10),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOfflineStrip(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        color: Colors.redAccent.shade700,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'Device is Offline. Showing local watchlist content.',
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApiKeyWarning(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: GlassCard(
        margin: const EdgeInsets.fromLTRB(16, 90, 16, 0), // Adjusted top margin to fit translucent appBar
        padding: const EdgeInsets.all(12),
        borderColor: Colors.yellowAccent.withValues(alpha: 0.2),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.yellowAccent, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Viewing in Demo Mode',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Enter a free TMDB API key in config.dart to unlock live global streams and search.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCarousel(BuildContext context, List<dynamic> items) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCarouselTimer(items.length);
    });

    return SizedBox(
      height: 480,
      width: double.infinity,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildHeroSlide(context, item);
            },
          ),
          
          Positioned(
            bottom: 24,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(items.length, (index) {
                final isSelected = _currentPage == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isSelected ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.accent : Colors.white54,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSlide(BuildContext context, dynamic item) {
    final title = item['title'] ?? item['name'] ?? 'Untitled';
    final overview = item['overview'] ?? '';
    final ratingNum = (item['vote_average'] as num?)?.toDouble() ?? 0.0;
    final rating = ratingNum.toStringAsFixed(1);
    
    final isLive = Provider.of<TMDBService>(context, listen: false).hasApiKey;
    final backdropPath = item['backdrop_path'];
    final imageUrl = isLive && backdropPath != null
        ? (backdropPath.toString().startsWith('http') ? backdropPath : '${TMDBService.backdropBaseUrl}$backdropPath')
        : (backdropPath ?? 'https://images.unsplash.com/photo-1594909122845-11baa439b7bf?w=800');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailsScreen(
              id: item['id'],
              mediaType: item['media_type'] ?? 'movie',
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(imageUrl),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black38,
                Colors.black54,
                AppTheme.background,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.secondaryAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: AppTheme.secondaryAccent, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      rating,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  shadows: [
                    Shadow(blurRadius: 12, color: Colors.black, offset: Offset(0, 4)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                overview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailsScreen(
                            id: item['id'],
                            mediaType: item['media_type'] ?? 'movie',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 24),
                    label: const Text(
                      'Watch Now',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalSection(
    BuildContext context, {
    required List<dynamic> items,
    bool showFreeBadge = false,
  }) {
    if (items.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No content available in this section.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
      );
    }

    final isLive = Provider.of<TMDBService>(context, listen: false).hasApiKey;

    return SizedBox(
      height: 230,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final name = item['title'] ?? item['name'] ?? 'Untitled';
          final voteAverage = (item['vote_average'] as num?)?.toDouble() ?? 0.0;
          final rating = voteAverage.toStringAsFixed(1);

          final posterPath = item['poster_path'];
          final imageUrl = isLive && posterPath != null
              ? (posterPath.toString().startsWith('http') ? posterPath : '${TMDBService.imageBaseUrl}$posterPath')
              : (posterPath ?? 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=300');

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetailsScreen(
                    id: item['id'],
                    mediaType: item['media_type'] ?? (item['title'] != null ? 'movie' : 'tv'),
                    posterUrl: imageUrl,
                  ),
                ),
              );
            },
            child: Container(
              width: 130,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Hero(
                      tag: 'poster_${item['id']}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const ImageShimmerPlaceholder(borderRadius: 12);
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: AppTheme.surface,
                                child: const Icon(Icons.movie, color: Colors.white24, size: 36),
                              );
                            },
                          ),
                          if (showFreeBadge)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade700,
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
                                ),
                                child: const Text(
                                  'FREE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star, color: AppTheme.secondaryAccent, size: 10),
                                  const SizedBox(width: 2),
                                  Text(
                                    rating,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final dbService = Provider.of<DatabaseService>(context);
    final isPremium = dbService.isPremium;

    Color themeColor = Colors.purpleAccent;
    if (dbService.currentProfile == 'Family') themeColor = Colors.blueAccent;
    if (dbService.currentProfile == 'Kids') themeColor = Colors.greenAccent;

    void navTo(Widget screen) {
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    }

    return Drawer(
      child: Container(
        color: AppTheme.background,
        child: SafeArea(
          child: Column(
            children: [
              // ── Profile Header ──────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [themeColor.withAlpha(200), themeColor.withAlpha(60)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white.withAlpha(220),
                      child: Text(
                        dbService.isLoggedIn
                            ? dbService.username.substring(0, 1).toUpperCase()
                            : dbService.currentProfile.substring(0, 1),
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: themeColor),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dbService.isLoggedIn ? dbService.username : dbService.currentProfile,
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dbService.isLoggedIn
                                ? dbService.email
                                : (isPremium ? 'Premium Active' : 'Free Account'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withAlpha(170), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    if (isPremium)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.tealAccent.withAlpha(40),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.tealAccent.withAlpha(80)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, color: Colors.tealAccent, size: 12),
                            SizedBox(width: 4),
                            Text('PRO', style: TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // ── Scrollable Navigation ───────────────────────
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      _drawerSectionLabel('Discover'),

                      _drawerItem(
                        icon: Icons.calendar_month_rounded,
                        label: 'Upcoming Releases',
                        iconColor: Colors.amberAccent,
                        onTap: () => navTo(const UpcomingReleasesScreen()),
                      ),

                      _drawerItem(
                        icon: Icons.history_rounded,
                        label: 'Watch History',
                        iconColor: Colors.lightBlueAccent,
                        onTap: () => navTo(const WatchHistoryScreen()),
                      ),

                      _drawerItem(
                        icon: Icons.download_for_offline_rounded,
                        label: 'Offline Downloads',
                        iconColor: Colors.greenAccent,
                        onTap: () => navTo(const DownloadsScreen()),
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Divider(color: Colors.white12, height: 1),
                      ),

                      _drawerSectionLabel('Account'),

                      _drawerItem(
                        icon: Icons.settings_rounded,
                        label: 'Settings',
                        iconColor: Colors.white60,
                        onTap: () => navTo(const SettingsScreen()),
                      ),

                      if (!dbService.isLoggedIn)
                        _drawerItem(
                          icon: Icons.login_rounded,
                          label: 'Sign In / Sign Up',
                          iconColor: AppTheme.accent,
                          onTap: () => navTo(const LoginScreen(showSkipButton: false)),
                        ),

                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Divider(color: Colors.white12, height: 1),
                      ),

                      // ── Premium Card ──────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: GestureDetector(
                          onTap: () => navTo(const SettingsScreen()),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isPremium
                                    ? [Colors.tealAccent.withAlpha(30), Colors.tealAccent.withAlpha(10)]
                                    : [AppTheme.secondaryAccent.withAlpha(40), AppTheme.secondaryAccent.withAlpha(15)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isPremium
                                    ? Colors.tealAccent.withAlpha(60)
                                    : AppTheme.secondaryAccent.withAlpha(70),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isPremium ? Icons.verified_rounded : Icons.workspace_premium_rounded,
                                  color: isPremium ? Colors.tealAccent : AppTheme.secondaryAccent,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isPremium ? 'Premium Pro Active' : 'Upgrade to Premium',
                                        style: TextStyle(
                                          color: isPremium ? Colors.tealAccent : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        isPremium ? 'Lifetime · Ad-free' : 'Remove ads · \$1.99 lifetime',
                                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isPremium)
                                  const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.secondaryAccent, size: 13),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Footer ─────────────────────────────────────
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: Row(
                  children: [
                    Icon(Icons.movie_filter_rounded, color: Colors.white12, size: 13),
                    SizedBox(width: 6),
                    Text(
                      'StreamSync  v1.2.0',
                      style: TextStyle(color: Colors.white12, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Colors.white30,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _buildGenresRow(BuildContext context) {
    final genres = [
      {'id': '28', 'name': 'Action', 'icon': Icons.flash_on},
      {'id': '35', 'name': 'Comedy', 'icon': Icons.sentiment_very_satisfied},
      {'id': '27', 'name': 'Horror', 'icon': Icons.nights_stay},
      {'id': '878', 'name': 'Sci-Fi', 'icon': Icons.rocket_launch},
      {'id': '10749', 'name': 'Romance', 'icon': Icons.favorite},
      {'id': '16', 'name': 'Animation', 'icon': Icons.animation},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text('Browse by Genre', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white70)),
        ),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: genres.length,
            itemBuilder: (context, index) {
              final g = genres[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => FilteredResultsScreen(title: g['name'] as String, genreId: g['id'] as String),
                  ));
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(g['icon'] as IconData, color: AppTheme.accent, size: 16),
                      const SizedBox(width: 8),
                      Text(g['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildYearsRow(BuildContext context) {
    final years = ['2024', '2023', '2022', '2020s', '2010s', '2000s'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text('Release Year', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white70)),
        ),
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: years.length,
            itemBuilder: (context, index) {
              final y = years[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => FilteredResultsScreen(title: y, year: y),
                  ));
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(y, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    Color iconColor = Colors.white70,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
        child: ListTile(
          dense: true,
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

