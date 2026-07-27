import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'native_stream_player_screen.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dbService = Provider.of<DatabaseService>(context);
    final downloads = dbService.downloads;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Downloads',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          if (downloads.isNotEmpty)
            TextButton.icon(
              onPressed: () => _confirmDeleteAll(context, dbService, downloads),
              icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.redAccent),
              label: const Text('Clear all', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
            ),
        ],
      ),
      body: downloads.isEmpty ? _emptyState() : _list(context, dbService, downloads),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.download_for_offline_rounded,
              size: 64,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No downloads yet',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Tap the download icon on any movie or show to save it for offline viewing.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // ── List ─────────────────────────────────────────────────────────────────

  Widget _list(
      BuildContext context,
      DatabaseService dbService,
      List<Map<String, dynamic>> downloads,
      ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: downloads.length,
      itemBuilder: (context, index) {
        final item = downloads[index];
        return _DownloadTile(
          item: item,
          onDelete: () => _deleteItem(context, dbService, item),
          onTap: () => _openOffline(context, item),
        );
      },
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  void _openOffline(BuildContext context, Map<String, dynamic> item) {
    final filePath = item['local_file_path'] as String?;
    if (filePath == null || !File(filePath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File not found on device. It may have been deleted.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NativeStreamPlayerScreen(
          id: item['id'],
          title: item['title'],
          mediaType: item['media_type'] ?? 'movie',
          season: item['season_number'] ?? 1,
          episode: item['episode_number'] ?? 1,
          seasons: item['seasons'] ?? [],
          isOffline: true,
          localFilePath: item['local_file_path'],
          posterPath: item['poster_path'],  // ← ADD THIS
        ),
      ),
    );
  }

  Future<void> _deleteItem(
      BuildContext context,
      DatabaseService dbService,
      Map<String, dynamic> item,
      ) async {
    final title    = item['title'] ?? item['name'] ?? 'this item';
    final filePath = item['local_file_path'] as String?;

    // Delete local file
    if (filePath != null) {
      final f = File(filePath);
      if (await f.exists()) await f.delete();
    }

    // Remove DB record
    await dbService.removeDownload(item['id'] as int);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$title" deleted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmDeleteAll(
      BuildContext context,
      DatabaseService dbService,
      List<Map<String, dynamic>> downloads,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.background,
        title: const Text('Clear all downloads?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'All downloaded files will be permanently deleted from your device.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete all', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    for (final item in downloads) {
      final fp = item['local_file_path'] as String?;
      if (fp != null) {
        final f = File(fp);
        if (await f.exists()) await f.delete();
      }
      await dbService.removeDownload(item['id'] as int);
    }
  }
}

// ── Individual tile ───────────────────────────────────────────────────────

class _DownloadTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _DownloadTile({
    required this.item,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title     = item['title'] ?? item['name'] ?? 'Untitled';
    final mediaType = item['media_type'] ?? 'movie';
    final date      = (item['download_date'] as String? ?? '').split('T').first;
    final isTv      = mediaType == 'tv';
    final sizeBytes = item['file_size_bytes'] as int? ?? 0;
    final filePath  = item['local_file_path'] as String?;
    final fileExists = filePath != null && File(filePath).existsSync();

    return Dismissible(
      key: Key('${item['id']}_${item['download_date']}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppTheme.background,
            title: Text(
              'Delete "$title"?',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            content: const Text(
              'The file will be removed from your device.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) => onDelete(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Colors.redAccent.shade700,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 26),
            SizedBox(height: 4),
            Text('Delete', style: TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: GlassCard(
            padding: const EdgeInsets.all(12),
            borderRadius: 16,
            child: Row(
              children: [
                // ── Poster ─────────────────────────────────────────────
                _Poster(posterPath: item['poster_path'] as String?),

                const SizedBox(width: 14),

                // ── Info ───────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge row
                      Row(
                        children: [
                          _Badge(
                            label: isTv ? 'SERIES' : 'MOVIE',
                            color: isTv ? Colors.purpleAccent : Colors.blueAccent,
                          ),
                          if (!fileExists) ...[
                            const SizedBox(width: 6),
                            _Badge(label: 'FILE MISSING', color: Colors.redAccent),
                          ],
                        ],
                      ),
                      const SizedBox(height: 7),

                      // Title
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Metadata chips
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          if (item['download_quality'] != null)
                            _Chip(
                              label: item['download_quality'].toString(),
                              color: AppTheme.secondaryAccent,
                            ),
                          if (item['download_language'] != null)
                            _Chip(label: item['download_language'].toString()),
                          if (sizeBytes > 0)
                            _Chip(
                              label: _formatSize(sizeBytes),
                              color: Colors.greenAccent,
                            ),
                          if (item['stream_source'] != null)
                            _Chip(label: item['stream_source'].toString()),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Date
                      Text(
                        'Saved $date',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // ── Play button ─────────────────────────────────────────
                Icon(
                  fileExists
                      ? Icons.play_circle_fill_rounded
                      : Icons.error_outline_rounded,
                  color: fileExists ? AppTheme.accent : Colors.redAccent,
                  size: 32,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────

class _Poster extends StatelessWidget {
  final String? posterPath;
  const _Poster({this.posterPath});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 68,
        height: 94,
        color: Colors.white10,
        child: posterPath != null && posterPath!.startsWith('http')
            ? Image.network(
          posterPath!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const _PosterPlaceholder(),
        )
            : const _PosterPlaceholder(),
      ),
    );
  }
}

class _PosterPlaceholder extends StatelessWidget {
  const _PosterPlaceholder();
  @override
  Widget build(BuildContext context) =>
      const Icon(Icons.movie_rounded, color: Colors.white24, size: 32);
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, this.color = Colors.white54});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, this.color = Colors.white70});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w500),
      ),
    );
  }
}