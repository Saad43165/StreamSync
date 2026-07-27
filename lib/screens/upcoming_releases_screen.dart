import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shimmer_loading.dart';
import 'details_screen.dart';

class UpcomingReleasesScreen extends StatefulWidget {
  const UpcomingReleasesScreen({super.key});

  @override
  State<UpcomingReleasesScreen> createState() => _UpcomingReleasesScreenState();
}

class _UpcomingReleasesScreenState extends State<UpcomingReleasesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _movieScroll = ScrollController();
  final ScrollController _tvScroll = ScrollController();
  String _sortBy = 'date'; // 'date' or 'title'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Kick off real fetches as soon as the screen mounts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tmdb = Provider.of<TMDBService>(context, listen: false);
      if (tmdb.upcomingMoviesFeed.isEmpty) tmdb.fetchUpcomingMovies();
      if (tmdb.upcomingTvFeed.isEmpty) tmdb.fetchUpcomingTv();
    });

    _movieScroll.addListener(() => _onScroll(_movieScroll, isMovie: true));
    _tvScroll.addListener(() => _onScroll(_tvScroll, isMovie: false));
  }

  void _onScroll(ScrollController controller, {required bool isMovie}) {
    if (!controller.hasClients) return;
    if (controller.position.pixels > controller.position.maxScrollExtent - 400) {
      final tmdb = Provider.of<TMDBService>(context, listen: false);
      if (isMovie) {
        if (tmdb.hasMoreUpcomingMovies && !tmdb.isLoadingUpcomingMovies) {
          tmdb.fetchUpcomingMovies(loadMore: true);
        }
      } else {
        if (tmdb.hasMoreUpcomingTv && !tmdb.isLoadingUpcomingTv) {
          tmdb.fetchUpcomingTv(loadMore: true);
        }
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _movieScroll.dispose();
    _tvScroll.dispose();
    super.dispose();
  }

  List<dynamic> _sorted(List<dynamic> items, {required String dateKey}) {
    final list = List<dynamic>.from(items);
    if (_sortBy == 'date') {
      list.sort((a, b) =>
          (a[dateKey] as String? ?? '').compareTo(b[dateKey] as String? ?? ''));
    } else {
      list.sort((a, b) => ((a['title'] ?? a['name'] ?? '') as String)
          .compareTo((b['title'] ?? b['name'] ?? '') as String));
    }
    return list;
  }

  String _formatDate(String rawDate) {
    try {
      final parts = rawDate.split('-');
      if (parts.length < 3) return rawDate;
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final monthIndex = int.parse(parts[1]) - 1;
      return '${months[monthIndex]} ${parts[2]}, ${parts[0]}';
    } catch (_) {
      return rawDate;
    }
  }

  String _getCountdown(String rawDate) {
    try {
      final releaseDate = DateTime.parse(rawDate);
      final now = DateTime.now();
      if (releaseDate.isBefore(now)) return 'Out now';
      final diff = releaseDate.difference(now);
      if (diff.inDays > 365) {
        final years = (diff.inDays / 365).floor();
        return '~$years year${years > 1 ? 's' : ''} away';
      } else if (diff.inDays > 30) {
        final months = (diff.inDays / 30).floor();
        return '~$months month${months > 1 ? 's' : ''} away';
      } else if (diff.inDays > 0) {
        return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} away';
      } else {
        return 'Today';
      }
    } catch (_) {
      return 'Coming Soon';
    }
  }

  Color _getCountdownColor(String rawDate) {
    try {
      final releaseDate = DateTime.parse(rawDate);
      final now = DateTime.now();
      if (releaseDate.isBefore(now)) return Colors.white38;
      final diff = releaseDate.difference(now);
      if (diff.inDays < 60) return Colors.greenAccent;
      if (diff.inDays < 180) return AppTheme.accent;
      return AppTheme.textSecondary;
    } catch (_) {
      return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tmdb = Provider.of<TMDBService>(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Upcoming Releases', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Live from TMDB — soonest first', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded, color: Colors.white70),
            color: AppTheme.surface,
            onSelected: (val) => setState(() => _sortBy = val),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'date',
                child: Row(children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: _sortBy == 'date' ? AppTheme.accent : Colors.white70),
                  const SizedBox(width: 8),
                  Text('Sort by Date', style: TextStyle(color: _sortBy == 'date' ? AppTheme.accent : Colors.white)),
                ]),
              ),
              PopupMenuItem(
                value: 'title',
                child: Row(children: [
                  Icon(Icons.sort_by_alpha_rounded, size: 14, color: _sortBy == 'title' ? AppTheme.accent : Colors.white70),
                  const SizedBox(width: 8),
                  Text('Sort by Title', style: TextStyle(color: _sortBy == 'title' ? AppTheme.accent : Colors.white)),
                ]),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: Colors.white,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.movie_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('Movies (${tmdb.upcomingMoviesFeed.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tv_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('Series (${tmdb.upcomingTvFeed.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMovieTab(tmdb),
          _buildTvTab(tmdb),
        ],
      ),
    );
  }

  Widget _buildMovieTab(TMDBService tmdb) {
    final items = _sorted(tmdb.upcomingMoviesFeed, dateKey: 'release_date');

    if (tmdb.isLoadingUpcomingMovies && items.isEmpty) {
      return ShimmerLoadingPresets.searchGridSkeleton();
    }
    if (tmdb.upcomingMoviesErrored && items.isEmpty) {
      return _buildErrorState(() => tmdb.fetchUpcomingMovies());
    }
    if (items.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: AppTheme.accent,
      backgroundColor: AppTheme.surface,
      onRefresh: () => tmdb.fetchUpcomingMovies(),
      child: ListView.builder(
        controller: _movieScroll,
        padding: const EdgeInsets.all(16),
        itemCount: items.length + (tmdb.hasMoreUpcomingMovies ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return _buildLoadMoreIndicator(tmdb.isLoadingUpcomingMovies);
          }
          return _buildUpcomingCard(context, items[index], dateKey: 'release_date');
        },
      ),
    );
  }

  Widget _buildTvTab(TMDBService tmdb) {
    final items = _sorted(tmdb.upcomingTvFeed, dateKey: 'first_air_date');

    if (tmdb.isLoadingUpcomingTv && items.isEmpty) {
      return ShimmerLoadingPresets.searchGridSkeleton();
    }
    if (tmdb.upcomingTvErrored && items.isEmpty) {
      return _buildErrorState(() => tmdb.fetchUpcomingTv());
    }
    if (items.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: AppTheme.accent,
      backgroundColor: AppTheme.surface,
      onRefresh: () => tmdb.fetchUpcomingTv(),
      child: ListView.builder(
        controller: _tvScroll,
        padding: const EdgeInsets.all(16),
        itemCount: items.length + (tmdb.hasMoreUpcomingTv ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return _buildLoadMoreIndicator(tmdb.isLoadingUpcomingTv);
          }
          return _buildUpcomingCard(context, items[index], dateKey: 'first_air_date');
        },
      ),
    );
  }

  Widget _buildLoadMoreIndicator(bool isLoading) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: isLoading
            ? const SizedBox(
          width: 24, height: 24,
          child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2.2),
        )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildErrorState(VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              "Couldn't load upcoming releases.\nCheck your connection and try again.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.black),
              label: const Text('Retry', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy_rounded, size: 48, color: Colors.white24),
            SizedBox(height: 16),
            Text(
              'Nothing scheduled right now — check back soon.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingCard(BuildContext context, dynamic itemRaw, {required String dateKey}) {
    final item = itemRaw as Map<String, dynamic>;
    final title = item['title'] ?? item['name'] ?? 'Untitled';
    final releaseDate = item[dateKey] as String? ?? '';
    final overview = item['overview'] as String? ?? '';
    final posterPath = item['poster_path'] as String?;
    final backdropPath = item['backdrop_path'] as String?;
    final mediaType = item['media_type'] as String? ?? 'movie';
    final genres = TMDBService.genreNamesFor(item);
    final countdown = _getCountdown(releaseDate);
    final countdownColor = _getCountdownColor(releaseDate);
    final formattedDate = releaseDate.isNotEmpty ? _formatDate(releaseDate) : 'Date TBA';

    final imageUrl = backdropPath != null
        ? '${TMDBService.backdropBaseUrl}$backdropPath'
        : (posterPath != null ? '${TMDBService.imageBaseUrl}$posterPath' : null);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetailsScreen(id: item['id'], mediaType: mediaType),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  imageUrl != null
                      ? Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(
                        height: 180,
                        child: ImageShimmerPlaceholder(borderRadius: 0),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      height: 180,
                      color: AppTheme.background,
                      child: const Icon(Icons.movie, color: Colors.white24, size: 48),
                    ),
                  )
                      : Container(
                    height: 180,
                    color: AppTheme.background,
                    child: const Icon(Icons.movie, color: Colors.white24, size: 48),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.black87],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: countdownColor.withOpacity(0.4)),
                      ),
                      child: Text(
                        countdown,
                        style: TextStyle(color: countdownColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: mediaType == 'tv'
                            ? Colors.blueAccent.withOpacity(0.7)
                            : Colors.purpleAccent.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        mediaType == 'tv' ? '📺 SERIES' : '🎬 MOVIE',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, color: Colors.white70, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          formattedDate,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  if (overview.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      overview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.5),
                    ),
                  ],
                  if (genres.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: genres.map((g) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(g, style: const TextStyle(color: Colors.white60, fontSize: 10)),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}