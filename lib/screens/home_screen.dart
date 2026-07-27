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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  // ── Connection ────────────────────────────────────────────────────────────
  bool _isOffline = false;

  // ── Hero carousel ─────────────────────────────────────────────────────────
  late PageController _pageController;
  Timer? _carouselTimer;
  int _currentPage = 0;
  bool _isCarouselActive = true;

  // ── Scroll / app-bar fade ─────────────────────────────────────────────────
  final ScrollController _scrollController = ScrollController();
  double _appBarOpacity = 0.0;

  // ── Section keys (for pill navigation) ───────────────────────────────────
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

  // ── Image URL helpers ─────────────────────────────────────────────────────
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
    _heroTextController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _carouselTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _startCarouselTimer(Provider.of<TMDBService>(context, listen: false).trending.take(6).length);
    }
  }

  void _onScroll() {
    final opacity = (_scrollController.offset / 120).clamp(0.0, 1.0);
    if ((opacity - _appBarOpacity).abs() > 0.01) {
      setState(() => _appBarOpacity = opacity);
    }
  }

  Future<void> _initApp() async {
    await _checkConnection();
    if (mounted) {
      final tmdb = Provider.of<TMDBService>(context, listen: false);
      await tmdb.fetchTrending();
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _startCarouselTimer(tmdb.trending.take(6).length);
          _heroTextController.forward();
        });
      }
    }
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

  // ── Colors ────────────────────────────────────────────────────────────────
  static const Color _bg       = Color(0xFF080810);
  static const Color _surface  = Color(0xFF0F0F1E);
  static const Color _card     = Color(0xFF14142A);
  static const Color _dimText  = Color(0xFF8888AA);
  static const Color _gold     = Color(0xFFF5C842);

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final tmdb     = Provider.of<TMDBService>(context);
    final db       = Provider.of<DatabaseService>(context);
    final trending = tmdb.trending;
    final carousel = trending.take(6).toList();

    return Scaffold(
      backgroundColor: _bg,
      extendBodyBehindAppBar: true,
      drawer: _buildDrawer(context, db),

      // ── Frosted glass app-bar that fades in on scroll ──────────────────
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AnimatedOpacity(
          opacity: _appBarOpacity,
          duration: const Duration(milliseconds: 80),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: _bg.withOpacity(0.72),
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
                      RichText(text: TextSpan(children: [
                        TextSpan(
                          text: 'Cine',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w300,
                            color: Colors.white.withOpacity(0.9),
                            letterSpacing: 1,
                          ),
                        ),
                        const TextSpan(
                          text: 'Sync',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ])),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.search_rounded,
                            color: Colors.white.withOpacity(0.8), size: 24),
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

      body: RefreshIndicator(
        color: AppTheme.accent,
        backgroundColor: _surface,
        onRefresh: () async {
          await _checkConnection();
          if (mounted) await tmdb.fetchTrending();
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          slivers: [

            // ── 1. Full-bleed hero carousel ──────────────────────────────
            SliverToBoxAdapter(
              child: tmdb.isLoading
                  ? ShimmerLoadingPresets.heroBannerSkeleton()
                  : trending.isEmpty
                  ? const SizedBox(
                  height: 300,
                  child: Center(
                    child: Text('No trending titles.',
                        style: TextStyle(color: _dimText)),
                  ))
                  : _buildHeroCarousel(context, carousel),
            ),

            // ── 2. Status banners ────────────────────────────────────────
            if (_isOffline)
              SliverToBoxAdapter(child: _buildOfflineStrip()),
            if (!tmdb.hasApiKey && !_isOffline)
              SliverToBoxAdapter(child: _buildApiKeyWarning()),

            // ── 3. Continue Watching ─────────────────────────────────────
            SliverToBoxAdapter(
                child: _buildContinueWatching(context, db, tmdb)),

            // ── 4. Genre pills ───────────────────────────────────────────
            SliverToBoxAdapter(child: _buildGenreStrip(context)),

            // ── 5. Year chips ────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildYearStrip(context)),

            // ── 6. Section jump pills ────────────────────────────────────
            SliverToBoxAdapter(child: _buildJumpPills(context)),

            // ── 7. Content rows ──────────────────────────────────────────
            ..._contentRows(context, tmdb),

            // bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HERO CAROUSEL
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeroCarousel(BuildContext context, List<dynamic> items) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.68,
      child: Stack(children: [
        RepaintBoundary(
          child: PageView.builder(
            controller: _pageController,
            itemCount: items.length,
            onPageChanged: (i) {
              setState(() => _currentPage = i);
              _heroTextController
                ..reset()
                ..forward();
            },
            itemBuilder: (ctx, i) => _buildHeroSlide(ctx, items[i], i),
          ),
        ),

        // Page indicator dots
        Positioned(
          bottom: 28,
          left: 0, right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(items.length, (i) {
              final sel = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: sel ? 22 : 5,
                height: 5,
                decoration: BoxDecoration(
                  color: sel ? AppTheme.accent : Colors.white30,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),

        // Transparent top area
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              child: Row(children: [
                Builder(builder: (ctx) => _glassCircleButton(
                  Icons.menu_rounded,
                      () => Scaffold.of(ctx).openDrawer(),
                )),
                const Spacer(),
                RichText(text: TextSpan(children: [
                  TextSpan(
                    text: 'Cine',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w300,
                      color: Colors.white.withOpacity(0.85),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const TextSpan(
                    text: 'Sync',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ])),
                const Spacer(),
                _glassCircleButton(Icons.search_rounded, () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SearchScreen()))),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _glassCircleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withOpacity(0.15)),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSlide(BuildContext context, dynamic item, int index) {
    final title    = item['title'] ?? item['name'] ?? 'Untitled';
    final overview = item['overview'] ?? '';
    final rating   = (item['vote_average'] as num?)?.toDouble() ?? 0.0;
    final imgUrl   = _imageUrl(item['backdrop_path'], isBackdrop: true);

    return GestureDetector(
      onTap: () => _pushDetails(context, item),
      child: Stack(fit: StackFit.expand, children: [
        // Cached backdrop
        CachedNetworkImage(
          imageUrl: imgUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: _card),
          errorWidget: (_, __, ___) => Container(color: _card),
          memCacheWidth: 640,
          maxWidthDiskCache: 1280,
        ),

        // Cinematic gradient
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                _bg.withOpacity(0.25),
                _bg.withOpacity(0.72),
                _bg,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.42, 0.72, 1.0],
            ),
          ),
        ),

        // Left-side vignette
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_bg.withOpacity(0.55), Colors.transparent],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),

        // Text content
        Positioned(
          left: 20, right: 80, bottom: 52,
          child: SlideTransition(
            position: _heroTextSlide,
            child: FadeTransition(
              opacity: _heroTextFade,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    _heroBadge(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.star_rounded,
                            color: _gold, size: 12),
                        const SizedBox(width: 4),
                        Text(rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            )),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    _heroBadge(
                      child: Text(
                        item['media_type'] == 'tv' ? 'SERIES' : 'FILM',
                        style: TextStyle(
                          color: AppTheme.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
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
                        shadows: [
                          Shadow(
                              blurRadius: 20,
                              color: Colors.black,
                              offset: Offset(0, 4))
                        ],
                      )),
                  const SizedBox(height: 10),
                  Text(overview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xAAFFFFFF),
                          height: 1.5)),
                  const SizedBox(height: 20),
                  Row(children: [
                    ElevatedButton.icon(
                      onPressed: () => _pushDetails(context, item),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.play_arrow_rounded,
                          size: 22, color: Colors.black),
                      label: const Text('Watch Now',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.black)),
                    ),
                    const SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: GestureDetector(
                          onTap: () => _pushDetails(context, item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 13),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.22)),
                            ),
                            child: const Row(mainAxisSize: MainAxisSize.min,
                                children: [
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
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _heroBadge({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.45),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: child,
        ),
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
        color: Colors.red.shade900.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
      ),
      child: const Row(children: [
        Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 16),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'You\'re offline — showing cached content.',
            style: TextStyle(
                color: Colors.white70, fontSize: 12),
          ),
        ),
      ]),
    );
  }

  Widget _buildApiKeyWarning() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1620),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Colors.amberAccent.withOpacity(0.25)),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: Colors.amberAccent.withOpacity(0.12),
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

  // ─────────────────────────────────────────────────────────────────────────
  // CONTINUE WATCHING
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildContinueWatching(
      BuildContext context, DatabaseService db, TMDBService tmdb) {
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
              style: TextStyle(
                  color: _dimText, fontSize: 12)),
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
          itemBuilder: (ctx, i) {
            final item = history[i];
            final name = item['title'] ?? 'Untitled';
            final url = _imageUrl(item['poster_path'], width: 300);
            final progress = item['progress_seconds'] as int? ?? 0;
            final duration = item['duration_seconds'] as int? ?? 0;
            final pct = duration > 0 ? (progress / duration).clamp(0.0, 1.0) : 0.0;
            final rem = duration > progress ? duration - progress : 0;
            final remLabel = rem > 0
                ? '${(rem / 60).floor()}m left'
                : (pct > 0 ? 'Watched' : 'Start');
            final epLabel = item['media_type'] == 'tv'
                ? 'S${item['season'] ?? 1} E${item['episode'] ?? 1}'
                : 'Movie';

            return Dismissible(
              key: Key('cw_${item['id']}_${item['season']}_${item['episode']}'),
              direction: DismissDirection.up,
              onDismissed: (_) => db.removeFromHistory(item['id']),
              child: GestureDetector(
                onTap: () => Navigator.push(ctx, MaterialPageRoute(
                    builder: (_) => DetailsScreen(
                        id: item['id'],
                        mediaType: item['media_type'] ?? 'movie'))),
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
                      placeholder: (_, __) => Container(color: _card),
                      errorWidget: (_, __, ___) => Container(color: _card),
                      memCacheWidth: 220,
                    ),

                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.black87],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.35, 1.0],
                        ),
                      ),
                    ),

                    Center(child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.6), width: 1.5),
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 24),
                    )),

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
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(remLabel,
                                        style: const TextStyle(
                                            color: Colors.white70, fontSize: 9)),
                                  ),
                                ]),
                          ]),
                    ),

                    if (pct > 0)
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: Colors.white12,
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

  // ─────────────────────────────────────────────────────────────────────────
  // GENRE STRIP
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildGenreStrip(BuildContext context) {
    final genres = [
      {'id': '28',    'name': 'Action',    'icon': Icons.flash_on_rounded},
      {'id': '35',    'name': 'Comedy',    'icon': Icons.sentiment_very_satisfied_rounded},
      {'id': '27',    'name': 'Horror',    'icon': Icons.nights_stay_rounded},
      {'id': '878',   'name': 'Sci-Fi',    'icon': Icons.rocket_launch_rounded},
      {'id': '10749', 'name': 'Romance',   'icon': Icons.favorite_rounded},
      {'id': '16',    'name': 'Animation', 'icon': Icons.animation_rounded},
      {'id': '18',    'name': 'Drama',     'icon': Icons.theater_comedy_rounded},
      {'id': '53',    'name': 'Thriller',  'icon': Icons.visibility_rounded},
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 28),
      const Padding(
        padding: EdgeInsets.only(left: 20, bottom: 12),
        child: Text('Genres',
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
          itemBuilder: (ctx, i) {
            final g = genres[i];
            return GestureDetector(
              onTap: () => Navigator.push(ctx, MaterialPageRoute(
                  builder: (_) => FilteredResultsScreen(
                      title: g['name'] as String,
                      genreId: g['id'] as String))),
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.07)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(g['icon'] as IconData,
                      color: AppTheme.accent, size: 15),
                  const SizedBox(width: 8),
                  Text(g['name'] as String,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // YEAR STRIP
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildYearStrip(BuildContext context) {
    final years = ['2025', '2024', '2023', '2022', '2020s', '2010s', '2000s'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 20),
      const Padding(
        padding: EdgeInsets.only(left: 20, bottom: 10),
        child: Text('By Year',
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
          itemBuilder: (ctx, i) {
            final y = years[i];
            return GestureDetector(
              onTap: () => Navigator.push(ctx, MaterialPageRoute(
                  builder: (_) => FilteredResultsScreen(
                      title: y, year: y))),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.07)),
                ),
                child: Text(y,
                    style: const TextStyle(
                        color: _dimText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            );
          },
        ),
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECTION JUMP PILLS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildJumpPills(BuildContext context) {
    final pills = [
      {'label': 'Trending',  'key': _trendingKey,  'icon': Icons.trending_up_rounded,            'color': AppTheme.accent},
      {'label': 'Movies',    'key': _moviesKey,    'icon': Icons.movie_rounded,                  'color': AppTheme.accent},
      {'label': 'TV Shows',  'key': _seriesKey,    'icon': Icons.tv_rounded,                     'color': AppTheme.accent},
      {'label': 'Upcoming',  'key': _upcomingKey,  'icon': Icons.event_note_rounded,             'color': const Color(0xFFF5C842)},
      {'label': 'Netflix',   'key': _netflixKey,   'icon': Icons.play_circle_fill_rounded,       'color': Colors.redAccent},
      {'label': 'Prime',     'key': _primeKey,     'icon': Icons.star_rounded,                   'color': Colors.lightBlueAccent},
      {'label': 'Disney+',   'key': _disneyKey,    'icon': Icons.auto_awesome_rounded,           'color': Colors.blueAccent},
      {'label': 'Action',    'key': _actionKey,    'icon': Icons.sports_martial_arts_rounded,    'color': AppTheme.accent},
      {'label': 'Comedy',    'key': _comedyKey,    'icon': Icons.emoji_emotions_rounded,         'color': AppTheme.accent},
      {'label': 'Sci-Fi',    'key': _scifiKey,     'icon': Icons.rocket_launch_rounded,          'color': AppTheme.accent},
      {'label': 'Horror',    'key': _horrorKey,    'icon': Icons.dangerous_rounded,              'color': AppTheme.accent},
      {'label': 'Bollywood', 'key': _bollywoodKey, 'icon': Icons.music_note_rounded,             'color': Colors.deepOrangeAccent},
      {'label': 'Pakistani', 'key': _pakistaniKey, 'icon': Icons.language_rounded,               'color': Colors.greenAccent},
      {'label': 'Free',      'key': _freeKey,      'icon': Icons.card_giftcard_rounded,          'color': Colors.greenAccent},
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 24),
      const Padding(
        padding: EdgeInsets.only(left: 20, bottom: 10),
        child: Text('Jump To',
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
            final color = p['color'] as Color;
            return GestureDetector(
              onTap: () => _scrollToSection(p['key'] as GlobalKey),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: color.withOpacity(0.22)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(p['icon'] as IconData, color: color, size: 13),
                  const SizedBox(width: 6),
                  Text(p['label'] as String,
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
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
  List<Widget> _contentRows(BuildContext context, TMDBService tmdb) {
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
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                _SectionHeader(
                  key: key,
                  title: title,
                  accentColor: accentColor,
                  platformLogoUrl: platformLogoUrl,
                  trailing: items.isNotEmpty
                      ? GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => SeeAllScreen(
                                categoryTitle: title,
                                initialItems: items))),
                    child: Row(children: [
                      Text('See all',
                          style: TextStyle(
                              color: accentColor ?? AppTheme.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 3),
                      Icon(Icons.arrow_forward_ios_rounded,
                          color: accentColor ?? AppTheme.accent,
                          size: 10),
                    ]),
                  )
                      : null,
                ),
                const SizedBox(height: 14),
                isLoading || tmdb.isLoading
                    ? ShimmerLoadingPresets.horizontalPostersSkeleton()
                    : _buildPosterRow(context, items,
                    showFreeBadge: showFreeBadge),
              ]),
        ),
      );
    }

    return [
      row('Trending Today',               tmdb.trending,      _trendingKey),
      row('Blockbuster Movies',           tmdb.movies,        _moviesKey),
      row('TV Shows & Series',            tmdb.series,        _seriesKey),
      row('Bollywood Hits',               tmdb.bollywood,     _bollywoodKey,
          accentColor: Colors.deepOrangeAccent),
      row('Pakistani Dramas & Films',     tmdb.pakistani,     _pakistaniKey,
          accentColor: Colors.greenAccent),
      SliverToBoxAdapter(
          child: _buildUpcomingSection(context, tmdb)),
      row('Streaming on Netflix',         tmdb.netflix,       _netflixKey,
          accentColor: Colors.redAccent,
          platformLogoUrl:
          'https://upload.wikimedia.org/wikipedia/commons/f/ff/Netflix-new-icon.png'),
      row('Streaming on Prime Video',     tmdb.prime,         _primeKey,
          accentColor: Colors.lightBlueAccent,
          platformLogoUrl:
          'https://upload.wikimedia.org/wikipedia/commons/d/de/Amazon_icon.png'),
      row('Streaming on Disney+',         tmdb.disney,        _disneyKey,
          accentColor: Colors.blueAccent,
          platformLogoUrl:
          'https://upload.wikimedia.org/wikipedia/commons/3/3e/Disney%2B_logo.png'),
      row('Action & Thrillers',           tmdb.actionMovies,  _actionKey),
      row('Comedies',                     tmdb.comedyMovies,  _comedyKey),
      row('Sci-Fi & Cyberpunk',           tmdb.scifiMovies,   _scifiKey),
      row('Horror & Mystery',             tmdb.horrorMovies,  _horrorKey),
      SliverToBoxAdapter(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              _SectionHeader(
                key: _freeKey,
                title: 'Free to Watch',
                trailing: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: Colors.greenAccent.withOpacity(0.3)),
                    ),
                    child: const Text('NO COST',
                        style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8)),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              _buildPosterRow(context,
                  tmdb.hasApiKey ? tmdb.trending : tmdb.trending.take(3).toList(),
                  showFreeBadge: true),
            ]),
      ),
    ];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UPCOMING SECTION
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildUpcomingSection(BuildContext context, TMDBService tmdb) {
    final list = tmdb.upcoming;
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
        key: _upcomingKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          _SectionHeader(
            title: 'Upcoming Releases',
            accentColor: _gold,
            trailing: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const UpcomingReleasesScreen())),
              child: const Row(children: [
                Text('See all',
                    style: TextStyle(
                        color: _gold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                SizedBox(width: 3),
                Icon(Icons.arrow_forward_ios_rounded,
                    color: _gold, size: 10),
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
              itemCount: list.length,
              itemBuilder: (ctx, i) {
                final item = list[i];
                final name = item['title'] ?? 'Upcoming';
                final url = _imageUrl(item['poster_path'], width: 300);
                final date = item['release_date'] ?? 'Coming Soon';

                return GestureDetector(
                  onTap: () => _pushDetails(ctx, item, mediaType: 'movie'),
                  child: Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 12),
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
                                  placeholder: (_, __) => Container(color: _card),
                                  errorWidget: (_, __, ___) => Container(color: _card),
                                  memCacheWidth: 120,
                                ),
                              ),
                              Positioned(
                                top: 8, right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _gold.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: const Text('SOON',
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5)),
                                ),
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

  // ─────────────────────────────────────────────────────────────────────────
  // POSTER ROW
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPosterRow(BuildContext context, List<dynamic> items,
      {bool showFreeBadge = false}) {
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
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final item = items[i];
          final name = item['title'] ?? item['name'] ?? 'Untitled';
          final rating = (item['vote_average'] as num?)?.toDouble() ?? 0.0;
          final url = _imageUrl(item['poster_path'], width: 300);

          return GestureDetector(
            onTap: () => _pushDetails(ctx, item, posterUrl: url),
            child: Container(
              width: 120,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Hero(
                        tag: 'poster_${item['id']}',
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(fit: StackFit.expand, children: [
                              CachedNetworkImage(
                                imageUrl: url,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const ImageShimmerPlaceholder(borderRadius: 12),
                                errorWidget: (_, __, ___) => Container(
                                    color: _card,
                                    child: const Icon(Icons.movie_rounded,
                                        color: Colors.white12, size: 36)),
                                memCacheWidth: 120,
                              ),

                              if (showFreeBadge)
                                Positioned(
                                  top: 7, left: 7,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade700,
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
                                    filter: ImageFilter.blur(
                                        sigmaX: 8, sigmaY: 8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.55),
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

  // ─────────────────────────────────────────────────────────────────────────
  // DRAWER (unchanged - already excellent)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDrawer(BuildContext context, DatabaseService db) {
    final isPremium = db.isPremium;
    final isLoggedIn = db.isLoggedIn;
    final username = isLoggedIn ? db.username : db.currentProfile;
    final sub = isLoggedIn ? db.email : (isPremium ? 'Premium Active' : 'Free Account');

    Color profileColor = AppTheme.accent;
    if (db.currentProfile == 'Family') profileColor = Colors.blueAccent;
    if (db.currentProfile == 'Kids')   profileColor = Colors.greenAccent;

    void navTo(Widget screen) {
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    }

    return Drawer(
      backgroundColor: _surface,
      child: SafeArea(
        child: Column(children: [
          Container(
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
              border: Border.all(
                  color: profileColor.withOpacity(0.25)),
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
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                          style: const TextStyle(
                              color: _dimText, fontSize: 11)),
                    ]),
              ),
              if (isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.tealAccent.withOpacity(0.3)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded,
                            color: Colors.tealAccent, size: 11),
                        SizedBox(width: 4),
                        Text('PRO',
                            style: TextStyle(
                                color: Colors.tealAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ]),
                ),
            ]),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _drawerLabel('Discover'),
                    _drawerItem(
                      icon: Icons.calendar_month_rounded,
                      label: 'Upcoming Releases',
                      color: Colors.amberAccent,
                      onTap: () => navTo(const UpcomingReleasesScreen()),
                    ),
                    _drawerItem(
                      icon: Icons.history_rounded,
                      label: 'Watch History',
                      color: Colors.lightBlueAccent,
                      onTap: () => navTo(const WatchHistoryScreen()),
                    ),
                    _drawerItem(
                      icon: Icons.download_for_offline_rounded,
                      label: 'Offline Downloads',
                      color: Colors.greenAccent,
                      onTap: () => navTo(const DownloadsScreen()),
                    ),
                    const _DrawerDivider(),
                    _drawerLabel('Account'),
                    _drawerItem(
                      icon: Icons.settings_rounded,
                      label: 'Settings',
                      color: _dimText,
                      onTap: () => navTo(const SettingsScreen()),
                    ),
                    if (!isLoggedIn)
                      _drawerItem(
                        icon: Icons.login_rounded,
                        label: 'Sign In / Sign Up',
                        color: AppTheme.accent,
                        onTap: () => navTo(
                            const LoginScreen(showSkipButton: false)),
                      ),
                    const _DrawerDivider(),

                    GestureDetector(
                      onTap: () => navTo(const SettingsScreen()),
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isPremium
                                ? [Colors.tealAccent.withOpacity(0.12),
                              Colors.tealAccent.withOpacity(0.04)]
                                : [AppTheme.accent.withOpacity(0.15),
                              AppTheme.accent.withOpacity(0.05)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isPremium
                                ? Colors.tealAccent.withOpacity(0.25)
                                : AppTheme.accent.withOpacity(0.3),
                          ),
                        ),
                        child: Row(children: [
                          Icon(
                            isPremium
                                ? Icons.verified_rounded
                                : Icons.workspace_premium_rounded,
                            color: isPremium
                                ? Colors.tealAccent
                                : AppTheme.accent,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isPremium
                                        ? 'Premium Pro Active'
                                        : 'Upgrade to Premium',
                                    style: TextStyle(
                                      color: isPremium
                                          ? Colors.tealAccent
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    isPremium
                                        ? 'Lifetime · Ad-free'
                                        : 'Remove ads · \$1.99 lifetime',
                                    style: const TextStyle(
                                        color: _dimText, fontSize: 11),
                                  ),
                                ]),
                          ),
                          if (!isPremium)
                            Icon(Icons.arrow_forward_ios_rounded,
                                color: AppTheme.accent, size: 12),
                        ]),
                      ),
                    ),
                  ]),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(children: [
              const Icon(Icons.movie_filter_rounded,
                  color: Colors.white12, size: 12),
              const SizedBox(width: 6),
              Text('CineSync  v1.2.0',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.1),
                      fontSize: 11)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _drawerLabel(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 5),
    child: Text(text.toUpperCase(),
        style: const TextStyle(
            color: _dimText,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5)),
  );

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
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
          trailing: Icon(Icons.chevron_right_rounded,
              color: Colors.white.withOpacity(0.15), size: 16),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.accentColor,
    this.platformLogoUrl,
  });

  final String   title;
  final Widget?  trailing;
  final Color?   accentColor;
  final String?  platformLogoUrl;

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
    child: Divider(color: Colors.white10, height: 1),
  );
}