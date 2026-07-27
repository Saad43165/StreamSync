import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shimmer_loading.dart';
import 'details_screen.dart';

class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dbService = Provider.of<DatabaseService>(context);
    final list = dbService.watchlist;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Watchlist',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppTheme.background,
        elevation: 0,
        actions: list.isNotEmpty
            ? [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
            tooltip: 'Clear all',
            onPressed: () => _showClearAllDialog(context, dbService),
          ),
        ]
            : null,
      ),
      body: list.isEmpty
          ? _buildEmptyState(context)
          : _buildWatchlistContent(context, list, dbService),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bookmark_outline,
                size: 40,
                color: AppTheme.accent.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your watchlist is empty',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add movies or TV series to track them!\nThey\'ll appear here for quick access.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatchlistContent(
      BuildContext context, List<dynamic> list, DatabaseService dbService) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              Text(
                '${list.length} ${list.length == 1 ? 'title' : 'titles'} saved',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
            physics: const BouncingScrollPhysics(),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final item = list[index];
              return _WatchlistCard(
                item: item,
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
                onDelete: () => dbService.removeFromWatchlist(item['id']),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showClearAllDialog(BuildContext context, DatabaseService dbService) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Watchlist',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Remove all titles from your watchlist?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              dbService.clearWatchlist();
              Navigator.pop(ctx);
            },
            child: const Text('Clear All',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _WatchlistCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _WatchlistCard({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title = item['title'] ?? 'Untitled';
    final mediaType = item['media_type'] ?? 'movie';
    final ratingNum = (item['rating'] as num?)?.toDouble() ??
        (item['vote_average'] as num?)?.toDouble() ?? 0.0;
    final rating = ratingNum > 0 ? ratingNum.toStringAsFixed(1) : '—';
    final posterPath = item['poster_path'];
    final overview = item['overview'] ?? '';
    final season = item['season'];
    final episode = item['episode'];
    final imageUrl = _buildImageUrl(posterPath);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: Key('watchlist_${item['id']}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.redAccent),
        ),
        onDismissed: (_) => onDelete(),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 56,
                      height: 84,
                      child: imageUrl != null
                          ? Hero(
                        tag: 'watchlist_poster_${item['id']}',
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: Colors.white12,
                            child: const Center(
                              child: SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.white12,
                            child: Icon(Icons.movie, color: Colors.white.withOpacity(0.3)),
                          ),
                          memCacheWidth: 112,
                        ),
                      )
                          : Container(
                        color: Colors.white12,
                        child: Icon(Icons.movie, color: Colors.white.withOpacity(0.3)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14, height: 1.3)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8, runSpacing: 4,
                          children: [
                            _Badge(text: mediaType.toUpperCase(), color: mediaType == 'tv' ? Colors.blueAccent : Colors.purpleAccent),
                            if (ratingNum > 0) _Badge(text: '⭐ $rating', color: const Color(0xFFF5C842)),
                            if (mediaType == 'tv' && season != null)
                              _Badge(text: 'S$season${episode != null ? 'E$episode' : ''}', color: Colors.tealAccent),
                          ],
                        ),
                        if (overview.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(overview, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.4)),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _buildImageUrl(dynamic posterPath) {
    if (posterPath == null) return null;
    final path = posterPath.toString();
    if (path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    if (path.startsWith('/')) return 'https://image.tmdb.org/t/p/w200$path';
    return null;
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.3)),
    );
  }
}