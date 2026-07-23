import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../screens/login_screen.dart';

class WatchHistoryScreen extends StatelessWidget {
  const WatchHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dbService = Provider.of<DatabaseService>(context);
    final history = dbService.watchHistory;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Watch History',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          if (history.isNotEmpty)
            TextButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.surface,
                    title: const Text('Clear History', style: TextStyle(color: Colors.white)),
                    content: const Text(
                      'Are you sure you want to delete all watch history?',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  dbService.clearDatabase();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Watch history cleared.')),
                  );
                }
              },
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 16),
              label: const Text('Clear All', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
            ),
        ],
      ),
      body: history.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded, color: Colors.white12, size: 80),
                  const SizedBox(height: 16),
                  const Text(
                    'No Watch History Yet',
                    style: TextStyle(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Movies and shows you watch will appear here.',
                    style: TextStyle(color: Colors.white24, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (!dbService.isLoggedIn) ...[
                    const Text(
                      'Sign in to sync history across devices',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen(showSkipButton: false)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Sign In', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            )
          : Column(
              children: [
                // Synced indicator
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        dbService.isLoggedIn ? Icons.cloud_done_rounded : Icons.phone_android_rounded,
                        color: dbService.isLoggedIn ? Colors.greenAccent : AppTheme.textSecondary,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          dbService.isLoggedIn
                              ? 'Synced to account: @${dbService.username}  •  ${history.length} titles watched'
                              : 'Saved locally for profile: ${dbService.currentProfile}  •  ${history.length} titles',
                          style: TextStyle(
                            color: dbService.isLoggedIn ? Colors.greenAccent.withAlpha(200) : AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final item = history[history.length - 1 - index]; // Newest first
                      final title = item['title'] ?? item['name'] ?? 'Unknown Title';
                      final mediaType = item['media_type'] ?? 'movie';
                      final posterPath = item['poster_path'];
                      final rating = ((item['vote_average'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            // Poster thumbnail
                            ClipRRect(
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                              child: posterPath != null
                                  ? Image.network(
                                      posterPath.toString().startsWith('http')
                                          ? posterPath
                                          : 'https://image.tmdb.org/t/p/w200$posterPath',
                                      width: 70,
                                      height: 95,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _posterPlaceholder(),
                                    )
                                  : _posterPlaceholder(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: mediaType == 'tv' ? Colors.blueAccent.withAlpha(50) : Colors.purpleAccent.withAlpha(50),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            mediaType == 'tv' ? 'SERIES' : 'MOVIE',
                                            style: TextStyle(
                                              color: mediaType == 'tv' ? Colors.blueAccent : Colors.purpleAccent,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.star_rounded, color: AppTheme.secondaryAccent, size: 12),
                                        const SizedBox(width: 3),
                                        Text(
                                          rating,
                                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: Icon(Icons.chevron_right_rounded, color: Colors.white24),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _posterPlaceholder() {
    return Container(
      width: 70,
      height: 95,
      color: AppTheme.surface,
      child: const Icon(Icons.movie_rounded, color: Colors.white24, size: 28),
    );
  }
}
