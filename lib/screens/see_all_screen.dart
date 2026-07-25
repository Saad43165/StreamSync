import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shimmer_loading.dart';
import 'details_screen.dart';

class SeeAllScreen extends StatefulWidget {
  final String categoryTitle;
  final List<dynamic> initialItems;

  const SeeAllScreen({
    super.key,
    required this.categoryTitle,
    required this.initialItems,
  });

  @override
  State<SeeAllScreen> createState() => _SeeAllScreenState();
}

class _SeeAllScreenState extends State<SeeAllScreen> {
  late List<dynamic> _items;
  late List<dynamic> _filteredItems;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _items = widget.initialItems;
    _filteredItems = _items;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredItems = _items;
      } else {
        _filteredItems = _items.where((item) {
          final title = (item['title'] ?? item['name'] ?? '').toString().toLowerCase();
          return title.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLive = Provider.of<TMDBService>(context, listen: false).hasApiKey;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.categoryTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Dynamic category-focused search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search within ${widget.categoryTitle.toLowerCase()}...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.4)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, color: Colors.white.withValues(alpha: 0.4)),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),

          // Search results Grid
          Expanded(
            child: _filteredItems.isEmpty
                ? Center(
                    child: Text(
                      'No matching titles found.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.62,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      final name = item['title'] ?? item['name'] ?? 'Untitled';
                      final posterPath = item['poster_path'];
                      final imageUrl = isLive && posterPath != null
                          ? (posterPath.toString().startsWith('http') ? posterPath : '${TMDBService.imageBaseUrl}$posterPath')
                          : (posterPath ?? 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=300');

                      final voteAverage = (item['vote_average'] as num?)?.toDouble() ?? 0.0;
                      final rating = voteAverage.toStringAsFixed(1);

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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
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
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: AppTheme.surface,
                                        child: const Icon(Icons.movie, color: Colors.white24, size: 30),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 6,
                                      right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black87,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.star, color: AppTheme.secondaryAccent, size: 8),
                                            const SizedBox(width: 2),
                                            Text(
                                              rating,
                                              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textPrimary,
                              ),
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
}
