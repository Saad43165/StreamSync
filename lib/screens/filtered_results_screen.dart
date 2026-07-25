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
  
  const FilteredResultsScreen({
    super.key, 
    required this.title,
    this.genreId,
    this.year,
  });

  @override
  State<FilteredResultsScreen> createState() => _FilteredResultsScreenState();
}

class _FilteredResultsScreenState extends State<FilteredResultsScreen> {
  final List<dynamic> _results = [];
  bool _isLoading = true;
  int _page = 1;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchResults();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoading && _hasMore) {
        _page++;
        _fetchResults();
      }
    });
  }

  Future<void> _fetchResults() async {
    setState(() => _isLoading = true);
    
    try {
      String url = 'https://api.themoviedb.org/3/discover/movie?api_key=${AppConfig.tmdbApiKey}&language=en-US&sort_by=popularity.desc&page=$_page';
      
      if (widget.genreId != null) {
        url += '&with_genres=${widget.genreId}';
      }
      if (widget.year != null) {
        if (widget.year!.endsWith('s')) {
          // Decade logic e.g., 2010s
          int startYear = int.parse(widget.year!.replaceAll('s', ''));
          url += '&primary_release_date.gte=$startYear-01-01&primary_release_date.lte=${startYear + 9}-12-31';
        } else {
          url += '&primary_release_year=${widget.year}';
        }
      }

      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final newResults = data['results'] as List<dynamic>;
        setState(() {
          _results.addAll(newResults);
          _hasMore = newResults.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
    
    setState(() => _isLoading = false);
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
      body: _results.isEmpty && _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.65,
                crossAxisSpacing: 12,
                mainAxisSpacing: 16,
              ),
              itemCount: _results.length + (_hasMore ? 3 : 0),
              itemBuilder: (context, index) {
                if (index >= _results.length) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(color: AppTheme.surface),
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
                          mediaType: 'movie',
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
                            errorBuilder: (_,__,___) => Container(color: AppTheme.surface),
                          )
                        else
                          Container(color: AppTheme.surface),
                        
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
}
