import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import '../widgets/ui_kit.dart';
import 'details_screen.dart';

enum _WatchlistSort { recent, title, rating }

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  String? _type; // null = all, 'movie', 'tv'
  _WatchlistSort _sort = _WatchlistSort.recent;

  static double _ratingOf(dynamic item) =>
      (item['rating'] as num?)?.toDouble() ??
      (item['vote_average'] as num?)?.toDouble() ??
      0.0;

  List<dynamic> _visible(List<dynamic> list) {
    final items = list
        .where((x) => _type == null || (x['media_type'] ?? 'movie') == _type)
        .toList();
    switch (_sort) {
      case _WatchlistSort.recent:
        // Stored oldest-first; newest saves belong on top.
        return items.reversed.toList();
      case _WatchlistSort.title:
        items.sort((a, b) => (a['title'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((b['title'] ?? '').toString().toLowerCase()));
        return items;
      case _WatchlistSort.rating:
        items.sort((a, b) => _ratingOf(b).compareTo(_ratingOf(a)));
        return items;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dbService = Provider.of<DatabaseService>(context);
    final list = dbService.watchlist;
    final movieCount = list.where((x) => (x['media_type'] ?? 'movie') == 'movie').length;
    final tvCount = list.length - movieCount;

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
                if (list.isNotEmpty) ...[
                  PopupMenuButton<_WatchlistSort>(
                    tooltip: 'Sort',
                    icon: const Icon(Icons.sort_rounded, color: AppTheme.textSecondary),
                    initialValue: _sort,
                    onSelected: (v) => setState(() => _sort = v),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: _WatchlistSort.recent, child: Text('Recently added')),
                      PopupMenuItem(value: _WatchlistSort.title, child: Text('Title A–Z')),
                      PopupMenuItem(value: _WatchlistSort.rating, child: Text('Highest rated')),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined, color: AppTheme.textSecondary),
                    tooltip: 'Clear all',
                    onPressed: () => _showClearAllDialog(context, dbService),
                  ),
                ],
              ],
            ),
            if (list.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(children: [
                  _FilterChip(
                    label: 'All',
                    count: list.length,
                    selected: _type == null,
                    onTap: () => setState(() => _type = null),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Movies',
                    count: movieCount,
                    selected: _type == 'movie',
                    onTap: () => setState(() => _type = 'movie'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Series',
                    count: tvCount,
                    selected: _type == 'tv',
                    onTap: () => setState(() => _type = 'tv'),
                  ),
                ]),
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
                  : _buildWatchlistContent(context, _visible(list), dbService),
            ),
          ],
        ),
      ),
    );
  }

  void _remove(BuildContext context, DatabaseService db, Map<String, dynamic> item) {
    db.removeFromWatchlist(item['id'], mediaType: item['media_type']);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text('Removed "${item['title'] ?? 'title'}"'),
      action: SnackBarAction(
        label: 'Undo',
        // Stored entries keep the score under 'rating'; addToWatchlist reads 'vote_average'.
        onPressed: () => db.addToWatchlist({...item, 'vote_average': item['rating']}),
      ),
    ));
  }

  Widget _buildWatchlistContent(
      BuildContext context, List<dynamic> list, DatabaseService dbService) {
    if (list.isEmpty) {
      return EmptyState(
        icon: _type == 'tv' ? Icons.tv_rounded : Icons.movie_outlined,
        title: _type == 'tv' ? 'No series saved' : 'No movies saved',
        message: 'Switch to All to see everything on your watchlist.',
      );
    }
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
          onDelete: () => _remove(context, dbService, item),
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
    final date = (item['release_date'] ?? '').toString();
    final year = date.length >= 4 && date != 'N/A' ? date.substring(0, 4) : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: Key('watchlist_${item['media_type']}_${item['id']}'),
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
                            if (year.isNotEmpty)
                              MetaBadge(text: year, color: AppTheme.textSecondary),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppTheme.accent : AppTheme.stroke),
        ),
        child: Text(
          '$label  $count',
          style: TextStyle(
            color: selected ? AppTheme.background : AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
