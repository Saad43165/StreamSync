import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shimmer_loading.dart';
import 'details_screen.dart';

enum _SortMode { none, ratingDesc, ratingAsc, alphabetical, alphabeticalReverse }

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
  final FocusNode _searchFocusNode = FocusNode();
  _SortMode _sortMode = _SortMode.none;
  bool _isMounted = true;

  // FIXED: Image URL helper
  String _posterUrl(dynamic posterPath, bool isLive) {
    if (posterPath == null) return '';
    final path = posterPath.toString();
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    if (isLive) return '${TMDBService.imageBaseUrl}$path';
    return '';
  }

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.initialItems);
    _filteredItems = List.from(_items);
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _isMounted = false;
    _searchController.removeListener(_applyFilters);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    List<dynamic> result;

    if (query.isEmpty) {
      result = List<dynamic>.from(_items);
    } else {
      result = _items.where((item) {
        final title = (item['title'] ?? item['name'] ?? '').toString().toLowerCase();
        return title.contains(query);
      }).toList();
    }

    // Apply sorting
    _sortItems(result);

    if (_isMounted) {
      setState(() => _filteredItems = result);
    }
  }

  void _sortItems(List<dynamic> items) {
    switch (_sortMode) {
      case _SortMode.ratingDesc:
        items.sort((a, b) => ((b['vote_average'] as num?) ?? 0)
            .compareTo((a['vote_average'] as num?) ?? 0));
        break;
      case _SortMode.ratingAsc:
        items.sort((a, b) => ((a['vote_average'] as num?) ?? 0)
            .compareTo((b['vote_average'] as num?) ?? 0));
        break;
      case _SortMode.alphabetical:
        items.sort((a, b) => ((a['title'] ?? a['name'] ?? '') as String)
            .compareTo((b['title'] ?? b['name'] ?? '') as String));
        break;
      case _SortMode.alphabeticalReverse:
        items.sort((a, b) => ((b['title'] ?? b['name'] ?? '') as String)
            .compareTo((a['title'] ?? a['name'] ?? '') as String));
        break;
      case _SortMode.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLive = context.watch<TMDBService>().hasApiKey;
    final hasNoSourceItems = _items.isEmpty;
    final itemCount = _filteredItems.length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.categoryTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // FIXED: Show count badge
          if (itemCount > 0)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$itemCount',
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          PopupMenuButton<_SortMode>(
            icon: Icon(
              _sortMode == _SortMode.none ? Icons.sort_rounded : Icons.sort_rounded,
              color: _sortMode == _SortMode.none ? Colors.white70 : AppTheme.accent,
            ),
            color: AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (mode) {
              setState(() => _sortMode = mode);
              _applyFilters();
            },
            itemBuilder: (_) => [
              _sortMenuItem(_SortMode.none, 'Default order', Icons.reorder_rounded),
              _sortMenuItem(_SortMode.ratingDesc, 'Highest rated first', Icons.star_rounded),
              _sortMenuItem(_SortMode.ratingAsc, 'Lowest rated first', Icons.star_outline_rounded),
              _sortMenuItem(_SortMode.alphabetical, 'A–Z', Icons.sort_by_alpha_rounded),
              _sortMenuItem(_SortMode.alphabeticalReverse, 'Z–A', Icons.sort_by_alpha_rounded),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search within ${widget.categoryTitle.toLowerCase()}...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.4)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear_rounded, color: Colors.white.withOpacity(0.4)),
                    onPressed: () {
                      _searchController.clear();
                      _searchFocusNode.unfocus();
                    },
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onSubmitted: (_) => _searchFocusNode.unfocus(),
              ),
            ),
          ),

          // Active filter chips
          if (_searchController.text.isNotEmpty || _sortMode != _SortMode.none)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
              child: Row(
                children: [
                  if (_searchController.text.isNotEmpty)
                    _FilterChip(
                      label: '"${_searchController.text}"',
                      onClear: () => _searchController.clear(),
                    ),
                  if (_sortMode != _SortMode.none) ...[
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: _sortModeLabel,
                      onClear: () {
                        setState(() => _sortMode = _SortMode.none);
                        _applyFilters();
                      },
                    ),
                  ],
                ],
              ),
            ),

          // Content
          Expanded(
            child: hasNoSourceItems
                ? _buildMessage('Nothing in this category yet.', Icons.inbox_rounded)
                : _filteredItems.isEmpty
                ? _buildMessage(
              'No titles match "${_searchController.text}".\nTry a different search term.',
              Icons.search_off_rounded,
            )
                : _buildGrid(isLive),
          ),
        ],
      ),
    );
  }

  String get _sortModeLabel {
    switch (_sortMode) {
      case _SortMode.ratingDesc: return 'Highest rated';
      case _SortMode.ratingAsc: return 'Lowest rated';
      case _SortMode.alphabetical: return 'A–Z';
      case _SortMode.alphabeticalReverse: return 'Z–A';
      case _SortMode.none: return '';
    }
  }

  PopupMenuItem<_SortMode> _sortMenuItem(_SortMode mode, String label, IconData icon) {
    final selected = _sortMode == mode;
    return PopupMenuItem(
      value: mode,
      child: Row(children: [
        Icon(icon, size: 16, color: selected ? AppTheme.accent : Colors.white70),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: selected ? AppTheme.accent : Colors.white)),
        if (selected) ...[
          const Spacer(),
          Icon(Icons.check_rounded, size: 16, color: AppTheme.accent),
        ],
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
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: Colors.white24),
            ),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(bool isLive) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 700 ? 4 : 3;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          physics: const BouncingScrollPhysics(),
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
            final imageUrl = _posterUrl(item['poster_path'], isLive);
            final voteAverage = (item['vote_average'] as num?)?.toDouble() ?? 0.0;
            final rating = voteAverage > 0 ? voteAverage.toStringAsFixed(1) : null;
            final mediaType = item['media_type'] as String?;

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailsScreen(
                      id: item['id'],
                      mediaType: mediaType ?? (item['title'] != null ? 'movie' : 'tv'),
                      posterUrl: imageUrl.isNotEmpty ? imageUrl : null,
                    ),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Hero(
                      tag: 'seeall_poster_${item['id']}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // FIXED: Use CachedNetworkImage
                            imageUrl.isNotEmpty
                                ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const ImageShimmerPlaceholder(borderRadius: 12),
                              errorWidget: (_, __, ___) => Container(
                                color: AppTheme.surface,
                                child: const Icon(Icons.movie, color: Colors.white24, size: 30),
                              ),
                              memCacheWidth: 200,
                            )
                                : Container(
                              color: AppTheme.surface,
                              child: const Icon(Icons.movie, color: Colors.white24, size: 30),
                            ),
                            // Media type badge
                            if (mediaType != null)
                              Positioned(
                                top: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (mediaType == 'tv' ? Colors.blueAccent : Colors.purpleAccent)
                                        .withOpacity(0.85),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    mediaType == 'tv' ? 'TV' : 'MOVIE',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 7,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            // Rating badge
                            if (rating != null)
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
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
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
                      height: 1.3,
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

// FIXED: New filter chip widget
class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onClear;

  const _FilterChip({required this.label, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.accent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onClear,
            child: const Icon(Icons.close_rounded, size: 14, color: AppTheme.accent),
          ),
        ],
      ),
    );
  }
}