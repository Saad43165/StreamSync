import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shimmer_loading.dart';
import 'details_screen.dart';

enum _SortMode { none, ratingDesc, alphabetical }

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
  _SortMode _sortMode = _SortMode.none;

  @override
  void initState() {
    super.initState();
    _items = widget.initialItems;
    _filteredItems = _items;
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilters);
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    List<dynamic> result = query.isEmpty
        ? List<dynamic>.from(_items)
        : _items.where((item) {
      final title = (item['title'] ?? item['name'] ?? '').toString().toLowerCase();
      return title.contains(query);
    }).toList();

    switch (_sortMode) {
      case _SortMode.ratingDesc:
        result.sort((a, b) => ((b['vote_average'] as num?) ?? 0)
            .compareTo((a['vote_average'] as num?) ?? 0));
        break;
      case _SortMode.alphabetical:
        result.sort((a, b) => ((a['title'] ?? a['name'] ?? '') as String)
            .compareTo((b['title'] ?? b['name'] ?? '') as String));
        break;
      case _SortMode.none:
        break;
    }

    setState(() => _filteredItems = result);
  }

  @override
  Widget build(BuildContext context) {
    // watch (not listen:false) so the grid reacts if the API key / live
    // status ever changes while this screen is open.
    final isLive = context.watch<TMDBService>().hasApiKey;
    final hasNoSourceItems = _items.isEmpty;

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
        actions: [
          PopupMenuButton<_SortMode>(
            icon: const Icon(Icons.sort_rounded, color: Colors.white70),
            color: AppTheme.surface,
            onSelected: (mode) {
              setState(() => _sortMode = mode);
              _applyFilters();
            },
            itemBuilder: (_) => [
              _sortMenuItem(_SortMode.none, 'Default order', Icons.reorder_rounded),
              _sortMenuItem(_SortMode.ratingDesc, 'Highest rated', Icons.star_rounded),
              _sortMenuItem(_SortMode.alphabetical, 'A–Z', Icons.sort_by_alpha_rounded),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
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
          Expanded(
            child: hasNoSourceItems
                ? _buildMessage('Nothing in this category yet.', Icons.inbox_rounded)
                : _filteredItems.isEmpty
                ? _buildMessage('No titles match "${_searchController.text}".', Icons.search_off_rounded)
                : _buildGrid(isLive),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<_SortMode> _sortMenuItem(_SortMode mode, String label, IconData icon) {
    final selected = _sortMode == mode;
    return PopupMenuItem(
      value: mode,
      child: Row(children: [
        Icon(icon, size: 16, color: selected ? AppTheme.accent : Colors.white70),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: selected ? AppTheme.accent : Colors.white)),
      ]),
    );
  }

  Widget _buildMessage(String text, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 44, color: Colors.white24),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(bool isLive) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Wider screens (tablets, foldables) get an extra column instead of
        // stretching 3 columns uncomfortably thin.
        final crossAxisCount = constraints.maxWidth >= 700 ? 4 : 3;
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
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
                : (posterPath is String && posterPath.startsWith('http') ? posterPath : null);

            final voteAverage = (item['vote_average'] as num?)?.toDouble() ?? 0.0;
            final rating = voteAverage > 0 ? voteAverage.toStringAsFixed(1) : '—';

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
                          imageUrl != null
                              ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const ImageShimmerPlaceholder(borderRadius: 12);
                            },
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: AppTheme.surface,
                              child: const Icon(Icons.movie, color: Colors.white24, size: 30),
                            ),
                          )
                              : Container(
                            color: AppTheme.surface,
                            child: const Icon(Icons.movie, color: Colors.white24, size: 30),
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
        );
      },
    );
  }
}