import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ad_banner.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/glass_card.dart';
import 'details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  final List<String> _categories = ['All', 'Action', 'Comedy', 'Sci-Fi', 'Horror', 'Upcoming'];
  String _selectedCategory = 'All';

  final List<String> _recentSearches = [
    'Avengers',
    'Superman',
    'Avatar',
    'Batman',
    'Stranger Things',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _addSearchQuery(String query) {
    if (query.trim().isEmpty) return;
    setState(() {
      _recentSearches.remove(query);
      _recentSearches.insert(0, query);
      if (_recentSearches.length > 8) {
        _recentSearches.removeLast();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tmdbService = Provider.of<TMDBService>(context);
    final isLive = tmdbService.hasApiKey;

    List<dynamic> baseList = [];
    if (_searchController.text.isEmpty) {
      if (_selectedCategory == 'All') {
        baseList = tmdbService.trending;
      } else if (_selectedCategory == 'Action') {
        baseList = tmdbService.actionMovies;
      } else if (_selectedCategory == 'Comedy') {
        baseList = tmdbService.comedyMovies;
      } else if (_selectedCategory == 'Sci-Fi') {
        baseList = tmdbService.scifiMovies;
      } else if (_selectedCategory == 'Horror') {
        baseList = tmdbService.horrorMovies;
      } else {
        baseList = tmdbService.upcoming;
      }
    } else {
      baseList = tmdbService.searchResults.where((item) => 
        item['media_type'] == 'movie' || item['media_type'] == 'tv'
      ).toList();
      
      if (_selectedCategory != 'All') {
        int targetGenre = -1;
        if (_selectedCategory == 'Action') targetGenre = 28;
        if (_selectedCategory == 'Comedy') targetGenre = 35;
        if (_selectedCategory == 'Sci-Fi') targetGenre = 878;
        if (_selectedCategory == 'Horror') targetGenre = 27;
        
        if (targetGenre != -1) {
          baseList = baseList.where((item) {
            final genres = item['genre_ids'] as List<dynamic>? ?? [];
            return genres.contains(targetGenre);
          }).toList();
        }
      }
    }
    List<dynamic> filteredResults = baseList;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Search & Explore', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input Row
            TextField(
              controller: _searchController,
              onSubmitted: (query) {
                _addSearchQuery(query);
                tmdbService.search(query);
              },
              onChanged: (query) {
                if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
                _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                  tmdbService.search(query);
                });
                setState(() {});
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search movies, series, dramas...',
                hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: AppTheme.accent),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          tmdbService.search('');
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.white10, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.accent, width: 1),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Horizontal Category Selection Pills Row
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, idx) {
                  final cat = _categories[idx];
                  final isSel = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSel,
                      onSelected: (val) {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      },
                      selectedColor: AppTheme.accent,
                      backgroundColor: AppTheme.surface,
                      labelStyle: TextStyle(
                        color: isSel ? Colors.black : Colors.white70,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Recent Searches (Visible only when search input is empty)
            if (_searchController.text.isEmpty) ...[
              const Text(
                'RECENT SEARCHES',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _recentSearches.map((query) {
                  return GestureDetector(
                    onTap: () {
                      _searchController.text = query;
                      tmdbService.search(query);
                      _addSearchQuery(query);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.history_rounded, size: 12, color: Colors.white38),
                          const SizedBox(width: 6),
                          Text(query, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.white10),
              const SizedBox(height: 10),
            ],

            // Search Results Title
            Text(
              _searchController.text.isEmpty ? 'SUGGESTED FOR YOU' : 'SEARCH RESULTS',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),

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
                                _searchController.text.isEmpty ? Icons.movie_outlined : Icons.search_off_rounded,
                                size: 54,
                                color: Colors.white24,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isEmpty
                                    ? 'Try searching or select a recent item'
                                    : 'No results found matching search criteria.',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.only(top: 4, bottom: 20),
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
                                _addSearchQuery(_searchController.text);
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
                                  borderRadius: BorderRadius.circular(16),
                                  color: AppTheme.surface,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
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
                                                return const ImageShimmerPlaceholder(borderRadius: 16);
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
                                              child: GlassCard(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                borderRadius: 6,
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.star_rounded, color: AppTheme.secondaryAccent, size: 12),
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
                                        padding: const EdgeInsets.all(10.0),
                                        child: Text(
                                          name,
                                          maxLines: 1,
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
