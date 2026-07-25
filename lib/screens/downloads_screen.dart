import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'stream_player_screen.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dbService = Provider.of<DatabaseService>(context);
    final downloads = dbService.downloads;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Offline Downloads', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: downloads.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.download_for_offline_rounded, size: 64, color: AppTheme.accent),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No downloaded content found.',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap the download button on any movie/show details page.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: downloads.length,
              itemBuilder: (context, index) {
                final item = downloads[index];
                final title = item['title'] ?? 'Untitled';
                final mediaType = item['media_type'] ?? 'movie';
                final date = item['download_date'] ?? '';
                final isTv = mediaType == 'tv';

                return Dismissible(
                  key: Key(item['id'].toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.shade700,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 28),
                  ),
                  onDismissed: (_) {
                    dbService.removeDownload(item['id'] as int);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Removed "$title" from downloads.')),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StreamPlayerScreen(
                              id: item['id'] as int,
                              title: title,
                              mediaType: mediaType,
                              seasons: item['seasons'] as List<dynamic>? ?? const [],
                              isOffline: true,
                              downloadQuality: item['download_quality'] as String?,
                              downloadLanguage: item['download_language'] as String?,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: GlassCard(
                        padding: const EdgeInsets.all(12),
                        borderRadius: 16,
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 70,
                                height: 95,
                                color: Colors.white10,
                                child: item['poster_path'] != null && (item['poster_path'] as String).startsWith('http')
                                    ? Image.network(
                                        item['poster_path'] as String,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.movie_rounded, color: Colors.white24),
                                      )
                                    : const Icon(Icons.movie_rounded, color: Colors.white24),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isTv ? Colors.purpleAccent.withOpacity(0.2) : Colors.blueAccent.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isTv ? 'SERIES' : 'MOVIE',
                                      style: TextStyle(
                                        color: isTv ? Colors.purpleAccent : Colors.blueAccent,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                   Row(
                                    children: [
                                      if (item['download_quality'] != null) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                                          child: Text(
                                            item['download_quality'].toString(),
                                            style: const TextStyle(color: AppTheme.secondaryAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      if (item['download_language'] != null) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                                          child: Text(
                                            item['download_language'].toString(),
                                            style: const TextStyle(color: Colors.white70, fontSize: 9),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      if (item['file_size_bytes'] != null) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                                          child: Text(
                                            '${((item['file_size_bytes'] as int) / (1024 * 1024)).toStringAsFixed(1)} MB',
                                            style: const TextStyle(color: Colors.greenAccent, fontSize: 9),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Downloaded: ${date.split("T").first}',
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.play_circle_outline_rounded, color: AppTheme.accent, size: 28),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
