import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../services/tmdb_service.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/shimmer_loading.dart';
import 'stream_player_screen.dart';

class DetailsScreen extends StatefulWidget {
  final int id;
  final String mediaType;

  const DetailsScreen({
    super.key,
    required this.id,
    required this.mediaType,
  });

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  Map<String, dynamic>? _details;
  bool _isLoading = true;

  // TV Selector variables
  int _selectedSeason = 1;
  int _selectedEpisode = 1;
  int _episodeCountForSelectedSeason = 10;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final tmdbService = Provider.of<TMDBService>(context, listen: false);
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final details = await tmdbService.fetchDetails(widget.id, widget.mediaType, dbService.selectedCountry);

    if (details != null && mounted) {
      setState(() {
        _details = details;
        _isLoading = false;

        // Init tv selector details if tv show
        if (widget.mediaType == 'tv') {
          final seasons = details['seasons'] as List<dynamic>? ?? [];
          if (seasons.isNotEmpty) {
            final firstSeason = seasons.firstWhere(
              (s) => (s['season_number'] as int? ?? 0) >= 1,
              orElse: () => seasons.first,
            );
            _selectedSeason = firstSeason['season_number'] ?? 1;
            _episodeCountForSelectedSeason = firstSeason['episode_count'] ?? 10;
          }
        }
      });
    } else if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _launchStreamingService(String providerName, String title) async {
    final encodedTitle = Uri.encodeComponent(title);
    final providerClean = providerName.toLowerCase().trim();
    
    String appUriStr = '';
    String webUriStr = '';

    if (providerClean.contains('netflix')) {
      appUriStr = 'nflx://www.netflix.com/search?q=$encodedTitle';
      webUriStr = 'https://www.netflix.com/search?q=$encodedTitle';
    } else if (providerClean.contains('youtube')) {
      appUriStr = 'vnd.youtube://results?search_query=$encodedTitle+full+movie';
      webUriStr = 'https://www.youtube.com/results?search_query=$encodedTitle+full+movie';
    } else if (providerClean.contains('prime video') || providerClean.contains('amazon')) {
      appUriStr = 'amazonvideo://search?query=$encodedTitle';
      webUriStr = 'https://www.amazon.com/s?k=$encodedTitle+prime+video';
    } else if (providerClean.contains('hulu')) {
      appUriStr = 'hulu://search?query=$encodedTitle';
      webUriStr = 'https://www.hulu.com/search?q=$encodedTitle';
    } else if (providerClean.contains('disney')) {
      appUriStr = 'disneyplus://';
      webUriStr = 'https://www.google.com/search?q=site:disneyplus.com+$encodedTitle';
    } else if (providerClean.contains('apple tv')) {
      appUriStr = 'videos://';
      webUriStr = 'https://tv.apple.com/search?term=$encodedTitle';
    } else if (providerClean.contains('tubi')) {
      webUriStr = 'https://tubitv.com/search/$encodedTitle';
    } else if (providerClean.contains('pluto')) {
      webUriStr = 'https://pluto.tv/search';
    } else if (providerClean.contains('max') || providerClean.contains('hbo')) {
      webUriStr = 'https://www.max.com/search?q=$encodedTitle';
    } else if (providerClean.contains('roku')) {
      webUriStr = 'https://therokuchannel.roku.com/search/$encodedTitle';
    } else if (providerClean.contains('vudu')) {
      webUriStr = 'https://www.vudu.com/content/movies/search?searchString=$encodedTitle';
    } else if (providerClean.contains('google play')) {
      webUriStr = 'https://play.google.com/store/search?q=$encodedTitle&c=movies';
    } else if (providerClean.contains('plex')) {
      webUriStr = 'https://watch.plex.tv/search?q=$encodedTitle';
    } else {
      webUriStr = 'https://www.google.com/search?q=watch+$encodedTitle+on+$providerName';
    }

    if (appUriStr.isNotEmpty) {
      try {
        final appUri = Uri.parse(appUriStr);
        if (await canLaunchUrl(appUri)) {
          await launchUrl(appUri, mode: LaunchMode.externalNonBrowserApplication);
          return;
        }
      } catch (_) {}
    }

    if (webUriStr.isNotEmpty) {
      try {
        final webUri = Uri.parse(webUriStr);
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('Error launching web url: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $providerName.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }

    if (_details == null) {
      return const Scaffold(
        body: Center(child: Text('Failed to load details.')),
      );
    }

    final details = _details!;
    final title = details['title'] ?? 'Untitled';
    final overview = details['overview'] ?? '';
    final voteAverage = (details['vote_average'] as num?)?.toDouble() ?? 0.0;
    final rating = voteAverage.toStringAsFixed(1);
    final releaseDate = details['release_date'] ?? 'N/A';
    final freeOptions = details['free_options'] as List<dynamic>;
    final subOptions = details['subscription_options'] as List<dynamic>;
    final genresList = details['genres'] as List<dynamic>? ?? [];

    final backdropPath = details['backdrop_path'];
    final backdropUrl = backdropPath ?? 'https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=800';
    final trailerId = details['trailer_id'];

    return Scaffold(
      body: Stack(
        children: [
          // 1. Dynamic Blurred Backdrop Canvas
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(backdropUrl),
                  fit: BoxFit.cover,
                ),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  color: AppTheme.background.withOpacity(0.85),
                ),
              ),
            ),
          ),

          // 2. Scrollable details content
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCustomAppBar(context, details),

                  // 3. YouTube Direct iframe Video Player Webview
                  if (trailerId != null)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12)],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: InAppWebView(
                          initialUrlRequest: URLRequest(
                            url: Uri.parse('https://www.youtube-nocookie.com/embed/$trailerId?autoplay=1&mute=1&playsinline=1&rel=0'),
                          ),
                          initialOptions: InAppWebViewGroupOptions(
                            crossPlatform: InAppWebViewOptions(
                              mediaPlaybackRequiresUserGesture: false,
                              transparentBackground: true,
                              javaScriptEnabled: true,
                              userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                            ),
                            android: AndroidInAppWebViewOptions(
                              useHybridComposition: true,
                              domStorageEnabled: true,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    _buildBackdropFallback(backdropUrl),

                  const SizedBox(height: 12),

                  // 4. WATCH STREAM ON DEMAND ROW
                  _buildWatchStreamButton(context, details),

                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.secondaryAccent.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.star, color: AppTheme.secondaryAccent, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    rating,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Released: $releaseDate',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 12),

                        // Dynamic Genre Badges
                        if (genresList.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: genresList.map((genre) => _buildGenreBadge(genre)).toList(),
                          ),

                        const SizedBox(height: 24),

                        // Watch Free Options
                        _buildWatchProvidersSection(
                          context,
                          title: title,
                          sectionTitle: 'Watch Free (No Subscription Required! 🎉)',
                          providers: freeOptions,
                          isFree: true,
                        ),

                        const SizedBox(height: 20),

                        // Subscription Options
                        _buildWatchProvidersSection(
                          context,
                          title: title,
                          sectionTitle: 'Streaming Subscriptions (Netflix, Prime, Max, etc.)',
                          providers: subOptions,
                          isFree: false,
                        ),

                        const SizedBox(height: 24),

                        const Text(
                          'Synopsis',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          overview.isEmpty ? 'No description available.' : overview,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                            height: 1.45,
                          ),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWatchStreamButton(BuildContext context, Map<String, dynamic> details) {
    final title = details['title'] ?? details['name'] ?? 'Untitled';
    final isTv = widget.mediaType == 'tv';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        children: [
          if (isTv) _buildTvSelector(details),
          ElevatedButton.icon(
            onPressed: () {
              // Record playback to Continue Watching history list
              Provider.of<DatabaseService>(context, listen: false).addToHistory(
                details,
                season: widget.mediaType == 'tv' ? _selectedSeason : null,
                episode: widget.mediaType == 'tv' ? _selectedEpisode : null,
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StreamPlayerScreen(
                    id: widget.id,
                    title: title,
                    mediaType: widget.mediaType,
                    season: _selectedSeason,
                    episode: _selectedEpisode,
                    seasons: details['seasons'] as List<dynamic>? ?? [],
                  ),
                ),
              );
            },
            icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.black, size: 24),
            label: Text(
              isTv 
                  ? 'Watch Season $_selectedSeason, Ep $_selectedEpisode Free'
                  : 'Watch Full Movie Free',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              shadowColor: AppTheme.accent.withOpacity(0.3),
              elevation: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTvSelector(Map<String, dynamic> details) {
    final seasons = details['seasons'] as List<dynamic>? ?? [];
    if (seasons.isEmpty) return const SizedBox();

    final validSeasons = seasons.where((s) => (s['season_number'] as int? ?? 0) >= 1).toList();
    if (validSeasons.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        borderRadius: 12,
        child: Row(
          children: [
            // Season Selector
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SEASON',
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedSeason,
                      dropdownColor: AppTheme.surface,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      isDense: true,
                      items: validSeasons.map((s) {
                        final sNum = s['season_number'] as int? ?? 1;
                        return DropdownMenuItem<int>(
                          value: sNum,
                          child: Text('Season $sNum'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          final targetSeason = validSeasons.firstWhere(
                            (s) => s['season_number'] == val,
                            orElse: () => validSeasons.first,
                          );
                          setState(() {
                            _selectedSeason = val;
                            _selectedEpisode = 1;
                            _episodeCountForSelectedSeason = targetSeason['episode_count'] ?? 10;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            Container(width: 1, height: 30, color: Colors.white12, margin: const EdgeInsets.symmetric(horizontal: 12)),

            // Episode Selector
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EPISODE',
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedEpisode,
                      dropdownColor: AppTheme.surface,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      isDense: true,
                      items: List.generate(_episodeCountForSelectedSeason, (index) => index + 1).map((epNum) {
                        return DropdownMenuItem<int>(
                          value: epNum,
                          child: Text('Episode $epNum'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedEpisode = val;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomAppBar(BuildContext context, Map<String, dynamic> details) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Consumer<DatabaseService>(
            builder: (context, dbService, child) {
              final isSaved = dbService.isInWatchlist(details['id']);
              return IconButton(
                icon: Icon(
                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: isSaved ? AppTheme.accent : Colors.white,
                  size: 28,
                ),
                onPressed: () {
                  if (isSaved) {
                    dbService.removeFromWatchlist(details['id']);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Removed from Watchlist')),
                    );
                  } else {
                    dbService.addToWatchlist(details);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Added to Watchlist')),
                    );
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGenreBadge(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Text(
        name,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildBackdropFallback(String imageUrl) {
    return Container(
      height: 220,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
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
              errorBuilder: (context, error, stackTrace) => Container(
                color: AppTheme.surface,
                child: const Icon(Icons.movie, color: Colors.white24, size: 54),
              ),
            ),
            Container(
              color: Colors.black38,
              child: const Center(
                child: Icon(Icons.play_circle_outline, size: 54, color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackSearchButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        borderRadius: 8,
        borderColor: Colors.greenAccent.withOpacity(0.2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.greenAccent, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatchProvidersSection(
    BuildContext context, {
    required String sectionTitle,
    required String title,
    required List<dynamic> providers,
    required bool isFree,
  }) {
    if (providers.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sectionTitle,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFree 
                ? 'No official free providers listed in your region.'
                : 'Not available on standard subscription streaming apps.',
            style: const TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic, fontSize: 12),
          ),
          if (isFree) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFallbackSearchButton(
                  context,
                  label: 'Search Tubi (Free)',
                  icon: Icons.movie_filter_rounded,
                  onTap: () => _launchStreamingService('tubi', title),
                ),
                _buildFallbackSearchButton(
                  context,
                  label: 'Search YouTube (Free)',
                  icon: Icons.play_circle_fill_rounded,
                  onTap: () => _launchStreamingService('youtube', title),
                ),
                _buildFallbackSearchButton(
                  context,
                  label: 'Search Google (Free)',
                  icon: Icons.search_rounded,
                  onTap: () {
                    final encoded = Uri.encodeComponent(title);
                    launchUrl(
                      Uri.parse('https://www.google.com/search?q=watch+$encoded+free+online'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sectionTitle,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isFree ? Colors.greenAccent : AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 64,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: providers.length,
            itemBuilder: (context, index) {
              final p = providers[index];
              final name = p['provider_name'] ?? 'Provider';
              final logoUrl = p['logo_path'] ?? '';

              return GestureDetector(
                onTap: () => _launchStreamingService(name, title),
                child: GlassCard(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  borderRadius: 10,
                  borderColor: isFree 
                      ? Colors.greenAccent.withOpacity(0.15) 
                      : Colors.white.withOpacity(0.08),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          logoUrl,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const ImageShimmerPlaceholder(borderRadius: 6);
                          },
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 32,
                            height: 32,
                            color: Colors.white12,
                            child: const Icon(Icons.play_circle_outline, color: Colors.white54, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'TAP TO LAUNCH',
                            style: TextStyle(
                              fontSize: 8,
                              letterSpacing: 0.3,
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
