import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      appBar: AppBar(
        title: const Text('My Watchlist', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: list.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_outline, size: 64, color: AppTheme.textSecondary.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  const Text(
                    'Your watchlist is empty.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add movies or TV series to track them!',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110), // clearance for floating dock
              itemCount: list.length,
              itemBuilder: (context, index) {
                final item = list[index];
                final title = item['title'] ?? 'Untitled';
                final mediaType = item['media_type'] ?? 'movie';
                final ratingNum = (item['rating'] as num?)?.toDouble() ?? 0.0;
                final rating = ratingNum.toStringAsFixed(1);
                final posterPath = item['poster_path'];
                
                // Load from dynamic TMDB URL or default mock cover art
                final isLive = dbService.watchlist.any((x) => x['id'] == item['id'] && x['poster_path'] != null && x['poster_path'].toString().startsWith('http'));
                final imageUrl = isLive 
                    ? posterPath 
                    : (posterPath ?? 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=300');

                return Card(
                  color: AppTheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 6,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 50,
                        height: 75,
                        color: Colors.white12,
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const ImageShimmerPlaceholder(borderRadius: 8);
                          },
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.movie, color: Colors.white24),
                        ),
                      ),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    subtitle: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            mediaType.toUpperCase(),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.star, color: AppTheme.secondaryAccent, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          rating,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () {
                        dbService.removeFromWatchlist(item['id']);
                      },
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailsScreen(
                            id: item['id'],
                            mediaType: mediaType,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
