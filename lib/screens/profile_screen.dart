import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import 'settings_screen.dart';
import 'details_screen.dart';
import 'downloads_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _posterUrl(dynamic posterPath) {
    if (posterPath == null) return '';
    final path = posterPath.toString().trim();
    if (path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return 'https://image.tmdb.org/t/p/w200$path';
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final moviesWatched = db.watchHistory.length;
    final hoursWatched = db.totalHoursWatched;
    final watchlistCount = db.watchlist.length;
    final downloadCount = db.downloads.length;
    final username = db.username.isNotEmpty ? db.username : 'Guest User';
    final initial = username.isNotEmpty ? username[0].toUpperCase() : 'G';

    final profileColors = {
      'Enthusiast': AppTheme.accent,
      'Family': Colors.blueAccent,
      'Kids': Colors.greenAccent,
    };
    final themeColor = profileColors[db.currentProfile] ?? AppTheme.accent;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: NestedScrollView(
        physics: const BouncingScrollPhysics(),
        headerSliverBuilder: (context, innerBoxScrolled) => [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: AppTheme.background,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          themeColor.withValues(alpha: 0.3),
                          AppTheme.background,
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 50),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 100, height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [themeColor, themeColor.withValues(alpha: 0.4)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: themeColor.withValues(alpha: 0.4),
                                      blurRadius: 24,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(initial,
                                    style: const TextStyle(
                                      fontSize: 42, fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              if (db.isPremium)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.tealAccent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.verified_rounded,
                                      color: Colors.black,
                                      size: 18,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(username,
                            style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: themeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: themeColor.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: themeColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(db.currentProfile,
                                  style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600,
                                    color: themeColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildStat('$moviesWatched', 'Watched', Icons.movie_rounded, themeColor),
                                _buildStatDivider(),
                                _buildStat('${hoursWatched}h', 'Hours', Icons.access_time_rounded, themeColor),
                                _buildStatDivider(),
                                _buildStat('$watchlistCount', 'Watchlist', Icons.bookmark_rounded, themeColor),
                              ],
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
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabBarDelegate(
              child: Container(
                color: AppTheme.background,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: themeColor,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: themeColor,
                  unselectedLabelColor: Colors.white38,
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  tabs: [
                    Tab(text: 'Watchlist ($watchlistCount)'),
                    Tab(text: 'History ($moviesWatched)'),
                    Tab(text: 'Downloads ($downloadCount)'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildWatchlistTab(db),
            _buildHistoryTab(db),
            _buildDownloadsTab(db),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54)),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 40, color: Colors.white12);
  }

  Widget _buildPoster({
    required String? posterPath,
    required String title,
    required String mediaType,
    double width = 80,
    double height = 110,
    int? memCacheWidth,
  }) {
    final posterUrl = _posterUrl(posterPath);

    if (posterUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: posterUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (_, __) => _posterPlaceholder(title, mediaType, width, height),
        errorWidget: (_, __, ___) => _posterPlaceholder(title, mediaType, width, height),
        memCacheWidth: memCacheWidth ?? width.toInt(),
      );
    }

    return _posterPlaceholder(title, mediaType, width, height);
  }

  Widget _posterPlaceholder(String title, String mediaType, double width, double height) {
    final firstLetter = title.isNotEmpty ? title[0].toUpperCase() : '?';

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.background,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            mediaType == 'tv' ? Icons.tv_rounded : Icons.movie_creation_rounded,
            color: Colors.white.withValues(alpha: 0.2),
            size: width * 0.35,
          ),
          const SizedBox(height: 4),
          Text(
            firstLetter,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: width * 0.35,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWatchlistTab(DatabaseService db) {
    if (db.watchlist.isEmpty) {
      return _buildEmptyState(
        icon: Icons.bookmark_border_rounded,
        title: 'No Watchlist Yet',
        subtitle: 'Add movies & shows to your watchlist\nand they will appear here.',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.65,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: db.watchlist.length,
      itemBuilder: (ctx, i) {
        final item = db.watchlist[i];
        final poster = _posterUrl(item['poster_path']);
        final title = item['title'] ?? item['name'] ?? 'Unknown';
        final rating = (item['rating'] as num?)?.toDouble() ??
            (item['vote_average'] as num?)?.toDouble();

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetailsScreen(
                  id: item['id'],
                  mediaType: item['media_type'] ?? 'movie',
                  posterUrl: poster.isNotEmpty ? poster : null,
                ),
              ),
            );
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            _showItemOptions(context, item, db);
          },
          child: Hero(
            tag: 'profile_watchlist_${item['id']}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  poster.isNotEmpty
                      ? CachedNetworkImage(
                    imageUrl: poster,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: AppTheme.surface,
                      child: const Center(
                        child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: AppTheme.surface,
                      child: const Icon(Icons.movie, color: Colors.white24),
                    ),
                    memCacheWidth: 150,
                  )
                      : Container(
                    color: AppTheme.surface,
                    child: const Icon(Icons.movie, color: Colors.white24),
                  ),
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black87, Colors.transparent],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(title,
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600, height: 1.3),
                          ),
                          if (rating != null && rating > 0) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, color: AppTheme.secondaryAccent, size: 10),
                                const SizedBox(width: 2),
                                Text(rating.toStringAsFixed(1),
                                    style: const TextStyle(color: AppTheme.secondaryAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab(DatabaseService db) {
    if (db.watchHistory.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history_rounded,
        title: 'No Watch History',
        subtitle: 'Movies and shows you watch\nwill appear here.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: db.watchHistory.length,
      itemBuilder: (ctx, i) {
        final item = db.watchHistory[i];
        final posterPath = item['poster_path'] as String?;
        final title = item['title'] ?? item['name'] ?? 'Unknown';
        final mediaType = item['media_type'] as String? ?? 'movie';
        final progress = item['progress_seconds'] as int? ?? 0;
        final duration = item['duration_seconds'] as int? ?? 0;
        final progressPercent = duration > 0 ? (progress / duration).clamp(0.0, 1.0) : 0.0;
        final lastWatched = item['last_watched'] as String?;
        final season = item['season'];
        final episode = item['episode'];

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetailsScreen(
                  id: item['id'],
                  mediaType: mediaType,
                  posterUrl: _posterUrl(posterPath),
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                  child: _buildPoster(
                    posterPath: posterPath,
                    title: title,
                    mediaType: mediaType,
                    width: 80, height: 110, memCacheWidth: 160,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, height: 1.3)),
                        if (season != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'S${season.toString().padLeft(2, '0')}${episode != null ? 'E${episode.toString().padLeft(2, '0')}' : ''}',
                              style: const TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        const SizedBox(height: 8),
                        if (progressPercent > 0) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(value: progressPercent, backgroundColor: Colors.white12, color: AppTheme.accent, minHeight: 3),
                          ),
                          const SizedBox(height: 4),
                          Text('${(progressPercent * 100).round()}% watched', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        ] else
                          const Text('Start watching', style: TextStyle(color: Colors.white38, fontSize: 11)),
                        if (lastWatched != null) ...[
                          const SizedBox(height: 2),
                          Text(_formatDate(lastWatched), style: const TextStyle(color: Colors.white24, fontSize: 10)),
                        ],
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.play_circle_outline_rounded, color: Colors.white38, size: 28),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailsScreen(id: item['id'], mediaType: mediaType, posterUrl: _posterUrl(posterPath)),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDownloadsTab(DatabaseService db) {
    if (db.downloads.isEmpty) {
      return _buildEmptyState(
        icon: Icons.download_done_rounded,
        title: 'No Downloads',
        subtitle: 'Download movies & shows to\nwatch offline anytime.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: db.downloads.length,
      itemBuilder: (ctx, i) {
        final item = db.downloads[i];
        final title = item['title'] ?? item['name'] ?? 'Unknown';
        final posterPath = item['poster_path'] as String?;
        final mediaType = item['media_type'] as String? ?? 'movie';
        final quality = item['download_quality'] as String? ?? '1080p';
        final size = item['file_size_bytes'] as int?;
        final sizeStr = size != null ? _formatBytes(size) : 'Unknown size';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildPoster(posterPath: posterPath, title: title, mediaType: mediaType, width: 55, height: 80, memCacheWidth: 110),
            ),
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    _MiniBadge(text: quality, color: AppTheme.accent),
                    const SizedBox(width: 6),
                    Text(sizeStr, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.play_circle_filled_rounded, color: AppTheme.accent, size: 32),
              onPressed: () {},
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white24, size: 36),
            ),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.5)),
          ],
        ),
      ),
    );
  }

  void _showItemOptions(BuildContext context, Map<String, dynamic> item, DatabaseService db) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: const Icon(Icons.play_arrow_rounded, color: Colors.white),
              title: const Text('Play', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => DetailsScreen(id: item['id'], mediaType: item['media_type'] ?? 'movie')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Remove from watchlist', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                db.removeFromWatchlist(item['id']);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Removed from watchlist'), duration: Duration(seconds: 2)),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class _MiniBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _MiniBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _StickyTabBarDelegate({required this.child});

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(covariant _StickyTabBarDelegate oldDelegate) => false;
}