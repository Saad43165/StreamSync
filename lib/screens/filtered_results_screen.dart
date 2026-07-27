import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/config.dart';
import '../theme/app_theme.dart';
import 'details_screen.dart';
import '../widgets/shimmer_loading.dart';

class FilteredResultsScreen extends StatefulWidget {
  final String title;
  final String? genreId;
  final String? year;

  /// 'movie' or 'tv'. Defaults to 'movie' for backward compatibility with
  /// existing call sites, but callers can now pass 'tv' to actually filter
  /// series instead of silently always querying movies.
  final String mediaType;

  const FilteredResultsScreen({
    super.key,
    required this.title,
    this.genreId,
    this.year,
    this.mediaType = 'movie',
  });

  @override
  State<FilteredResultsScreen> createState() => _FilteredResultsScreenState();
}

class _FilteredResultsScreenState extends State<FilteredResultsScreen> {
  final List<dynamic> _results = [];
  bool _isLoading = true;
  bool _hasErrored = false;
  int _page = 1;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchResults();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 300 &&
          !_isLoading &&
          _hasMore) {
        _page++;
        _fetchResults(loadMore: true);
      }
    });
  }

  Future<void> _fetchResults({bool loadMore = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      if (!loadMore) _hasErrored = false;
    });

    try {
      final endpoint = widget.mediaType == 'tv' ? 'tv' : 'movie';
      String url =
          'https://api.themoviedb.org/3/discover/$endpoint?api_key=${AppConfig.tmdbApiKey}&language=en-US&sort_by=popularity.desc&page=$_page';

      if (widget.genreId != null) {
        url += '&with_genres=${widget.genreId}';
      }
      if (widget.year != null) {
        final dateField = widget.mediaType == 'tv' ? 'first_air_date' : 'primary_release_date';
        if (widget.year!.endsWith('s')) {
          final startYear = int.parse(widget.year!.replaceAll('s', ''));
          url += '&$dateField.gte=$startYear-01-01&$dateField.lte=${startYear + 9}-12-31';
        } else if (widget.mediaType == 'tv') {
          url += '&first_air_date_year=${widget.year}';
        } else {
          url += '&primary_release_year=${widget.year}';
        }
      }

      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final newResults = (data['results'] as List<dynamic>? ?? []).map((item) {
          item['media_type'] = widget.mediaType;
          return item;
        }).toList();
        setState(() {
          _results.addAll(newResults);
          _hasMore = newResults.isNotEmpty;
          _hasErrored = false;
        });
      } else {
        setState(() => _hasErrored = _results.isEmpty);
      }
    } catch (e) {
      debugPrint('Error fetching filtered results: $e');
      if (mounted) setState(() => _hasErrored = _results.isEmpty);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _onRefresh() async {
    _page = 1;
    _hasMore = true;
    _results.clear();
    await _fetchResults();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_results.isEmpty && _isLoading) {
      return ShimmerLoadingPresets.searchGridSkeleton();
    }
    if (_results.isEmpty && _hasErrored) {
      return _buildErrorState();
    }
    if (_results.isEmpty && !_isLoading) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: AppTheme.accent,
      backgroundColor: AppTheme.surface,
      onRefresh: _onRefresh,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.65,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
        ),
        itemCount: _results.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _results.length) {
            return Center(
              child: _isLoading
                  ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2),
              )
                  : const SizedBox.shrink(),
            );
          }

          final item = _results[index];
          final title = item['title'] ?? item['name'] ?? 'Unknown';
          final poster = item['poster_path'] != null
              ? 'https://image.tmdb.org/t/p/w500${item['poster_path']}'
              : null;

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetailsScreen(
                    id: item['id'],
                    mediaType: widget.mediaType,
                    posterUrl: poster,
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (poster != null)
                    Image.network(
                      poster,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const ImageShimmerPlaceholder(borderRadius: 12);
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: AppTheme.surface,
                        child: const Icon(Icons.movie, color: Colors.white24, size: 24),
                      ),
                    )
                  else
                    Container(
                      color: AppTheme.surface,
                      child: const Icon(Icons.movie, color: Colors.white24, size: 24),
                    ),
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                      ),
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              "Couldn't load this list. Check your connection.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.black),
              label: const Text('Retry', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Nothing matches this filter yet.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      ),
    );
  }
}