import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/tmdb_service.dart';
import '../services/database_service.dart';
import '../services/download_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/shimmer_loading.dart';
import 'native_stream_player_screen.dart';

class DetailsScreen extends StatefulWidget {
  final int id;
  final String mediaType;
  final String? posterUrl;

  const DetailsScreen({
    super.key,
    required this.id,
    required this.mediaType,
    this.posterUrl,
  });

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? _details;
  bool _isLoading = true;
  String? _error;

  // TV Selector variables
  int _selectedSeason = 1;
  int _selectedEpisode = 1;
  int _episodeCountForSelectedSeason = 10;

  // Scroll-aware animation
  late ScrollController _scrollController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _loadDetails();
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  Future<void> _loadDetails() async {
    try {
      final tmdbService = Provider.of<TMDBService>(context, listen: false);
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final details = await tmdbService.fetchDetails(
        widget.id,
        widget.mediaType,
        dbService.selectedCountry,
      );

      if (!mounted) return;

      if (details != null) {
        setState(() {
          _details = details;
          _isLoading = false;

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

        _fadeController.forward();
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Could not load details';
        });
      }
    } catch (e) {
      debugPrint('Error loading details: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load: ${e.toString()}';
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ── Image URL builder ──────────────────────────────────────────────────

  static String _buildImageUrl(String? path, {int width = 500}) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return 'https://image.tmdb.org/t/p/w$width$path';
  }

  // ── Download options bottom sheet ──────────────────────────────────────

  void _showDownloadOptionsDialog(Map<String, dynamic> details) {
    String selectedQuality = '1080p';
    String selectedLanguage = 'English';

    final downloadService = Provider.of<DownloadService>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20, 20, 20,
                MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.download_for_offline_rounded,
                          color: AppTheme.accent, size: 24),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Download for offline',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        icon: const Icon(Icons.close, color: Colors.white54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Quality',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    children: ['4K UHD', '1080p', '720p', '480p'].map((q) {
                      final isSel = selectedQuality == q;
                      return ChoiceChip(
                        label: Text(q),
                        selected: isSel,
                        onSelected: (val) {
                          if (val) setModalState(() => selectedQuality = q);
                        },
                        selectedColor: AppTheme.accent,
                        backgroundColor: Colors.white.withAlpha(15),
                        labelStyle: TextStyle(
                          color: isSel ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.white.withOpacity(0.08)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text('Audio track',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    children: ['English', 'Spanish', 'Hindi', 'French'].map((l) {
                      final isSel = selectedLanguage == l;
                      return ChoiceChip(
                        label: Text(l),
                        selected: isSel,
                        onSelected: (val) {
                          if (val) setModalState(() => selectedLanguage = l);
                        },
                        selectedColor: AppTheme.accent,
                        backgroundColor: Colors.white.withAlpha(15),
                        labelStyle: TextStyle(
                          color: isSel ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.white.withOpacity(0.08)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      downloadService.startDownload(
                        details: details,
                        selectedQuality: selectedQuality,
                        selectedLanguage: selectedLanguage,
                      );
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          backgroundColor: Colors.greenAccent,
                          content: Text(
                            'Download started — check the progress indicator.',
                            style: TextStyle(color: Colors.black),
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.download_rounded, color: Colors.black),
                    label: const Text(
                      'Start download',
                      style: TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Delete downloaded file + DB record ─────────────────────────────────

  Future<void> _deleteDownload(
      BuildContext context, DatabaseService dbService, int id) async {
    final record = dbService.downloads.firstWhere(
          (d) => d['id'] == id,
      orElse: () => {},
    );
    final filePath = record['local_file_path'] as String?;
    if (filePath != null) {
      final file = File(filePath);
      if (await file.exists()) await file.delete();
    }

    await dbService.removeDownload(id);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download deleted from device.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Streaming service launcher ─────────────────────────────────────────

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

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const _DetailsSkeleton();

    if (_error != null || _details == null) {
      return _buildErrorScreen();
    }

    final details = _details!;
    final title = details['title'] ?? 'Untitled';
    final overview = details['overview'] ?? '';
    final voteAverage = (details['vote_average'] as num?)?.toDouble() ?? 0.0;
    final rating = voteAverage.toStringAsFixed(1);
    final releaseDate = details['release_date'] ?? 'N/A';
    final releaseYear = releaseDate.toString().split('-').first;
    final freeOptions = details['free_options'] as List<dynamic>? ?? [];
    final subOptions = details['subscription_options'] as List<dynamic>? ?? [];
    final genresList = details['genres'] as List<dynamic>? ?? [];
    final castList = details['cast'] as List<dynamic>? ?? [];

    final backdropUrl = _buildImageUrl(details['backdrop_path'], width: 1280);
    final trailerId = details['trailer_id'];

    return Scaffold(
      backgroundColor: AppTheme.background,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Parallax backdrop with scroll offset
          Positioned.fill(
            child: _ParallaxBackdrop(
              imageUrl: backdropUrl,
              scrollOffset: _scrollOffset,
            ),
          ),

          // Scrollable content with fade animation
          FadeTransition(
            opacity: _fadeAnimation,
            child: SafeArea(
              top: false,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Top spacing
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).padding.top + 44,
                    ),
                  ),

                  // Trailer or backdrop fallback
                  SliverToBoxAdapter(
                    child: trailerId != null
                        ? _TrailerThumbnail(
                      trailerId: trailerId.toString(),
                      onTap: () async {
                        final url = Uri.parse(
                            'https://www.youtube.com/watch?v=$trailerId');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                    )
                        : _BackdropFallback(imageUrl: backdropUrl),
                  ),

                  // Content sections
                  SliverToBoxAdapter(child: const SizedBox(height: 20)),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _TitleBlock(
                        posterUrl: widget.posterUrl ?? details['poster_path'],
                        posterHeroTag: 'poster_${widget.id}',
                        title: title,
                        rating: rating,
                        releaseYear: releaseYear,
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(child: const SizedBox(height: 22)),

                  // Watch button
                  SliverToBoxAdapter(
                    child: _buildWatchStreamButton(context, details),
                  ),

                  // Details sections
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (genresList.isNotEmpty) ...[
                            _GenreRow(genres: genresList),
                            const SizedBox(height: 26),
                          ],

                          const _SectionHeader(
                              icon: Icons.play_circle_outline_rounded,
                              label: 'Watch free'),
                          const SizedBox(height: 12),
                          _buildWatchProvidersSection(
                            context,
                            title: title,
                            providers: freeOptions,
                            isFree: true,
                          ),

                          const SizedBox(height: 26),

                          const _SectionHeader(
                              icon: Icons.workspace_premium_outlined,
                              label: 'Also on subscription'),
                          const SizedBox(height: 12),
                          _buildWatchProvidersSection(
                            context,
                            title: title,
                            providers: subOptions,
                            isFree: false,
                          ),

                          const SizedBox(height: 26),

                          const _SectionHeader(
                              icon: Icons.notes_rounded,
                              label: 'Synopsis'),
                          const SizedBox(height: 10),
                          _ExpandableText(
                            text: overview.isEmpty
                                ? 'No description available.'
                                : overview,
                          ),

                          const SizedBox(height: 26),

                          if (castList.isNotEmpty) ...[
                            const _SectionHeader(
                                icon: Icons.groups_2_outlined,
                                label: 'Cast & crew'),
                            const SizedBox(height: 14),
                            _CastRow(castList: castList),
                          ],

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Glass app bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _GlassAppBar(
              details: details,
              onDownloadTap: (dbService) {
                if (dbService.isDownloaded(details['id'])) {
                  _deleteDownload(context, dbService, details['id'] as int);
                } else {
                  _showDownloadOptionsDialog(details);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white24, size: 48),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Couldn\'t load this title.',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text('Check your connection and try again.',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back,
                      color: Colors.white70, size: 18),
                  label: const Text('Go back',
                      style: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(width: 20),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _error = null;
                    });
                    _loadDetails();
                  },
                  icon: const Icon(Icons.refresh,
                      color: Colors.white70, size: 18),
                  label: const Text('Retry',
                      style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Watch button ───────────────────────────────────────────────────────

  Widget _buildWatchStreamButton(
      BuildContext context, Map<String, dynamic> details) {
    final title = details['title'] ?? details['name'] ?? 'Untitled';
    final isTv = widget.mediaType == 'tv';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          if (isTv) _buildTvSelector(details),

          // Primary watch button
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                HapticFeedback.mediumImpact();
                Provider.of<DatabaseService>(context, listen: false)
                    .addToHistory(
                  details,
                  season: widget.mediaType == 'tv' ? _selectedSeason : null,
                  episode: widget.mediaType == 'tv' ? _selectedEpisode : null,
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NativeStreamPlayerScreen(
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
              child: Ink(
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF8B5CF6)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withOpacity(0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isTv
                          ? 'Watch S$_selectedSeason · E$_selectedEpisode'
                          : 'Watch full movie',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15.5),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          _WatchlistButton(itemId: widget.id, details: details),
        ],
      ),
    );
  }

  Widget _buildTvSelector(Map<String, dynamic> details) {
    final seasons = details['seasons'] as List<dynamic>? ?? [];
    if (seasons.isEmpty) return const SizedBox();

    final validSeasons = seasons
        .where((s) => (s['season_number'] as int? ?? 0) >= 1)
        .toList();
    if (validSeasons.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        borderRadius: 14,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SEASON',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                          color: AppTheme.textSecondary)),
                  const SizedBox(height: 2),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedSeason,
                      dropdownColor: AppTheme.surface,
                      icon: const Icon(Icons.expand_more_rounded,
                          color: Colors.white, size: 20),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                      isDense: true,
                      items: validSeasons.map((s) {
                        final sNum = s['season_number'] as int? ?? 1;
                        return DropdownMenuItem<int>(
                            value: sNum, child: Text('Season $sNum'));
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
                            _episodeCountForSelectedSeason =
                                targetSeason['episode_count'] ?? 10;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            Container(
                width: 1,
                height: 32,
                color: Colors.white12,
                margin: const EdgeInsets.symmetric(horizontal: 12)),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('EPISODE',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                          color: AppTheme.textSecondary)),
                  const SizedBox(height: 2),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedEpisode,
                      dropdownColor: AppTheme.surface,
                      icon: const Icon(Icons.expand_more_rounded,
                          color: Colors.white, size: 20),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                      isDense: true,
                      items: List.generate(
                          _episodeCountForSelectedSeason,
                              (i) => i + 1)
                          .map((epNum) => DropdownMenuItem<int>(
                          value: epNum,
                          child: Text('Episode $epNum')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null)
                          setState(() => _selectedEpisode = val);
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

  Widget _buildWatchProvidersSection(
      BuildContext context, {
        required String title,
        required List<dynamic> providers,
        required bool isFree,
      }) {
    if (providers.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFree
                ? 'No official free providers listed in your region.'
                : 'Not available on standard subscription streaming apps.',
            style: const TextStyle(
                color: AppTheme.textSecondary,
                fontStyle: FontStyle.italic,
                fontSize: 12.5),
          ),
          if (isFree) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FallbackSearchChip(
                  label: 'Search Tubi',
                  icon: Icons.movie_filter_rounded,
                  onTap: () => _launchStreamingService('tubi', title),
                ),
                _FallbackSearchChip(
                  label: 'Search YouTube',
                  icon: Icons.play_circle_fill_rounded,
                  onTap: () => _launchStreamingService('youtube', title),
                ),
                _FallbackSearchChip(
                  label: 'Search Google',
                  icon: Icons.search_rounded,
                  onTap: () {
                    final encoded = Uri.encodeComponent(title);
                    launchUrl(
                      Uri.parse(
                          'https://www.google.com/search?q=watch+$encoded+free+online'),
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

    return SizedBox(
      height: 66,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: providers.length,
        itemBuilder: (context, index) {
          final p = providers[index] as Map<String, dynamic>;
          final name = p['provider_name'] ?? 'Provider';
          final logoUrl = p['logo_path'] ?? '';
          return _ProviderCard(
            name: name,
            logoUrl: logoUrl,
            isFree: isFree,
            onTap: () => _launchStreamingService(name, title),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// New Performance Widgets
// ═══════════════════════════════════════════════════════════════════════════

class _ParallaxBackdrop extends StatelessWidget {
  final String imageUrl;
  final double scrollOffset;

  const _ParallaxBackdrop({
    required this.imageUrl,
    required this.scrollOffset,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Transform.translate(
          offset: Offset(0, scrollOffset * 0.3),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.7,
            placeholder: (_, __) => Container(color: AppTheme.surface),
            errorWidget: (_, __, ___) => Container(color: AppTheme.surface),
            memCacheWidth: 640,
            maxWidthDiskCache: 1280,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.35),
                AppTheme.background.withOpacity(0.92),
                AppTheme.background,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.38, 0.62],
            ),
          ),
        ),
      ],
    );
  }
}

class _GenreRow extends StatelessWidget {
  final List<dynamic> genres;

  const _GenreRow({required this.genres});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: genres.map((g) => _GenreBadge(name: g.toString())).toList(),
    );
  }
}

class _CastRow extends StatelessWidget {
  final List<dynamic> castList;

  const _CastRow({required this.castList});

  @override
  Widget build(BuildContext context) {
    final displayCast = castList.length > 20 ? castList.sublist(0, 20) : castList;

    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: displayCast.length,
        itemBuilder: (context, index) {
          final cast = displayCast[index] as Map<String, dynamic>;
          return _CastCard(
            name: cast['name'] ?? 'Unknown',
            character: cast['character'] ?? '',
            profilePath: cast['profile_path'],
          );
        },
      ),
    );
  }
}

class _ExpandableText extends StatefulWidget {
  final String text;

  const _ExpandableText({required this.text});

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;
  static const int _maxLines = 4;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
            height: 1.55,
          ),
          maxLines: _expanded ? null : _maxLines,
          overflow: _expanded ? null : TextOverflow.ellipsis,
        ),
        if (widget.text.length > 200)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _expanded ? 'Show less' : 'Read more',
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Original Widgets (Kept exactly as they were)
// ═══════════════════════════════════════════════════════════════════════════

class _GlassAppBar extends StatelessWidget {
  final Map<String, dynamic> details;
  final void Function(DatabaseService dbService) onDownloadTap;

  const _GlassAppBar({
    required this.details,
    required this.onDownloadTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.45),
                Colors.black.withOpacity(0.0)
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _GlassIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.pop(context),
                ),
                Consumer<DatabaseService>(
                  builder: (context, dbService, _) {
                    final isDownloaded = dbService.isDownloaded(details['id']);
                    final isSaved = dbService.isInWatchlist(details['id']);

                    final downloadService = Provider.of<DownloadService>(
                        context, listen: true);
                    final isActivelyDownloading =
                    downloadService.isDownloading(details['id'] as int);

                    return Row(
                      children: [
                        _GlassIconButton(
                          icon: isActivelyDownloading
                              ? Icons.downloading_rounded
                              : isDownloaded
                              ? Icons.download_done_rounded
                              : Icons.download_rounded,
                          iconColor: isActivelyDownloading
                              ? AppTheme.accent
                              : isDownloaded
                              ? Colors.greenAccent
                              : Colors.white,
                          onTap: isActivelyDownloading
                              ? () {}
                              : () => onDownloadTap(dbService),
                        ),
                        const SizedBox(width: 8),
                        _GlassIconButton(
                          icon: isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          iconColor: isSaved ? AppTheme.accent : Colors.white,
                          onTap: () {
                            if (isSaved) {
                              dbService.removeFromWatchlist(details['id']);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Removed from watchlist'),
                                  ));
                            } else {
                              dbService.addToWatchlist(details);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Added to watchlist'),
                                  ));
                            }
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, color: iconColor, size: 19),
        ),
      ),
    );
  }
}

class _TrailerThumbnail extends StatelessWidget {
  final String trailerId;
  final VoidCallback onTap;
  const _TrailerThumbnail({
    required this.trailerId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 210,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
          boxShadow: const [
            BoxShadow(
                color: Colors.black54,
                blurRadius: 15,
                offset: Offset(0, 6))
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: 'https://img.youtube.com/vi/$trailerId/hqdefault.jpg',
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: AppTheme.surface),
              errorWidget: (_, __, ___) => Container(color: AppTheme.surface),
              memCacheWidth: 640,
            ),
            Container(color: Colors.black.withOpacity(0.15)),
            Center(
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 32),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(6)),
                child: const Text('TRAILER',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackdropFallback extends StatelessWidget {
  final String imageUrl;
  const _BackdropFallback({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 10)
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: AppTheme.surface),
              errorWidget: (_, __, ___) => Container(
                color: AppTheme.surface,
                child: const Icon(Icons.movie,
                    color: Colors.white24, size: 54),
              ),
              memCacheWidth: 640,
            ),
            Container(
              color: Colors.black38,
              child: const Center(
                  child: Icon(Icons.play_circle_outline,
                      size: 54, color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  final dynamic posterUrl;
  final String posterHeroTag;
  final String title;
  final String rating;
  final String releaseYear;

  const _TitleBlock({
    required this.posterUrl,
    required this.posterHeroTag,
    required this.title,
    required this.rating,
    required this.releaseYear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (posterUrl != null)
          Hero(
            tag: posterHeroTag,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 96,
                height: 144,
                margin: const EdgeInsets.only(right: 16),
                decoration: const BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black54, blurRadius: 12)
                    ]),
                child: CachedNetworkImage(
                  imageUrl: posterUrl is String ? posterUrl : _DetailsScreenState._buildImageUrl(posterUrl, width: 200),
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: AppTheme.surface),
                  errorWidget: (_, __, ___) => Container(
                    color: AppTheme.surface,
                    child: const Icon(Icons.movie,
                        color: Colors.white24, size: 32),
                  ),
                  memCacheWidth: 200,
                ),
              ),
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.2,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryAccent
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            color: AppTheme.secondaryAccent,
                            size: 15),
                        const SizedBox(width: 4),
                        Text(rating,
                            style: const TextStyle(
                                color: AppTheme.secondaryAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                  Text(releaseYear,
                      style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white30),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('HD',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.accent, size: 17),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.1),
        ),
      ],
    );
  }
}

class _GenreBadge extends StatelessWidget {
  final String name;
  const _GenreBadge({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Text(name,
          style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _FallbackSearchChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _FallbackSearchChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        borderRadius: 10,
        borderColor: Colors.greenAccent.withOpacity(0.2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.greenAccent, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final String name;
  final String logoUrl;
  final bool isFree;
  final VoidCallback onTap;
  const _ProviderCard({
    required this.name,
    required this.logoUrl,
    required this.isFree,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        borderRadius: 12,
        borderColor: isFree
            ? Colors.greenAccent.withOpacity(0.15)
            : Colors.white.withOpacity(0.08),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: CachedNetworkImage(
                imageUrl: logoUrl,
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                placeholder: (_, __) => const ImageShimmerPlaceholder(borderRadius: 7),
                errorWidget: (_, __, ___) => Container(
                  width: 34,
                  height: 34,
                  color: Colors.white12,
                  child: const Icon(Icons.play_circle_outline,
                      color: Colors.white54, size: 18),
                ),
                memCacheWidth: 68,
              ),
            ),
            const SizedBox(width: 9),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  isFree ? 'FREE · TAP TO OPEN' : 'TAP TO OPEN',
                  style: TextStyle(
                    fontSize: 8,
                    letterSpacing: 0.3,
                    color: isFree
                        ? Colors.greenAccent
                        : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CastCard extends StatelessWidget {
  final String name;
  final String character;
  final String? profilePath;
  const _CastCard({
    required this.name,
    required this.character,
    this.profilePath,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = profilePath != null
        ? 'https://image.tmdb.org/t/p/w200$profilePath'
        : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=333333&color=ffffff';

    return Container(
      width: 88,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: 68,
              height: 68,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 68,
                height: 68,
                color: AppTheme.surface,
              ),
              errorWidget: (_, __, ___) => Container(
                width: 68,
                height: 68,
                color: AppTheme.surface,
                child: const Icon(Icons.person, color: Colors.white24),
              ),
              memCacheWidth: 136,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            character,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _WatchlistButton extends StatelessWidget {
  final int itemId;
  final Map<String, dynamic> details;
  const _WatchlistButton({
    required this.itemId,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<DatabaseService, bool>(
      selector: (_, db) => db.isInWatchlist(itemId),
      builder: (context, inWatchlist, child) {
        final db = Provider.of<DatabaseService>(context, listen: false);
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            if (inWatchlist) {
              db.removeFromWatchlist(itemId);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Removed from watchlist'),
                    backgroundColor: Colors.black87,
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ));
            } else {
              db.addToWatchlist(details);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❤️ Added to watchlist'),
                    backgroundColor: Color(0xFF6C63FF),
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ));
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: inWatchlist
                  ? const Color(0xFF6C63FF).withOpacity(0.18)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: inWatchlist
                      ? const Color(0xFF6C63FF)
                      : Colors.white24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                    inWatchlist
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: inWatchlist
                        ? const Color(0xFF6C63FF)
                        : Colors.white70,
                    size: 19),
                const SizedBox(width: 8),
                Text(
                    inWatchlist ? 'In watchlist' : 'Add to watchlist',
                    style: TextStyle(
                        color: inWatchlist
                            ? const Color(0xFF6C63FF)
                            : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DetailsSkeleton extends StatefulWidget {
  const _DetailsSkeleton();

  @override
  State<_DetailsSkeleton> createState() => _DetailsSkeletonState();
}

class _DetailsSkeletonState extends State<_DetailsSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.2, end: 0.6).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _shimmerBlock(double w, double h, {double r = 8}) {
    return Container(
      width: w,
      height: h,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(r),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _anim,
          builder: (_, child) =>
              Opacity(opacity: _anim.value, child: child),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBlock(double.infinity, 210, r: 18),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmerBlock(96, 144, r: 14),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _shimmerBlock(double.infinity, 22),
                          _shimmerBlock(160, 16),
                          _shimmerBlock(100, 16),
                        ],
                      ),
                    ),
                  ],
                ),
                _shimmerBlock(double.infinity, 56, r: 16),
                const SizedBox(height: 8),
                _shimmerBlock(double.infinity, 44, r: 14),
                const SizedBox(height: 20),
                _shimmerBlock(180, 18),
                _shimmerBlock(double.infinity, 13),
                _shimmerBlock(double.infinity, 13),
                _shimmerBlock(240, 13),
              ],
            ),
          ),
        ),
      ),
    );
  }
}