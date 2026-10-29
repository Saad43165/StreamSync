import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/ui_kit.dart';
import 'details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _Genre {
  final String label;
  final int? movieId;
  final int? tvId;
  final Color color;
  const _Genre(this.label, this.movieId, this.tvId, this.color);
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;
  List<String> _recentSearches = [];
  bool _isOffline = false;

  // Selected genre filter (only used while searching)
  String? _selectedType; // null=All, 'movie', 'tv'

  static const List<_Genre> _genres = [
    _Genre('Action',    28,   10759, Color(0xFFE53935)),
    _Genre('Drama',     18,   18,    Color(0xFF8E24AA)),
    _Genre('Comedy',    35,   35,    Color(0xFFF57F17)),
    _Genre('Sci-Fi',    878,  10765, Color(0xFF1565C0)),
    _Genre('Horror',    27,   9648,  Color(0xFF37474F)),
    _Genre('Romance',   10749,10749, Color(0xFFE91E63)),
    _Genre('Anime',     16,   16,    Color(0xFF00838F)),
    _Genre('Crime',     80,   80,    Color(0xFF4E342E)),
    _Genre('Fantasy',   14,   10765, Color(0xFF283593)),
    _Genre('Thriller',  53,   9648,  Color(0xFF558B2F)),
    _Genre('Animation', 16,   16,    Color(0xFF00796B)),
    _Genre('Upcoming',  null, null,  Color(0xFFBF360C)),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_searchFocusNode.hasFocus) _searchFocusNode.unfocus();
    });
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _recentSearches = prefs.getStringList('recent_searches') ?? [];
      });
    }
  }

  Future<void> _saveRecentSearch(String q) async {
    if (q.trim().isEmpty) return;
    _recentSearches.remove(q);
    _recentSearches.insert(0, q);
    if (_recentSearches.length > 10) _recentSearches = _recentSearches.take(10).toList();
    setState(() {});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recent_searches', _recentSearches);
  }

  Future<void> _clearRecentSearches() async {
    setState(() => _recentSearches.clear());
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_searches');
  }

  Future<void> _runSearch(String query) async {
    setState(() => _isOffline = false);
    try {
      await Provider.of<TMDBService>(context, listen: false).search(query);
    } catch (_) {
      if (mounted) setState(() => _isOffline = true);
    }
  }

  void _onGenreTap(_Genre genre) {
    final tmdb = Provider.of<TMDBService>(context, listen: false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _GenreResultsScreen(
          genre: genre,
          initialItems: _genreItems(tmdb, genre),
        ),
      ),
    );
  }

  List<dynamic> _genreItems(TMDBService tmdb, _Genre genre) {
    if (genre.label == 'Upcoming') return tmdb.upcoming;
    return tmdb.trending.where((item) {
      final isTv = item['media_type'] == 'tv' || item['name'] != null;
      final gId = isTv ? genre.tvId : genre.movieId;
      if (gId == null) return true;
      final genres = item['genre_ids'] as List<dynamic>? ?? [];
      return genres.contains(gId);
    }).toList();
  }

  List<dynamic> _filteredResults(TMDBService tmdb) {
    var results = tmdb.searchResults
        .where((item) => item['media_type'] == 'movie' || item['media_type'] == 'tv')
        .toList();
    if (_selectedType != null) {
      results = results.where((item) => item['media_type'] == _selectedType).toList();
    }
    return results;
  }

  void _openDetails(dynamic item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailsScreen(
          id: item['id'],
          mediaType: item['media_type'] ?? (item['title'] != null ? 'movie' : 'tv'),
          heroTag: 'search_${item['id']}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tmdb = Provider.of<TMDBService>(context);
    final isSearching = _searchController.text.isNotEmpty;
    final results = _filteredResults(tmdb);

    return Scaffold(
      backgroundColor: AppTheme.background,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: () => _searchFocusNode.unfocus(),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Sticky search header ──────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              floating: true,
              backgroundColor: AppTheme.background,
              elevation: 0,
              toolbarHeight: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(color: AppTheme.background),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(72),
                child: _buildSearchHeader(isSearching, results.length, tmdb),
              ),
            ),

            if (_isOffline)
              SliverToBoxAdapter(child: _buildOfflineBanner()),

            // ── Idle state: recents + genre browse ────────────────────────────
            if (!isSearching) ...[
              if (_recentSearches.isNotEmpty)
                SliverToBoxAdapter(child: _buildRecentSearches()),
              SliverToBoxAdapter(child: _buildBrowseHeader()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: _buildGenreGrid(),
              ),
            ]

            // ── Searching: type filter + results grid ─────────────────────────
            else ...[
              SliverToBoxAdapter(child: _buildTypeFilter(results.length, tmdb.isLoading)),
              if (tmdb.isLoading)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: ShimmerLoadingPresets.searchGridSkeleton(),
                  ),
                )
              else if (results.isEmpty)
                SliverToBoxAdapter(child: _buildEmptyState())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: _buildResultsGrid(results),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader(bool isSearching, int count, TMDBService tmdb) {
    return Container(
      color: AppTheme.background,
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 8, 16, 12),
      child: Row(children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.surfaceRaised,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: _searchFocusNode.hasFocus
                    ? AppTheme.accent
                    : Colors.white.withValues(alpha: 0.08),
                width: 1.2,
              ),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onSubmitted: (q) {
                _saveRecentSearch(q);
                _runSearch(q);
                _searchFocusNode.unfocus();
              },
              onChanged: (q) {
                if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
                _debounceTimer = Timer(const Duration(milliseconds: 350), () => _runSearch(q));
                setState(() {});
              },
              style: const TextStyle(color: Colors.white, fontSize: 15),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search movies, shows...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppTheme.accent, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          _runSearch('');
                          setState(() {});
                        },
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white38, size: 18),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ),
        if (isSearching) ...[
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              _searchController.clear();
              _runSearch('');
              setState(() {});
              _searchFocusNode.unfocus();
            },
            child: const Text('Cancel',
                style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ]),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.25)),
      ),
      child: const Row(children: [
        Icon(Icons.wifi_off_rounded, color: AppTheme.danger, size: 15),
        SizedBox(width: 8),
        Expanded(
          child: Text("Can't reach the server — showing cached results.",
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
        ),
      ]),
    );
  }

  Widget _buildRecentSearches() {
    final recent = _recentSearches.take(8).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 8, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            const Expanded(
              child: Text('Recent searches',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: _clearRecentSearches,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                minimumSize: const Size(0, 36),
              ),
              child: const Text('Clear'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final q in recent)
                ActionChip(
                  avatar: const Icon(Icons.history_rounded,
                      size: 16, color: AppTheme.textSecondary),
                  label: Text(q, overflow: TextOverflow.ellipsis),
                  onPressed: () {
                    _searchController.text = q;
                    _runSearch(q);
                    _saveRecentSearch(q);
                    setState(() {});
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ]),
    );
  }

  Widget _buildBrowseHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 16, 12),
      child: Text('Browse by genre',
          style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3)),
    );
  }

  SliverGrid _buildGenreGrid() {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (_, i) {
          final genre = _genres[i];
          return Material(
            color: AppTheme.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              side: BorderSide(color: genre.color.withValues(alpha: 0.28)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _onGenreTap(genre),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      genre.color.withValues(alpha: 0.30),
                      genre.color.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: genre.color.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Icon(_genreIcon(genre.label),
                          size: 19, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(genre.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
              ),
            ),
          );
        },
        childCount: _genres.length,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.7,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
    );
  }

  Widget _buildTypeFilter(int resultCount, bool isLoading) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 20, 8),
      child: Row(children: [
        _TypeChip(label: 'All', selected: _selectedType == null,
            onTap: () => setState(() => _selectedType = null)),
        const SizedBox(width: 8),
        _TypeChip(label: 'Movies', selected: _selectedType == 'movie',
            onTap: () => setState(() => _selectedType = 'movie')),
        const SizedBox(width: 8),
        _TypeChip(label: 'Series', selected: _selectedType == 'tv',
            onTap: () => setState(() => _selectedType = 'tv')),
        const Spacer(),
        if (!isLoading)
          Text(
            '$resultCount ${resultCount == 1 ? 'result' : 'results'}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
          ),
      ]),
    );
  }

  SliverGrid _buildResultsGrid(List<dynamic> items) {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (_, i) {
          final item = items[i];
          return _SearchPosterCard(
            item: item,
            heroTag: 'search_${item['id']}',
            onTap: () => _openDetails(item),
          );
        },
        childCount: items.length,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.5,
        crossAxisSpacing: 10,
        mainAxisSpacing: 14,
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.55,
      child: EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No results for "${_searchController.text.trim()}"',
        message: _selectedType != null
            ? 'Try switching the filter to All, or check the spelling.'
            : 'Check the spelling, or search for an actor or a different title.',
      ),
    );
  }

  IconData _genreIcon(String label) {
    switch (label) {
      case 'Action':    return Icons.local_fire_department_rounded;
      case 'Drama':     return Icons.theater_comedy_rounded;
      case 'Comedy':    return Icons.sentiment_very_satisfied_rounded;
      case 'Sci-Fi':    return Icons.rocket_launch_rounded;
      case 'Horror':    return Icons.dark_mode_rounded;
      case 'Romance':   return Icons.favorite_rounded;
      case 'Anime':     return Icons.animation_rounded;
      case 'Crime':     return Icons.gavel_rounded;
      case 'Fantasy':   return Icons.auto_fix_high_rounded;
      case 'Thriller':  return Icons.psychology_rounded;
      case 'Animation': return Icons.brush_rounded;
      case 'Upcoming':  return Icons.upcoming_rounded;
      default:          return Icons.movie_rounded;
    }
  }
}

// ── Genre Results fullscreen ──────────────────────────────────────────────────
class _GenreResultsScreen extends StatelessWidget {
  final _Genre genre;
  final List<dynamic> initialItems;

  const _GenreResultsScreen({required this.genre, required this.initialItems});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(genre.label),
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: initialItems.isEmpty
          ? const EmptyState(
              icon: Icons.movie_filter_outlined,
              title: 'Nothing here yet',
              message: 'Pull to refresh on Home to load more titles, then try again.')
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 14,
              ),
              itemCount: initialItems.length,
              itemBuilder: (_, i) {
                final item = initialItems[i];
                return _SearchPosterCard(
                  item: item,
                  heroTag: 'genre_${genre.label}_${item['id']}',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetailsScreen(
                        id: item['id'],
                        mediaType: item['media_type'] ?? 'movie',
                        heroTag: 'genre_${genre.label}_${item['id']}',
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ── Poster card (3-column) ───────────────────────────────────────────────────
class _SearchPosterCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String heroTag;
  final VoidCallback onTap;
  const _SearchPosterCard(
      {required this.item, required this.heroTag, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = item['title'] ?? item['name'] ?? '';
    final posterPath = item['poster_path'];
    final imageUrl = posterPath != null
        ? (posterPath.toString().startsWith('http')
            ? posterPath.toString()
            : '${TMDBService.imageBaseUrl}$posterPath')
        : null;
    final rating = (item['vote_average'] as num?)?.toDouble() ?? 0.0;
    final mediaType = item['media_type'] as String?;

    final date = (item['release_date'] ?? item['first_air_date'] ?? '').toString();
    final year = date.length >= 4 ? date.substring(0, 4) : '';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Hero(
              tag: heroTag,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: Stack(fit: StackFit.expand, children: [
                  imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                              color: AppTheme.surface,
                              child: const ImageShimmerPlaceholder(borderRadius: 8)),
                          errorWidget: (_, __, ___) => Container(
                            color: AppTheme.surface,
                            child: const Icon(Icons.movie_rounded,
                                color: Colors.white24, size: 32),
                          ),
                          memCacheWidth: 240,
                        )
                      : Container(
                          color: AppTheme.surface,
                          child: const Icon(Icons.movie_rounded,
                              color: Colors.white24, size: 32),
                        ),

                  // Rating badge bottom-right
                  if (rating > 0)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.star_rounded, color: AppTheme.gold, size: 11),
                          const SizedBox(width: 2),
                          Text(rating.toStringAsFixed(1),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            [
              if (mediaType != null) mediaType == 'tv' ? 'Series' : 'Film',
              if (year.isNotEmpty) year,
            ].join(' · '),
            maxLines: 1,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

// ── Type filter chip ──────────────────────────────────────────────────────────
class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.accent : AppTheme.stroke,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? AppTheme.background : AppTheme.textPrimary,
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.w500)),
      ),
    );
  }
}
