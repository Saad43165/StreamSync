import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import 'settings_screen.dart';
import 'watchlist_screen.dart';
import 'downloads_screen.dart';
import 'watch_history_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final moviesWatched = db.watchHistory.length;
    final hoursWatched = db.totalHoursWatched;
    final showsCompleted = db.watchlist.where((w) => w['completed'] == true).length;
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
        headerSliverBuilder: (context, innerBoxScrolled) => [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppTheme.background,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_rounded, color: Colors.white70),
                onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  // Gradient background
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
                  // Frosted glass center
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        // Avatar with glow ring
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
                                    color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(username,
                          style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold,
                            color: Colors.white)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: themeColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(db.currentProfile,
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: themeColor)),
                        ),
                        const SizedBox(height: 20),

                        // Stats row
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStat('$moviesWatched', 'Watched', Icons.movie_rounded, themeColor),
                              _buildStatDivider(),
                              _buildStat('${hoursWatched}h', 'Hours', Icons.access_time_rounded, themeColor),
                              _buildStatDivider(),
                              _buildStat('${db.watchlist.length}', 'Watchlist', Icons.bookmark_rounded, themeColor),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tab bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: themeColor,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: themeColor,
                unselectedLabelColor: Colors.white38,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'Watchlist'),
                  Tab(text: 'History'),
                  Tab(text: 'Downloads'),
                ],
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
          style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label,
          style: const TextStyle(fontSize: 11, color: Colors.white54)),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 40, color: Colors.white12);
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
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.65,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: db.watchlist.length,
      itemBuilder: (ctx, i) {
        final item = db.watchlist[i];
        final poster = item['poster_path'] as String?;
        final title = item['title'] ?? item['name'] ?? 'Unknown';
        return GestureDetector(
          onLongPress: () => HapticFeedback.mediumImpact(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                poster != null
                    ? Image.network(poster, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                          Container(color: AppTheme.surface,
                            child: const Icon(Icons.movie, color: Colors.white24)))
                    : Container(color: AppTheme.surface,
                        child: const Icon(Icons.movie, color: Colors.white24)),
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
                    child: Text(title,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
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
      itemCount: db.watchHistory.length,
      itemBuilder: (ctx, i) {
        final item = db.watchHistory[i];
        final poster = item['poster_path'] as String?;
        final title = item['title'] ?? item['name'] ?? 'Unknown';
        final progress = (item['progress'] as num?)?.toDouble() ?? 0.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                child: poster != null
                    ? Image.network(poster, width: 70, height: 100, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                          Container(width: 70, height: 100, color: AppTheme.background,
                            child: const Icon(Icons.movie, color: Colors.white24)))
                    : Container(width: 70, height: 100, color: AppTheme.background,
                        child: const Icon(Icons.movie, color: Colors.white24)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                        style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 6),
                      if (progress > 0) ...[
                        LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          backgroundColor: Colors.white12,
                          color: AppTheme.accent,
                          minHeight: 3,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        const SizedBox(height: 4),
                        Text('${(progress * 100).round()}% watched',
                          style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ] else
                        const Text('Resume watching',
                          style: TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
              ),
              const Icon(Icons.play_circle_outline, color: Colors.white38, size: 28),
              const SizedBox(width: 12),
            ],
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
      itemCount: db.downloads.length,
      itemBuilder: (ctx, i) {
        final item = db.downloads[i];
        final title = item['title'] ?? item['name'] ?? 'Unknown';
        final poster = item['poster_path'] as String?;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: poster != null
                  ? Image.network(poster, width: 50, height: 70, fit: BoxFit.cover)
                  : Container(width: 50, height: 70, color: AppTheme.background,
                      child: const Icon(Icons.movie, color: Colors.white24)),
            ),
            title: Text(title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: const Text('Downloaded', style: TextStyle(color: AppTheme.accent, fontSize: 12)),
            trailing: const Icon(Icons.play_circle_filled, color: AppTheme.accent, size: 32),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white24, size: 64),
          const SizedBox(height: 16),
          Text(title,
            style: const TextStyle(color: Colors.white54, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _StickyTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.background,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _StickyTabBarDelegate oldDelegate) => false;
}
