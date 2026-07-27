import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/glass_card.dart';
import 'details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _CategoryDef {
  final String label;
  final IconData icon;
  final int? movieGenreId;
  final int? tvGenreId;
  const _CategoryDef(this.label, this.icon, this.movieGenreId, this.tvGenreId);
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  static const List<_CategoryDef> _categories = [
    _CategoryDef('All', Icons.apps_rounded, null, null),
    _CategoryDef('Action', Icons.local_fire_department_rounded, 28, 10759),
    _CategoryDef('Drama', Icons.theater_comedy_rounded, 18, 18),
    _CategoryDef('Comedy', Icons.sentiment_very_satisfied_rounded, 35, 35),
    _CategoryDef('Sci-Fi', Icons.rocket_launch_rounded, 878, 10765),
    _CategoryDef('Horror', Icons.dark_mode_rounded, 27, 9648),
    _CategoryDef('Anime', Icons.animation_rounded, 16, 16),
    _CategoryDef('Upcoming', Icons.upcoming_rounded, null, null),
  ];

  int _selectedIndex = 0;
  bool _isOffline = false;

  final List<String> _recentSearches = [
    'Avengers',
    'Superman',
    'Avatar',
    'Batman',
    'Stranger Things',
  ];

  // ── Image URL helper ──────────────────────────────────────────────────────
  static String _posterUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${TMDBService.imageBaseUrl}$path';
  }

  @override
  void initState() {
    super.initState();
    // Dismiss keyboard when scrolling
    _scrollController.addListener(() {
      if (_searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _addSearchQuery(String query) {
    if (query.trim().isEmpty) return;
    setState(() {
      _recentSearches.remove(query);
      _recentSearches.insert(0, query);
      if (_recentSearches.length > 8) {
        _recentSearches.removeLast();
      }
    });
  }

  Future<void> _runSearch(String query) async {
    setState(() => _isOffline = false);
    try {
      final tmdbService = Provider.of<TMDBService>(context, listen: false);
      await tmdbService.search(query);
    } catch (_) {
      if (mounted) setState(() => _isOffline = true);
    }
  }

  Future<void> _onRefresh() async {
    final tmdbService = Provider.of<TMDBService>(context, listen: false);
    setState(() => _isOffline = false);
    try {
      if (_searchController.text.isNotEmpty) {
        await tmdbService.search(_searchController.text);
      } else {
        await tmdbService.search('');
      }
    } catch (_) {
      if (mounted) setState(() => _isOffline = true);
    }
  }

  _CategoryDef get _selectedCategory => _categories[_selectedIndex];

  @override
  Widget build(BuildContext context) {
    final tmdbService = Provider.of<TMDBService>(context);
    final isLive = tmdbService.hasApiKey;
    final isSearching = _searchController.text.isNotEmpty;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    List<dynamic> baseList;
    if (!isSearching) {
      switch (_selectedCategory.label) {
        case 'All':
          baseList = tmdbService.trending;
          break;
        case 'Action':
          baseList = tmdbService.actionMovies;
          break;
        case 'Comedy':
          baseList = tmdbService.comedyMovies;
          break;
        case 'Sci-Fi':
          baseList = tmdbService.scifiMovies;
          break;
        case 'Horror':
          baseList = tmdbService.horrorMovies;
          break;
        case 'Upcoming':
          baseList = tmdbService.upcoming;
          break;
        default:
          baseList = tmdbService.trending.where((item) {
            final isTv = (item['media_type'] == 'tv') ||
                (item['media_type'] == null && item['name'] != null);
            final genreId =
            isTv ? _selectedCategory.tvGenreId : _selectedCategory.movieGenreId;
            if (genreId == null) return true;
            final genres = item['genre_ids'] as List<dynamic>? ?? [];
            return genres.contains(genreId);
          }).toList();
      }
    } else {
      baseList = tmdbService.searchResults
          .where((item) =>
      item['media_type'] == 'movie' || item['media_type'] == 'tv')
          .toList();

      if (_selectedCategory.label != 'All') {
        baseList = baseList.where((item) {
          final isTv = item['media_type'] == 'tv';
          final genreId =
          isTv ? _selectedCategory.tvGenreId : _selectedCategory.movieGenreId;
          if (genreId == null) return true;
          final genres = item['genre_ids'] as List<dynamic>? ?? [];
          return genres.contains(genreId);
        }).toList();
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      // FIX: Use resizeToAvoidBottomInset to handle keyboard properly
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Search & Explore',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: GestureDetector(
        // Dismiss keyboard when tapping outside
        onTap: () => _searchFocusNode.unfocus(),
        child: RefreshIndicator(
          color: AppTheme.accent,
          backgroundColor: AppTheme.surface,
          onRefresh: _onRefresh,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                // FIX: Add bottom padding when keyboard is open
                bottom: bottomInset > 0 ? bottomInset + 16 : 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSearchField(tmdbService),
                  const SizedBox(height: 12),
                  _buildCategoryRow(),
                  const SizedBox(height: 16),

                  if (_isOffline) _buildOfflineBanner(),

                  if (!isSearching) ...[
                    _buildRecentSearches(tmdbService),
                  ],

                  Text(
                    isSearching ? 'SEARCH RESULTS' : 'SUGGESTED FOR YOU',
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 12),

                  // FIX: Use flexible height instead of Expanded in scrollable
                  if (tmdbService.isLoading)
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: ShimmerLoadingPresets.searchGridSkeleton(),
                    )
                  else if (baseList.isEmpty)
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.4,
                      child: _buildEmptyState(isSearching),
                    )
                  else
                    _buildResultsGrid(baseList, isLive),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(TMDBService tmdbService) {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      onSubmitted: (query) {
        _addSearchQuery(query);
        _runSearch(query);
        _searchFocusNode.unfocus();
      },
      onChanged: (query) {
        if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 400), () {
          _runSearch(query);
        });
        setState(() {});
      },
      style: const TextStyle(color: Colors.white),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search movies, series, dramas...',
        hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.accent),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
          icon: const Icon(Icons.clear_rounded, color: AppTheme.textSecondary),
          onPressed: () {
            _searchController.clear();
            _runSearch('');
            setState(() {});
          },
        )
            : null,
        filled: true,
        fillColor: AppTheme.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white10, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.accent, width: 1.4),
        ),
      ),
    );
  }

  Widget _buildCategoryRow() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _categories.length,
        itemBuilder: (context, idx) {
          final cat = _categories[idx];
          final isSel = _selectedIndex == idx;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: ChoiceChip(
                avatar: Icon(cat.icon,
                    size: 15, color: isSel ? Colors.black : Colors.white54),
                label: Text(cat.label),
                selected: isSel,
                onSelected: (_) => setState(() => _selectedIndex = idx),
                selectedColor: AppTheme.accent,
                backgroundColor: AppTheme.surface,
                labelStyle: TextStyle(
                  color: isSel ? Colors.black : Colors.white70,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: isSel ? AppTheme.accent : Colors.white12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "Couldn't reach the server — showing cached results. Pull down to retry.",
              style: TextStyle(color: Colors.redAccent, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSearches(TMDBService tmdbService) {
    if (_recentSearches.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'RECENT SEARCHES',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2),
            ),
            GestureDetector(
              onTap: () => setState(() => _recentSearches.clear()),
              child: const Text('Clear All',
                  style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _recentSearches.map((query) {
            return GestureDetector(
              onTap: () {
                _searchController.text = query;
                _runSearch(query);
                _addSearchQuery(query);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.history_rounded, size: 12, color: Colors.white38),
                    const SizedBox(width: 6),
                    Text(query, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        const Divider(color: Colors.white10),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildEmptyState(bool isSearching) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Icons.search_off_rounded : Icons.movie_outlined,
            size: 54,
            color: Colors.white24,
          ),
          const SizedBox(height: 16),
          Text(
            isSearching
                ? 'No results for that search or filter combo.'
                : 'Nothing here yet — try another category.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          if (isSearching) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => setState(() => _selectedIndex = 0),
              icon: const Icon(Icons.filter_alt_off_rounded, size: 16, color: AppTheme.accent),
              label: const Text('Clear filter', style: TextStyle(color: AppTheme.accent)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsGrid(List<dynamic> items, bool isLive) {
    // FIX: Use a fixed-height container instead of Expanded in scroll view
    final itemCount = items.length;
    final crossAxisCount = 2;
    final aspectRatio = 0.62;
    final crossAxisSpacing = 12.0;
    final mainAxisSpacing = 12.0;
    final screenWidth = MediaQuery.of(context).size.width - 32; // minus padding
    final itemWidth = (screenWidth - (crossAxisCount - 1) * crossAxisSpacing) / crossAxisCount;
    final itemHeight = itemWidth / aspectRatio;
    final rowCount = (itemCount / crossAxisCount).ceil();
    final gridHeight = rowCount * itemHeight + (rowCount - 1) * mainAxisSpacing;

    return SizedBox(
      height: gridHeight,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: const EdgeInsets.only(top: 4, bottom: 20),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: aspectRatio,
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: mainAxisSpacing,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _PosterCard(
            item: item,
            isLive: isLive,
            onTap: () {
              _addSearchQuery(_searchController.text);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetailsScreen(
                    id: item['id'],
                    mediaType:
                    item['media_type'] ?? (item['title'] != null ? 'movie' : 'tv'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PosterCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isLive;
  final VoidCallback onTap;

  const _PosterCard({required this.item, required this.isLive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = item['title'] ?? item['name'] ?? 'Untitled';
    final voteAverage = (item['vote_average'] as num?)?.toDouble() ?? 0.0;
    final rating = voteAverage > 0 ? voteAverage.toStringAsFixed(1) : '—';
    final mediaType = item['media_type'] as String?;

    final posterPath = item['poster_path'];
    final imageUrl = posterPath != null
        ? (posterPath.toString().startsWith('http')
        ? posterPath.toString()
        : '${TMDBService.imageBaseUrl}$posterPath')
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Hero(
        tag: 'poster_${item['id']}_${item['media_type'] ?? ''}',
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: AppTheme.surface,
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // FIX: Use CachedNetworkImage for better performance
                      imageUrl != null && imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                        const ImageShimmerPlaceholder(borderRadius: 16),
                        errorWidget: (_, __, ___) => Container(
                          color: AppTheme.surface,
                          child: const Icon(Icons.movie,
                              color: Colors.white24, size: 48),
                        ),
                        memCacheWidth: 200,
                      )
                          : Container(
                        color: AppTheme.surface,
                        child: const Icon(Icons.movie,
                            color: Colors.white24, size: 48),
                      ),
                      if (mediaType != null)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: (mediaType == 'tv'
                                  ? Colors.blueAccent
                                  : Colors.purpleAccent)
                                  .withOpacity(0.85),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              mediaType == 'tv' ? 'SERIES' : 'MOVIE',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      if (voteAverage > 0)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: GlassCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            borderRadius: 6,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: AppTheme.secondaryAccent, size: 12),
                                const SizedBox(width: 2),
                                Text(
                                  rating,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}