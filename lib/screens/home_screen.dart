import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
import 'search_screen.dart';

// ── Pre-computed static colors (avoids withOpacity() allocations every frame) ─
const Color _bg       = Color(0xFF080810);
const Color _surface  = Color(0xFF0F0F1E);
const Color _card     = Color(0xFF14142A);
const Color _dimText  = Color(0xFF8888AA);
const Color _gold     = Color(0xFFF5C842);

// Replaces withOpacity calls — computed once at compile time
const Color _bgBlur72       = Color(0xB8080810); // _bg @ 0.72
const Color _white12        = Color(0x1FFFFFFF);
const Color _white14        = Color(0x24FFFFFF);
const Color _white15        = Color(0x26FFFFFF);
const Color _white22        = Color(0x38FFFFFF);
const Color _white30        = Color(0x4DFFFFFF);
const Color _black45        = Color(0x73000000);
const Color _black54        = Color(0x8A000000);
const Color _black55        = Color(0x8C000000);
const Color _black87        = Color(0xDE000000);
const Color _white07        = Color(0x12FFFFFF);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  bool _isOffline = false;

  // ── Hero carousel ─────────────────────────────────────────────────────────
  late PageController _pageController;
  Timer? _carouselTimer;
  int _currentPage = 0;
  bool _isCarouselActive = true;

  // ── Scroll / app-bar fade (ValueNotifier = no setState on scroll) ─────────
  final ValueNotifier<double> _appBarOpacity = ValueNotifier(0.0);
  final ScrollController _scrollController = ScrollController();

  // ── Section keys ──────────────────────────────────────────────────────────
  final GlobalKey _trendingKey   = GlobalKey();
  final GlobalKey _moviesKey     = GlobalKey();
  final GlobalKey _seriesKey     = GlobalKey();
  final GlobalKey _netflixKey    = GlobalKey();
  final GlobalKey _primeKey      = GlobalKey();
  final GlobalKey _disneyKey     = GlobalKey();
  final GlobalKey _actionKey     = GlobalKey();
  final GlobalKey _comedyKey     = GlobalKey();
  final GlobalKey _scifiKey      = GlobalKey();
  final GlobalKey _horrorKey     = GlobalKey();
  final GlobalKey _upcomingKey   = GlobalKey();
  final GlobalKey _freeKey       = GlobalKey();
  final GlobalKey _bollywoodKey  = GlobalKey();
  final GlobalKey _pakistaniKey  = GlobalKey();

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _heroTextController;
  late Animation<double>   _heroTextFade;
  late Animation<Offset>   _heroTextSlide;

  // ── Cached static widgets (built once, reused) ────────────────────────────
  Widget? _cachedGenreStrip;
  Widget? _cachedJumpPills;
  Widget? _cachedYearStrip;

  static String _imageUrl(String? path, {int width = 500, bool isBackdrop = false}) {
    if (path == null || path.isEmpty) {
      return isBackdrop
          ? 'https://images.unsplash.com/photo-1594909122845-11baa439b7bf?w=1200'
          : 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=300';
    }
    if (path.startsWith('http')) return path;
    final size = isBackdrop ? 'w1280' : 'w$width';
    return 'https://image.tmdb.org/t/p/$size$path';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();

    _heroTextController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _heroTextFade = CurvedAnimation(
        parent: _heroTextController, curve: Curves.easeOut);
    _heroTextSlide = Tween<Offset>(
        begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _heroTextController, curve: Curves.easeOut));

    // FIX 1: Use listener that updates ValueNotifier — no setState on scroll
    _scrollController.addListener(_onScroll);
    _initApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isCarouselActive = false;
    _carouselTimer?.cancel();
    _pageController.dispose();
    _scrollController.dispose();
    _appBarOpacity.dispose();
    _heroTextController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _carouselTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      final tmdb = context.read<TMDBService>();
      _startCarouselTimer(tmdb.trending.take(6).length);
    }
  }

  // FIX 1: No setState — ValueNotifier is listened to by ValueListenableBuilder
  void _onScroll() {
    final opacity = (_scrollController.offset / 120).clamp(0.0, 1.0);
    _appBarOpacity.value = opacity;
  }

  Future<void> _initApp() async {
    await _checkConnection();
    if (!mounted) return;
    final tmdb = context.read<TMDBService>(); // FIX 2: listen:false in callbacks
    await tmdb.fetchTrending();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCarouselTimer(tmdb.trending.take(6).length);
      _heroTextController.forward();
    });
  }

  Future<void> _checkConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      if (mounted) {
        setState(() =>
        _isOffline = result.isEmpty || result[0].rawAddress.isEmpty);
      }
    } catch (_) {
      if (mounted) setState(() => _isOffline = true);
    }
  }

  void _startCarouselTimer(int count) {
    _carouselTimer?.cancel();
    if (count <= 1 || !_isCarouselActive) return;
    _carouselTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!_isCarouselActive || !_pageController.hasClients) return;
      final next = (_currentPage + 1) % count;
      _pageController.animateToPage(next,
          duration: const Duration(milliseconds: 700),
          curve: Curves.fastOutSlowIn);
    });
  }

  void _scrollToSection(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    // FIX 3: Use Selector to only rebuild when specific fields change,
    //        not on every TMDBService.notifyListeners()
    return Scaffold(
      backgroundColor: _bg,
      extendBodyBehindAppBar: true,
      drawer: _buildDrawer(context),

      // FIX 4: ValueListenableBuilder — appbar animates without setState
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ValueListenableBuilder<double>(
          valueListenable: _appBarOpacity,
          builder: (_, opacity, child) => AnimatedOpacity(
            opacity: opacity,
            duration: const Duration(milliseconds: 80),
            child: child,
          ),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: ColoredBox(
                color: _bgBlur72,
                child: SafeArea(
                  bottom: false,
                  child: SizedBox(
                    height: 60,
                    child: Row(children: [
                      Builder(builder: (ctx) => IconButton(
                        icon: const Icon(Icons.menu_rounded,
                            color: Colors.white, size: 24),
                        onPressed: () => Scaffold.of(ctx).openDrawer(),
                      )),
                      const Spacer(),
                      const _CineSyncLogo(fontSize: 20),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.search_rounded,
                            color: Color(0xCCFFFFFF), size: 24),
                        onPressed: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => const SearchScreen())),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),

      body: Selector<TMDBService, _TMDBSnapshot>(
        // FIX 5: Selector — only rebuild body when these specific values change
        selector: (_, tmdb) => _TMDBSnapshot(
          isLoading: tmdb.isLoading,
          hasApiKey: tmdb.hasApiKey,
          trending: tmdb.trending,
          movies: tmdb.movies,
          series: tmdb.series,
          bollywood: tmdb.bollywood,
          pakistani: tmdb.pakistani,
          upcoming: tmdb.upcoming,
          netflix: tmdb.netflix,
          prime: tmdb.prime,
          disney: tmdb.disney,
          actionMovies: tmdb.actionMovies,
          comedyMovies: tmdb.comedyMovies,
          scifiMovies: tmdb.scifiMovies,
          horrorMovies: tmdb.horrorMovies,
        ),
        builder: (context, snap, __) {
          final carousel = snap.trending.take(6).toList();
          return RefreshIndicator(
            color: AppTheme.accent,
            backgroundColor: _surface,
            onRefresh: () async {
              await _checkConnection();
              if (mounted) await context.read<TMDBService>().fetchTrending();
            },
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              slivers: [
                // ── 1. Hero carousel ────────────────────────────────────
                SliverToBoxAdapter(
                  child: snap.isLoading
                      ? ShimmerLoadingPresets.heroBannerSkeleton()
                      : snap.trending.isEmpty
                      ? const SizedBox(
                      height: 300,
                      child: Center(
                        child: Text('No trending titles.',
                            style: TextStyle(color: _dimText)),
                      ))
                      : _HeroCarousel(
                    items: carousel,
                    pageController: _pageController,
                    currentPage: _currentPage,
                    heroTextFade: _heroTextFade,
                    heroTextSlide: _heroTextSlide,
                    onPageChanged: (i) {
                      setState(() => _currentPage = i);
                      _heroTextController
                        ..reset()
                        ..forward();
                    },
                    onSearchTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const SearchScreen())),
                    onMenuTap: () => Scaffold.of(context).openDrawer(),
                    onItemTap: (item) => _pushDetails(context, item),
                  ),
                ),

                if (_isOffline)
                  SliverToBoxAdapter(child: _buildOfflineStrip()),
                if (!snap.hasApiKey && !_isOffline)
                  const SliverToBoxAdapter(child: _ApiKeyWarning()),

                // FIX 6: DatabaseService only used in ContinueWatching;
                //        isolated so it doesn't cause full-page rebuilds
                SliverToBoxAdapter(
                  child: _ContinueWatchingSection(
                    onItemTap: (id, type) => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => DetailsScreen(
                                id: id, mediaType: type))),
                  ),
                ),

                // FIX 7: Static strips cached as fields — built only once
                SliverToBoxAdapter(
                    child: _cachedGenreStrip ??=
                        _buildGenreStrip(context)),
                SliverToBoxAdapter(
                    child: _cachedYearStrip ??=
                        _buildYearStrip(context)),
                SliverToBoxAdapter(
                    child: _cachedJumpPills ??=
                        _buildJumpPills(context)),

                // ── Content rows ─────────────────────────────────────────
                ..._contentRows(context, snap),

                const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STATUS BANNERS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildOfflineStrip() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xB2B71C1C), // red.900 @ 0.7
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x66FF5252)),
      ),
      child: const Row(children: [
        Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 16),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            "You're offline — showing cached content.",
            style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 12),
          ),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GENRE STRIP — built once and cached
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildGenreStrip(BuildContext context) {
    const genres = [
      _Genre('28',    'Action',    Icons.flash_on_rounded),
      _Genre('35',    'Comedy',    Icons.sentiment_very_satisfied_rounded),
      _Genre('27',    'Horror',    Icons.nights_stay_rounded),
      _Genre('878',   'Sci-Fi',    Icons.rocket_launch_rounded),
      _Genre('10749', 'Romance',   Icons.favorite_rounded),
      _Genre('16',    'Animation', Icons.animation_rounded),
      _Genre('18',    'Drama',     Icons.theater_comedy_rounded),
      _Genre('53',    'Thriller',  Icons.visibility_rounded),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 28),
      const Padding(
        padding: EdgeInsets.only(left: 20, bottom: 12),
        child: Text('GENRES',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _dimText,
                letterSpacing: 1.4)),
      ),
      SizedBox(
        height: 44,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: genres.length,
          itemExtent: null, // let items size naturally
          itemBuilder: (ctx, i) {
            final g = genres[i];
            return _GenreChip(genre: g);
          },
        ),
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // YEAR STRIP
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildYearStrip(BuildContext context) {
    const years = ['2025', '2024', '2023', '2022', '2020s', '2010s', '2000s'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 20),
      const Padding(
        padding: EdgeInsets.only(left: 20, bottom: 10),
        child: Text('BY YEAR',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _dimText,
                letterSpacing: 1.4)),
      ),
      SizedBox(
        height: 36,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: years.length,
          itemBuilder: (ctx, i) => _YearChip(year: years[i]),
        ),
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // JUMP PILLS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildJumpPills(BuildContext context) {
    final pills = [
      _Pill('Trending',  _trendingKey,  Icons.trending_up_rounded,         AppTheme.accent),
      _Pill('Movies',    _moviesKey,    Icons.movie_rounded,                AppTheme.accent),
      _Pill('TV Shows',  _seriesKey,    Icons.tv_rounded,                   AppTheme.accent),
      _Pill('Upcoming',  _upcomingKey,  Icons.event_note_rounded,           _gold),
      _Pill('Netflix',   _netflixKey,   Icons.play_circle_fill_rounded,     Colors.redAccent),
      _Pill('Prime',     _primeKey,     Icons.star_rounded,                 Colors.lightBlueAccent),
      _Pill('Disney+',   _disneyKey,    Icons.auto_awesome_rounded,         Colors.blueAccent),
      _Pill('Action',    _actionKey,    Icons.sports_martial_arts_rounded,  AppTheme.accent),
      _Pill('Comedy',    _comedyKey,    Icons.emoji_emotions_rounded,       AppTheme.accent),
      _Pill('Sci-Fi',    _scifiKey,     Icons.rocket_launch_rounded,        AppTheme.accent),
      _Pill('Horror',    _horrorKey,    Icons.dangerous_rounded,            AppTheme.accent),
      _Pill('Bollywood', _bollywoodKey, Icons.music_note_rounded,           Colors.deepOrangeAccent),
      _Pill('Pakistani', _pakistaniKey, Icons.language_rounded,             Colors.greenAccent),
      _Pill('Free',      _freeKey,      Icons.card_giftcard_rounded,        Colors.greenAccent),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 24),
      const Padding(
        padding: EdgeInsets.only(left: 20, bottom: 10),
        child: Text('JUMP TO',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _dimText,
                letterSpacing: 1.4)),
      ),
      SizedBox(
        height: 38,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: pills.length,
          itemBuilder: (ctx, i) {
            final p = pills[i];
            return _JumpPillChip(
              pill: p,
              onTap: () => _scrollToSection(p.key),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONTENT ROWS
  // ─────────────────────────────────────────────────────────────────────────
  List<Widget> _contentRows(BuildContext context, _TMDBSnapshot snap) {
    // FIX 8: Helper now returns SliverToBoxAdapter directly,
    //        widgets are const where possible
    Widget row(
        String title,
        List<dynamic> items,
        GlobalKey key, {
          Color? accentColor,
          bool showFreeBadge = false,
          bool isLoading = false,
          String? platformLogoUrl,
        }) {
      return SliverToBoxAdapter(
        child: RepaintBoundary(
          child: _ContentRow(
            title: title,
            items: items,
            sectionKey: key,
            accentColor: accentColor,
            showFreeBadge: showFreeBadge,
            isLoading: isLoading || snap.isLoading,
            platformLogoUrl: platformLogoUrl,
            onSeeAll: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => SeeAllScreen(
                    categoryTitle: title, initialItems: items))),
            onItemTap: (item, url) => _pushDetails(context, item,
                posterUrl: url),
          ),
        ),
      );
    }

    return [
      row('Trending Today',           snap.trending,     _trendingKey),
      row('Blockbuster Movies',       snap.movies,       _moviesKey),
      row('TV Shows & Series',        snap.series,       _seriesKey),
      row('Bollywood Hits',           snap.bollywood,    _bollywoodKey,
          accentColor: Colors.deepOrangeAccent),
      row('Pakistani Dramas & Films', snap.pakistani,    _pakistaniKey,
          accentColor: Colors.greenAccent),
      SliverToBoxAdapter(
          child: _UpcomingSection(
            sectionKey: _upcomingKey,
            items: snap.upcoming,
            onSeeAll: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const UpcomingReleasesScreen())),
            onItemTap: (item) => _pushDetails(context, item,
                mediaType: 'movie'),
          )),
      row('Streaming on Netflix',     snap.netflix,      _netflixKey,
          accentColor: Colors.redAccent,
          platformLogoUrl: 'https://upload.wikimedia.org/wikipedia/commons/f/ff/Netflix-new-icon.png'),
      row('Streaming on Prime Video', snap.prime,        _primeKey,
          accentColor: Colors.lightBlueAccent,
          platformLogoUrl: 'https://upload.wikimedia.org/wikipedia/commons/d/de/Amazon_icon.png'),
      row('Streaming on Disney+',     snap.disney,       _disneyKey,
          accentColor: Colors.blueAccent,
          platformLogoUrl: 'https://upload.wikimedia.org/wikipedia/commons/3/3e/Disney%2B_logo.png'),
      row('Action & Thrillers',       snap.actionMovies, _actionKey),
      row('Comedies',                 snap.comedyMovies, _comedyKey),
      row('Sci-Fi & Cyberpunk',       snap.scifiMovies,  _scifiKey),
      row('Horror & Mystery',         snap.horrorMovies, _horrorKey),
      SliverToBoxAdapter(
        child: RepaintBoundary(
          child: _FreeSection(
            sectionKey: _freeKey,
            items: snap.trending,
            hasApiKey: snap.hasApiKey,
            onItemTap: (item, url) => _pushDetails(context, item,
                posterUrl: url),
          ),
        ),
      ),
    ];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DRAWER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDrawer(BuildContext context) {
    // FIX 9: Drawer reads DatabaseService once here, not via Provider.of
    //        without listen:false
    final db = context.read<DatabaseService>();
    final isPremium  = db.isPremium;
    final isLoggedIn = db.isLoggedIn;
    final username   = isLoggedIn ? db.username : db.currentProfile;
    final sub        = isLoggedIn
        ? db.email
        : (isPremium ? 'Premium Active' : 'Free Account');

    Color profileColor = AppTheme.accent;
    if (db.currentProfile == 'Family') profileColor = Colors.blueAccent;
    if (db.currentProfile == 'Kids')   profileColor = Colors.greenAccent;

    void navTo(Widget screen) {
      Navigator.pop(context);
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => screen));
    }

    return Drawer(
      backgroundColor: _surface,
      child: SafeArea(
        child: Column(children: [
          // Profile card
          _DrawerProfileCard(
            username: username,
            sub: sub,
            profileColor: profileColor,
            isPremium: isPremium,
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _DrawerLabel('Discover'),
                    _DrawerItem(
                      icon: Icons.calendar_month_rounded,
                      label: 'Upcoming Releases',
                      color: Colors.amberAccent,
                      onTap: () => navTo(const UpcomingReleasesScreen()),
                    ),
                    _DrawerItem(
                      icon: Icons.history_rounded,
                      label: 'Watch History',
                      color: Colors.lightBlueAccent,
                      onTap: () => navTo(const WatchHistoryScreen()),
                    ),
                    _DrawerItem(
                      icon: Icons.download_for_offline_rounded,
                      label: 'Offline Downloads',
                      color: Colors.greenAccent,
                      onTap: () => navTo(const DownloadsScreen()),
                    ),
                    const _DrawerDivider(),
                    const _DrawerLabel('Account'),
                    _DrawerItem(
                      icon: Icons.settings_rounded,
                      label: 'Settings',
                      color: _dimText,
                      onTap: () => navTo(const SettingsScreen()),
                    ),
                    if (!isLoggedIn)
                      _DrawerItem(
                        icon: Icons.login_rounded,
                        label: 'Sign In / Sign Up',
                        color: AppTheme.accent,
                        onTap: () => navTo(
                            const LoginScreen(showSkipButton: false)),
                      ),
                    const _DrawerDivider(),
                    _DrawerUpgradeCard(
                      isPremium: isPremium,
                      onTap: () => navTo(const SettingsScreen()),
                    ),
                  ]),
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(children: [
              Icon(Icons.movie_filter_rounded,
                  color: Color(0x1FFFFFFF), size: 12),
              SizedBox(width: 6),
              Text('CineSync  v1.2.0',
                  style: TextStyle(
                      color: Color(0x1AFFFFFF), fontSize: 11)),
            ]),
          ),
        ]),
      ),
    );
  }

  void _pushDetails(BuildContext context, dynamic item,
      {String? mediaType, String? posterUrl}) {
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => DetailsScreen(
          id: item['id'],
          mediaType: mediaType ?? item['media_type'] ?? 'movie',
          posterUrl: posterUrl,
        )));
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// DATA MODEL — Selector snapshot (equality check prevents needless rebuilds)
// ═════════════════════════════════════════════════════════════════════════════
class _TMDBSnapshot {
  const _TMDBSnapshot({
    required this.isLoading,
    required this.hasApiKey,
    required this.trending,
    required this.movies,
    required this.series,
    required this.bollywood,
    required this.pakistani,
    required this.upcoming,
    required this.netflix,
    required this.prime,
    required this.disney,
    required this.actionMovies,
    required this.comedyMovies,
    required this.scifiMovies,
    required this.horrorMovies,
  });

  final bool isLoading;
  final bool hasApiKey;
  final List<dynamic> trending, movies, series, bollywood, pakistani,
      upcoming, netflix, prime, disney, actionMovies, comedyMovies,
      scifiMovies, horrorMovies;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _TMDBSnapshot &&
        other.isLoading == isLoading &&
        other.hasApiKey == hasApiKey &&
        identical(other.trending, trending) &&
        identical(other.movies, movies) &&
        identical(other.series, series);
    // identical() on list references — rebuild only when the list
    // object itself is replaced (which happens after a fresh fetch)
  }

  @override
  int get hashCode => Object.hash(isLoading, hasApiKey,
      trending, movies, series);
}

// ═════════════════════════════════════════════════════════════════════════════
// STATIC DATA MODELS
// ═════════════════════════════════════════════════════════════════════════════
class _Genre {
  const _Genre(this.id, this.name, this.icon);
  final String id, name;
  final IconData icon;
}

class _Pill {
  const _Pill(this.label, this.key, this.icon, this.color);
  final String label;
  final GlobalKey key;
  final IconData icon;
  final Color color;
}

// ═════════════════════════════════════════════════════════════════════════════
// LOGO — const widget, zero rebuild cost
// ═════════════════════════════════════════════════════════════════════════════
class _CineSyncLogo extends StatelessWidget {
  const _CineSyncLogo({required this.fontSize});
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(children: [
        TextSpan(
          text: 'Cine',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w300,
            color: const Color(0xE6FFFFFF),
            letterSpacing: 0.5,
          ),
        ),
        TextSpan(
          text: 'Sync',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HERO CAROUSEL — extracted to its own StatelessWidget
// Receives callbacks; does not rebuild the parent on page changes
// ═════════════════════════════════════════════════════════════════════════════
class _HeroCarousel extends StatelessWidget {
  const _HeroCarousel({
    required this.items,
    required this.pageController,
    required this.currentPage,
    required this.heroTextFade,
    required this.heroTextSlide,
    required this.onPageChanged,
    required this.onSearchTap,
    required this.onMenuTap,
    required this.onItemTap,
  });

  final List<dynamic> items;
  final PageController pageController;
  final int currentPage;
  final Animation<double> heroTextFade;
  final Animation<Offset> heroTextSlide;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onSearchTap;
  final VoidCallback onMenuTap;
  final ValueChanged<dynamic> onItemTap;

  static String _imgUrl(String? path) {
    if (path == null || path.isEmpty) {
      return 'https://images.unsplash.com/photo-1594909122845-11baa439b7bf?w=1200';
    }
    if (path.startsWith('http')) return path;
    return 'https://image.tmdb.org/t/p/w1280$path';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.68,
      child: Stack(children: [
        // FIX 10: RepaintBoundary around the PageView alone
        RepaintBoundary(
          child: PageView.builder(
            controller: pageController,
            itemCount: items.length,
            onPageChanged: onPageChanged,
            itemBuilder: (ctx, i) {
              final item = items[i];
              final title    = item['title'] ?? item['name'] ?? 'Untitled';
              final overview = item['overview'] ?? '';
              final rating   = (item['vote_average'] as num?)?.toDouble() ?? 0.0;
              final imgUrl   = _imgUrl(item['backdrop_path']);
              return GestureDetector(
                onTap: () => onItemTap(item),
                child: Stack(fit: StackFit.expand, children: [
                  CachedNetworkImage(
                    imageUrl: imgUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const ColoredBox(color: _card),
                    errorWidget: (_, __, ___) => const ColoredBox(color: _card),
                    memCacheWidth: 640,
                    maxWidthDiskCache: 1280,
                  ),
                  // Cinematic gradient — const decoration
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Color(0x40080810),
                          Color(0xB8080810),
                          _bg,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.0, 0.42, 0.72, 1.0],
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0x8C080810), Colors.transparent],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                  // Text overlay
                  Positioned(
                    left: 20, right: 80, bottom: 52,
                    child: SlideTransition(
                      position: heroTextSlide,
                      child: FadeTransition(
                        opacity: heroTextFade,
                        child: _HeroSlideContent(
                          title: title,
                          overview: overview,
                          rating: rating,
                          mediaType: item['media_type'] as String?,
                          onWatchNow: () => onItemTap(item),
                          onDetails: () => onItemTap(item),
                        ),
                      ),
                    ),
                  ),
                ]),
              );
            },
          ),
        ),

        // Dot indicators
        Positioned(
          bottom: 28, left: 0, right: 0,
          child: _DotIndicator(count: items.length, current: currentPage),
        ),

        // Transparent top bar
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                _GlassCircleButton(icon: Icons.menu_rounded, onTap: onMenuTap),
                const Spacer(),
                const _CineSyncLogo(fontSize: 19),
                const Spacer(),
                _GlassCircleButton(icon: Icons.search_rounded, onTap: onSearchTap),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Hero text content — extracted to avoid rebuilding on dot change ──────────
class _HeroSlideContent extends StatelessWidget {
  const _HeroSlideContent({
    required this.title,
    required this.overview,
    required this.rating,
    required this.mediaType,
    required this.onWatchNow,
    required this.onDetails,
  });

  final String title, overview;
  final double rating;
  final String? mediaType;
  final VoidCallback onWatchNow, onDetails;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          _HeroBadge(child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.star_rounded, color: _gold, size: 12),
            const SizedBox(width: 4),
            Text(rating.toStringAsFixed(1),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ])),
          const SizedBox(width: 8),
          _HeroBadge(child: Text(
            mediaType == 'tv' ? 'SERIES' : 'FILM',
            style: TextStyle(
                color: AppTheme.accent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2),
          )),
        ]),
        const SizedBox(height: 10),
        Text(title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.08,
              letterSpacing: -0.5,
              shadows: [Shadow(blurRadius: 20, color: Colors.black,
                  offset: Offset(0, 4))],
            )),
        const SizedBox(height: 10),
        Text(overview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 13, color: Color(0xAAFFFFFF), height: 1.5)),
        const SizedBox(height: 20),
        Row(children: [
          ElevatedButton.icon(
            onPressed: onWatchNow,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 22),
            label: const Text('Watch Now',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: GestureDetector(
                onTap: onDetails,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 13),
                  decoration: BoxDecoration(
                    color: _white14,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _white22),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.info_outline_rounded,
                        color: Colors.white, size: 18),
                    SizedBox(width: 7),
                    Text('Details',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ],
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _black45,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _white12),
          ),
          child: child,
        ),
      ),
    );
  }
}

// FIX 11: Dot indicator is a pure StatelessWidget — no animation needed,
//         parent already calls setState for page change
class _DotIndicator extends StatelessWidget {
  const _DotIndicator({required this.count, required this.current});
  final int count, current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final sel = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: sel ? 22 : 5,
          height: 5,
          decoration: BoxDecoration(
            color: sel ? AppTheme.accent : _white30,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _white12,
              shape: BoxShape.circle,
              border: Border.all(color: _white15),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// CONTINUE WATCHING — reads DatabaseService itself, isolated
// ═════════════════════════════════════════════════════════════════════════════
class _ContinueWatchingSection extends StatelessWidget {
  const _ContinueWatchingSection({required this.onItemTap});
  final void Function(int id, String type) onItemTap;

  static String _imgUrl(String? path) {
    if (path == null || path.isEmpty) {
      return 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=300';
    }
    if (path.startsWith('http')) return path;
    return 'https://image.tmdb.org/t/p/w300$path';
  }

  @override
  Widget build(BuildContext context) {
    final db      = context.watch<DatabaseService>();
    final history = db.watchHistory;
    if (history.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 28),
      _SectionHeader(
        title: 'Continue Watching',
        trailing: GestureDetector(
          onTap: () {
            db.clearDatabase();
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Watch history cleared.')));
          },
          child: const Text('Clear all',
              style: TextStyle(color: _dimText, fontSize: 12)),
        ),
      ),
      const SizedBox(height: 14),
      SizedBox(
        height: 140,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: history.length,
          // FIX 12: addRepaintBoundaries=true (default) is good here
          itemBuilder: (ctx, i) {
            final item     = history[i];
            final name     = item['title'] ?? 'Untitled';
            final url      = _imgUrl(item['poster_path']);
            final progress = item['progress_seconds'] as int? ?? 0;
            final duration = item['duration_seconds'] as int? ?? 0;
            final pct      = duration > 0
                ? (progress / duration).clamp(0.0, 1.0) : 0.0;
            final rem      = duration > progress ? duration - progress : 0;
            final remLabel = rem > 0
                ? '${(rem / 60).floor()}m left'
                : (pct > 0 ? 'Watched' : 'Start');
            final epLabel  = item['media_type'] == 'tv'
                ? 'S${item['season'] ?? 1} E${item['episode'] ?? 1}'
                : 'Movie';

            return Dismissible(
              key: Key('cw_${item['id']}_${item['season']}_${item['episode']}'),
              direction: DismissDirection.up,
              onDismissed: (_) => db.removeFromHistory(item['id']),
              child: GestureDetector(
                onTap: () => onItemTap(
                    item['id'], item['media_type'] ?? 'movie'),
                child: Container(
                  width: 220,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: _card,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(fit: StackFit.expand, children: [
                    CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const ColoredBox(color: _card),
                      errorWidget: (_, __, ___) => const ColoredBox(color: _card),
                      memCacheWidth: 220,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, _black87],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.35, 1.0],
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: _black45,
                          shape: BoxShape.circle,
                          border: Border.all(color: _white30, width: 1.5),
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 24),
                      ),
                    ),
                    Positioned(
                      bottom: pct > 0 ? 8 : 12,
                      left: 10, right: 10,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                            const SizedBox(height: 3),
                            Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(epLabel,
                                      style: TextStyle(
                                          color: AppTheme.accent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _black54,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(remLabel,
                                        style: const TextStyle(
                                            color: Color(0xB3FFFFFF),
                                            fontSize: 9)),
                                  ),
                                ]),
                          ]),
                    ),
                    if (pct > 0)
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: _white12,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.accent),
                          minHeight: 3,
                        ),
                      ),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// CONTENT ROW — extracted StatelessWidget with RepaintBoundary at call site
// ═════════════════════════════════════════════════════════════════════════════
class _ContentRow extends StatelessWidget {
  const _ContentRow({
    required this.title,
    required this.items,
    required this.sectionKey,
    required this.isLoading,
    required this.onSeeAll,
    required this.onItemTap,
    this.accentColor,
    this.platformLogoUrl,
    this.showFreeBadge = false,
  });

  final String title;
  final List<dynamic> items;
  final GlobalKey sectionKey;
  final bool isLoading, showFreeBadge;
  final Color? accentColor;
  final String? platformLogoUrl;
  final VoidCallback onSeeAll;
  final void Function(dynamic item, String posterUrl) onItemTap;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 32),
      _SectionHeader(
        key: sectionKey,
        title: title,
        accentColor: accentColor,
        platformLogoUrl: platformLogoUrl,
        trailing: items.isNotEmpty
            ? GestureDetector(
          onTap: onSeeAll,
          child: Row(children: [
            Text('See all',
                style: TextStyle(
                    color: accentColor ?? AppTheme.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            const SizedBox(width: 3),
            Icon(Icons.arrow_forward_ios_rounded,
                color: accentColor ?? AppTheme.accent, size: 10),
          ]),
        )
            : null,
      ),
      const SizedBox(height: 14),
      isLoading
          ? ShimmerLoadingPresets.horizontalPostersSkeleton()
          : _PosterRow(items: items, showFreeBadge: showFreeBadge,
          onItemTap: onItemTap),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// POSTER ROW
// ═════════════════════════════════════════════════════════════════════════════
class _PosterRow extends StatelessWidget {
  const _PosterRow({
    required this.items,
    required this.onItemTap,
    this.showFreeBadge = false,
  });

  final List<dynamic> items;
  final bool showFreeBadge;
  final void Function(dynamic item, String posterUrl) onItemTap;

  static String _imgUrl(String? path) {
    if (path == null || path.isEmpty) {
      return 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=300';
    }
    if (path.startsWith('http')) return path;
    return 'https://image.tmdb.org/t/p/w300$path';
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text('Nothing here yet.',
              style: TextStyle(color: _dimText, fontSize: 13)),
        ),
      );
    }

    return SizedBox(
      height: 210,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        // FIX 13: itemExtent gives ListView O(1) layout instead of O(n)
        itemExtent: 132, // 120 width + 12 margin
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final item   = items[i];
          final name   = item['title'] ?? item['name'] ?? 'Untitled';
          final rating = (item['vote_average'] as num?)?.toDouble() ?? 0.0;
          final url    = _imgUrl(item['poster_path']);

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => onItemTap(item, url),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Hero(
                        tag: 'poster_${item['id']}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(fit: StackFit.expand, children: [
                            CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                              const ImageShimmerPlaceholder(borderRadius: 12),
                              errorWidget: (_, __, ___) => const ColoredBox(
                                color: _card,
                                child: Icon(Icons.movie_rounded,
                                    color: Color(0x1FFFFFFF), size: 36),
                              ),
                              memCacheWidth: 120,
                            ),
                            if (showFreeBadge)
                              Positioned(
                                top: 7, left: 7,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF388E3C),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('FREE',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                            Positioned(
                              bottom: 7, right: 7,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _black55,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.star_rounded,
                                              color: _gold, size: 10),
                                          const SizedBox(width: 3),
                                          Text(rating.toStringAsFixed(1),
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold)),
                                        ]),
                                  ),
                                ),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            height: 1.35)),
                  ]),
            ),
          );
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// UPCOMING SECTION
// ═════════════════════════════════════════════════════════════════════════════
class _UpcomingSection extends StatelessWidget {
  const _UpcomingSection({
    required this.sectionKey,
    required this.items,
    required this.onSeeAll,
    required this.onItemTap,
  });

  final GlobalKey sectionKey;
  final List<dynamic> items;
  final VoidCallback onSeeAll;
  final ValueChanged<dynamic> onItemTap;

  static String _imgUrl(String? path) {
    if (path == null || path.isEmpty) {
      return 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=300';
    }
    if (path.startsWith('http')) return path;
    return 'https://image.tmdb.org/t/p/w300$path';
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
        key: sectionKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          _SectionHeader(
            title: 'Upcoming Releases',
            accentColor: _gold,
            trailing: GestureDetector(
              onTap: onSeeAll,
              child: const Row(children: [
                Text('See all',
                    style: TextStyle(
                        color: _gold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                SizedBox(width: 3),
                Icon(Icons.arrow_forward_ios_rounded, color: _gold, size: 10),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 230,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemExtent: 132,
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final item = items[i];
                final name = item['title'] ?? 'Upcoming';
                final url  = _imgUrl(item['poster_path']);
                final date = item['release_date'] ?? 'Coming Soon';

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => onItemTap(item),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Stack(fit: StackFit.expand, children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: url,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) =>
                                  const ColoredBox(color: _card),
                                  errorWidget: (_, __, ___) =>
                                  const ColoredBox(color: _card),
                                  memCacheWidth: 120,
                                ),
                              ),
                              const Positioned(
                                top: 8, right: 8,
                                child: _SoonBadge(),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 7),
                          Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(date,
                              style: const TextStyle(
                                  color: _gold,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ]),
                  ),
                );
              },
            ),
          ),
        ]);
  }
}

class _SoonBadge extends StatelessWidget {
  const _SoonBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xE6F5C842),
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Text('SOON',
          style: TextStyle(
              color: Colors.black,
              fontSize: 8,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5)),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// FREE SECTION
// ═════════════════════════════════════════════════════════════════════════════
class _FreeSection extends StatelessWidget {
  const _FreeSection({
    required this.sectionKey,
    required this.items,
    required this.hasApiKey,
    required this.onItemTap,
  });

  final GlobalKey sectionKey;
  final List<dynamic> items;
  final bool hasApiKey;
  final void Function(dynamic item, String url) onItemTap;

  @override
  Widget build(BuildContext context) {
    final displayItems = hasApiKey ? items : items.take(3).toList();

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          _SectionHeader(
            key: sectionKey,
            title: 'Free to Watch',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0x1F69FF72),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0x4D69FF72)),
              ),
              child: const Text('NO COST',
                  style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8)),
            ),
          ),
          const SizedBox(height: 14),
          _PosterRow(
              items: displayItems,
              showFreeBadge: true,
              onItemTap: onItemTap),
        ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// GENRE / YEAR / PILL CHIPS — all StatelessWidgets, built by ListView.builder
// ═════════════════════════════════════════════════════════════════════════════
class _GenreChip extends StatelessWidget {
  const _GenreChip({required this.genre});
  final _Genre genre;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => FilteredResultsScreen(
              title: genre.name, genreId: genre.id))),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _white07),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(genre.icon, color: AppTheme.accent, size: 15),
          const SizedBox(width: 8),
          Text(genre.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

class _YearChip extends StatelessWidget {
  const _YearChip({required this.year});
  final String year;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => FilteredResultsScreen(title: year, year: year))),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0x0DFFFFFF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _white07),
        ),
        child: Text(year,
            style: const TextStyle(
                color: _dimText,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _JumpPillChip extends StatelessWidget {
  const _JumpPillChip({required this.pill, required this.onTap});
  final _Pill pill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          // FIX 14: Pre-compute alpha from color constant, avoid withOpacity
          color: Color.fromARGB(
              (0.08 * 255).round(),
              pill.color.red, pill.color.green, pill.color.blue),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Color.fromARGB(
              (0.22 * 255).round(),
              pill.color.red, pill.color.green, pill.color.blue)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(pill.icon, color: pill.color, size: 13),
          const SizedBox(width: 6),
          Text(pill.label,
              style: TextStyle(
                  color: pill.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// API KEY WARNING — const widget
// ═════════════════════════════════════════════════════════════════════════════
class _ApiKeyWarning extends StatelessWidget {
  const _ApiKeyWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1620),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x40FFCA28)),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: const Color(0x1FFFCA28),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.key_rounded,
              color: Colors.amberAccent, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Demo Mode',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const SizedBox(height: 2),
                Text('Add a TMDB API key in config.dart for live data.',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11)),
              ]),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// DRAWER WIDGETS
// ═════════════════════════════════════════════════════════════════════════════
class _DrawerProfileCard extends StatelessWidget {
  const _DrawerProfileCard({
    required this.username,
    required this.sub,
    required this.profileColor,
    required this.isPremium,
  });

  final String username, sub;
  final Color profileColor;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            profileColor.withOpacity(0.22),
            profileColor.withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: profileColor.withOpacity(0.25)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: profileColor.withOpacity(0.25),
          child: Text(
            username.substring(0, 1).toUpperCase(),
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: profileColor),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(username,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                const SizedBox(height: 2),
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _dimText, fontSize: 11)),
              ]),
        ),
        if (isPremium)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0x1F64FFDA),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x4D64FFDA)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.verified_rounded, color: Colors.tealAccent, size: 11),
              SizedBox(width: 4),
              Text('PRO',
                  style: TextStyle(
                      color: Colors.tealAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ]),
          ),
      ]),
    );
  }
}

class _DrawerLabel extends StatelessWidget {
  const _DrawerLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 5),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              color: _dimText,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5)),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
        child: ListTile(
          dense: true,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          leading: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          title: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          trailing: const Icon(Icons.chevron_right_rounded,
              color: Color(0x26FFFFFF), size: 16),
        ),
      ),
    );
  }
}

class _DrawerUpgradeCard extends StatelessWidget {
  const _DrawerUpgradeCard({required this.isPremium, required this.onTap});
  final bool isPremium;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isPremium
                ? [const Color(0x1F64FFDA), const Color(0x0A64FFDA)]
                : [AppTheme.accent.withValues(alpha: 0.15), AppTheme.accent.withValues(alpha: 0.05)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPremium
                ? const Color(0x4064FFDA)
                : AppTheme.accent.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isPremium ? Icons.verified_rounded : Icons.workspace_premium_rounded,
              color: isPremium ? Colors.tealAccent : AppTheme.accent,
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
                  const SizedBox(height: 2),
                  Text(
                    isPremium
                        ? 'Lifetime · Ad-free'
                        : 'Remove ads · \$1.99 lifetime',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (!isPremium)
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppTheme.accent,
                size: 12,
              ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHARED SECTION HEADER
// ═════════════════════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.accentColor,
    this.platformLogoUrl,
  });

  final String  title;
  final Widget? trailing;
  final Color?  accentColor;
  final String? platformLogoUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        if (platformLogoUrl != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: platformLogoUrl!,
              width: 18, height: 18,
              fit: BoxFit.contain,
              placeholder: (_, __) => const SizedBox.shrink(),
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Container(
          width: 3, height: 17,
          decoration: BoxDecoration(
            color: accentColor ?? AppTheme.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.2)),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class _DrawerDivider extends StatelessWidget {
  const _DrawerDivider();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Divider(color: Color(0x1AFFFFFF), height: 1),
  );
}