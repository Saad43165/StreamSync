import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import '../widgets/ui_kit.dart';
import 'details_screen.dart';

class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dbService = Provider.of<DatabaseService>(context);
    final list = dbService.watchlist;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Watchlist',
              subtitle: list.isEmpty
                  ? 'Save titles to watch later'
                  : '${list.length} ${list.length == 1 ? 'title' : 'titles'} saved',
              actions: [
                if (list.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined, color: AppTheme.textSecondary),
                    tooltip: 'Clear all',
                    onPressed: () => _showClearAllDialog(context, dbService),
                  ),
              ],
            ),
            Expanded(
              child: list.isEmpty
                  ? EmptyState(
                      icon: Icons.bookmark_outline_rounded,
                      title: 'Your watchlist is empty',
                      message: 'Tap the bookmark on any movie or show and it will be waiting for you here.',
                      actionLabel: 'Browse titles',
                      onAction: () => MainNavigationShell.selectTab(context, 0),
                    )
                  : _buildWatchlistContent(context, list, dbService),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatchlistContent(
      BuildContext context, List<dynamic> list, DatabaseService dbService) {
    return ListView.builder(
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
                  heroTag: 'watchlist_poster_${item['id']}',
                ),
              ),
            );
          },
          onDelete: () => dbService.removeFromWatchlist(item['id'], mediaType: item['media_type']),
        );
      },
    );
  }

  void _showClearAllDialog(BuildContext context, DatabaseService dbService) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear watchlist?'),
        content: const Text('This removes every saved title. It can\'t be undone.'),
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
                style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold)),
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
            color: AppTheme.danger.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: const Icon(Icons.delete_outline, color: AppTheme.danger),
        ),
        onDismissed: (_) => onDelete(),
        child: Material(
          color: AppTheme.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            side: const BorderSide(color: AppTheme.divider),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 64,
                      height: 96,
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
                            child: Icon(Icons.movie, color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          memCacheWidth: 128,
                        ),
                      )
                          : Container(
                        color: Colors.white12,
                        child: Icon(Icons.movie, color: Colors.white.withValues(alpha: 0.3)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontSize: 15, height: 1.3)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8, runSpacing: 4,
                          children: [
                            MetaBadge(
                                text: mediaType == 'tv' ? 'SERIES' : 'FILM',
                                color: mediaType == 'tv' ? AppTheme.accent : AppTheme.secondaryAccent),
                            if (ratingNum > 0)
                              MetaBadge(text: rating, icon: Icons.star_rounded, color: AppTheme.gold),
                            if (mediaType == 'tv' && season != null)
                              MetaBadge(
                                  text: 'S$season${episode != null ? 'E$episode' : ''}',
                                  color: AppTheme.textSecondary),
                          ],
                        ),
                        if (overview.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(overview, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4)),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted, size: 18),
                    tooltip: 'Remove',
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
