import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ad_banner.dart';
import '../widgets/shimmer_loading.dart';
import 'details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _freeOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tmdbService = Provider.of<TMDBService>(context);
    final isLive = tmdbService.hasApiKey;

    // Filter out non-media results (e.g. actor/director profiles) and apply search filters
    List<dynamic> filteredResults = tmdbService.searchResults.where((item) => 
      item['media_type'] == 'movie' || item['media_type'] == 'tv'
    ).toList();
    
    if (_freeOnly) {
      if (isLive) {
        // dynamic filters can be applied here
      } else {
        filteredResults = filteredResults.where((item) => 
          item['id'] == 1 || item['id'] == 2 || item['id'] == 4
        ).toList();
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search & Filters', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            // Search Input Row
            TextField(
              controller: _searchController,
              onChanged: (query) {
                tmdbService.search(query);
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search movies, series, dramas...',
                hintStyle: const TextStyle(color: AppTheme.textSecondary),
                prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          tmdbService.search('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Free Switch Row (Solving the "No Subscription" problem)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.money_off, color: Colors.greenAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Show Free Options Only',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: _freeOnly,
                  activeTrackColor: Colors.greenAccent.withOpacity(0.5),
                  activeColor: Colors.greenAccent,
                  onChanged: (value) {
                    setState(() {
                      _freeOnly = value;
                    });
                  },
                ),
              ],
            ),
            const Divider(color: Colors.white12),

            // Search Results Grid
            Expanded(
              child: tmdbService.isLoading
                  ? ShimmerLoadingPresets.searchGridSkeleton()
                  : filteredResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _searchController.text.isEmpty ? Icons.movie : Icons.search_off,
                                size: 64,
                                color: AppTheme.textSecondary.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isEmpty
                                    ? 'Search above to find movies & shows'
                                    : 'No results found matching search criteria.',
                                style: const TextStyle(color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.only(top: 10, bottom: 20),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.7,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: filteredResults.length,
                          itemBuilder: (context, index) {
                             final item = filteredResults[index];
                             final name = item['title'] ?? item['name'] ?? 'Untitled';
                             final voteAverage = (item['vote_average'] as num?)?.toDouble() ?? 0.0;
                             final rating = voteAverage.toStringAsFixed(1);

                            final posterPath = item['poster_path'];
                            final imageUrl = isLive && posterPath != null
                                ? '${TMDBService.imageBaseUrl}$posterPath'
                                : (posterPath ?? 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=300');

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DetailsScreen(
                                      id: item['id'],
                                      mediaType: item['media_type'] ?? (item['title'] != null ? 'movie' : 'tv'),
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: AppTheme.surface,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Image
                                      Expanded(
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Image.network(
                                              imageUrl,
                                              fit: BoxFit.cover,
                                              loadingBuilder: (context, child, loadingProgress) {
                                                if (loadingProgress == null) return child;
                                                return const ImageShimmerPlaceholder(borderRadius: 12);
                                              },
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  color: AppTheme.surface,
                                                  child: const Icon(Icons.movie, color: Colors.white24, size: 48),
                                                );
                                              },
                                            ),
                                            Positioned(
                                              bottom: 8,
                                              right: 8,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.black87,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.star, color: AppTheme.secondaryAccent, size: 10),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      rating,
                                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Title Text
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
            const AdBanner(),
            const SizedBox(height: 100), // clearance for floating bottom dock
          ],
        ),
      ),
    );
  }
}
