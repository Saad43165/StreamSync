import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';

class StreamPlayerScreen extends StatefulWidget {
  final int id;
  final String title;
  final String mediaType;
  final int season;
  final int episode;
  final List<dynamic> seasons;

  const StreamPlayerScreen({
    super.key,
    required this.id,
    required this.title,
    required this.mediaType,
    this.season = 1,
    this.episode = 1,
    this.seasons = const [],
  });

  @override
  State<StreamPlayerScreen> createState() => _StreamPlayerScreenState();
}

class _StreamPlayerScreenState extends State<StreamPlayerScreen> {
  bool _isLoading = true;
  InAppWebViewController? _webViewController;
  late int _currentSeason;
  late int _currentEpisode;
  late int _episodeCount;
  String _mirrorSource = 'vidsrc.to'; // 'vidsrc.to', 'vidsrc.me', 'embed.su'

  @override
  void initState() {
    super.initState();
    _currentSeason = widget.season;
    _currentEpisode = widget.episode;
    _updateEpisodeCount();

    // Allow rotation inside player screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _updateEpisodeCount() {
    if (widget.seasons.isNotEmpty) {
      final currentSeasonData = widget.seasons.firstWhere(
        (s) => s['season_number'] == _currentSeason,
        orElse: () => widget.seasons.first,
      );
      _episodeCount = currentSeasonData['episode_count'] ?? 10;
    } else {
      _episodeCount = 10;
    }
  }

  String _getStreamUrl() {
    if (widget.mediaType == 'movie') {
      if (_mirrorSource == 'vidsrc.to') return 'https://vidsrc.to/embed/movie/${widget.id}';
      if (_mirrorSource == 'vidsrc.me') return 'https://vidsrc.me/embed/movie?tmdb=${widget.id}';
      return 'https://embed.su/embed/movie/${widget.id}';
    } else {
      if (_mirrorSource == 'vidsrc.to') return 'https://vidsrc.to/embed/tv/${widget.id}/$_currentSeason/$_currentEpisode';
      if (_mirrorSource == 'vidsrc.me') return 'https://vidsrc.me/embed/tv?tmdb=${widget.id}&season=$_currentSeason&episode=$_currentEpisode';
      return 'https://embed.su/embed/tv/${widget.id}/$_currentSeason/$_currentEpisode';
    }
  }

  void _reloadStream() {
    setState(() {
      _isLoading = true;
    });
    final url = _getStreamUrl();
    _webViewController?.loadUrl(urlRequest: URLRequest(url: Uri.parse(url)));
  }

  void _playNextEpisode() {
    if (_currentEpisode < _episodeCount) {
      setState(() {
        _currentEpisode++;
      });
      _saveToHistory();
      _reloadStream();
    } else {
      // Switch to next season if available
      final nextSeason = _currentSeason + 1;
      final hasNextSeason = widget.seasons.any((s) => s['season_number'] == nextSeason);
      if (hasNextSeason) {
        setState(() {
          _currentSeason = nextSeason;
          _currentEpisode = 1;
          _updateEpisodeCount();
        });
        _saveToHistory();
        _reloadStream();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have reached the final episode.')),
        );
      }
    }
  }

  void _playPrevEpisode() {
    if (_currentEpisode > 1) {
      setState(() {
        _currentEpisode--;
      });
      _saveToHistory();
      _reloadStream();
    } else if (_currentSeason > 1) {
      // Switch to previous season
      final prevSeason = _currentSeason - 1;
      final hasPrevSeason = widget.seasons.any((s) => s['season_number'] == prevSeason);
      if (hasPrevSeason) {
        setState(() {
          _currentSeason = prevSeason;
          _updateEpisodeCount();
          _currentEpisode = _episodeCount;
        });
        _saveToHistory();
        _reloadStream();
      }
    }
  }

  void _saveToHistory() {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    // Retrieve original detail map structure from history/watchlist to preserve details
    final existing = dbService.watchHistory.firstWhere(
      (element) => element['id'] == widget.id,
      orElse: () => {'id': widget.id, 'title': widget.title, 'media_type': widget.mediaType},
    );
    dbService.addToHistory(existing, season: _currentSeason, episode: _currentEpisode);
  }

  @override
  void dispose() {
    // Reset orientation restrictions back to default portrait when exiting player
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    if (isLandscape) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    final isTv = widget.mediaType == 'tv';

    // Build the WebView Widget
    Widget webviewWidget = InAppWebView(
      initialUrlRequest: URLRequest(
        url: Uri.parse(_getStreamUrl()),
      ),
      initialOptions: InAppWebViewGroupOptions(
        crossPlatform: InAppWebViewOptions(
          javaScriptEnabled: true,
          mediaPlaybackRequiresUserGesture: false,
          javaScriptCanOpenWindowsAutomatically: false,
          useShouldOverrideUrlLoading: true,
          userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          cacheEnabled: true,
        ),
        android: AndroidInAppWebViewOptions(
          useHybridComposition: true,
          domStorageEnabled: true,
          supportMultipleWindows: false,
          databaseEnabled: true,
          useWideViewPort: true,
          loadWithOverviewMode: true,
        ),
      ),
      onWebViewCreated: (controller) {
        _webViewController = controller;
      },
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final uri = navigationAction.request.url;
        if (uri == null) return NavigationActionPolicy.CANCEL;
        final urlStr = uri.toString();
        // Block known ad redirect / popup domains
        final blockedDomains = [
          'exoclick.com', 'popads.net', 'popcash.net', 'adcash.com',
          'doubleclick.net', 'adnxs.com', 'rubiconproject.com',
          'openx.net', 'adsrvr.org', 'googlesyndication.com',
        ];
        for (final blocked in blockedDomains) {
          if (urlStr.contains(blocked)) return NavigationActionPolicy.CANCEL;
        }
        // Allow all other URLs (streaming CDNs, players, etc.)
        return NavigationActionPolicy.ALLOW;
      },
      onLoadStop: (controller, url) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );

    if (isLandscape) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(child: webviewWidget),
            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
            // Floating exit button
            Positioned(
              top: 16,
              left: 16,
              child: _buildRoundButton(
                icon: Icons.arrow_back,
                onTap: () => Navigator.pop(context),
              ),
            ),
            // TV Navigation overlay in landscape
            if (isTv)
              Positioned(
                bottom: 16,
                right: 16,
                child: Row(
                  children: [
                    _buildRoundButton(
                      icon: Icons.skip_previous_rounded,
                      onTap: (_currentEpisode > 1 || _currentSeason > 1) ? _playPrevEpisode : null,
                    ),
                    const SizedBox(width: 8),
                    _buildRoundButton(
                      icon: Icons.list_rounded,
                      onTap: () => _showEpisodeSelectorSheet(context),
                    ),
                    const SizedBox(width: 8),
                    _buildRoundButton(
                      icon: Icons.skip_next_rounded,
                      onTap: (_currentEpisode < _episodeCount || widget.seasons.any((s) => s['season_number'] == _currentSeason + 1)) ? _playNextEpisode : null,
                    ),
                  ],
                ),
              ),
            // Mirror Selector in landscape
            Positioned(
              top: 16,
              right: 16,
              child: _buildRoundButton(
                icon: Icons.tune_rounded,
                onTap: () => _showMirrorSelectorSheet(context),
              ),
            ),
          ],
        ),
      );
    }

    // Portrait Layout (Top Video + Bottom controls/details)
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(widget.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 16:9 Video Box
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: Stack(
                children: [
                  webviewWidget,
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
                ],
              ),
            ),
          ),

          // Control section
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TV Controls Row
                  if (isTv) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Season $_currentSeason • Episode $_currentEpisode',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Total episodes in season: $_episodeCount',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                        // Choose Episode button
                        ElevatedButton.icon(
                          onPressed: () => _showEpisodeSelectorSheet(context),
                          icon: const Icon(Icons.list_rounded, size: 16, color: Colors.black),
                          label: const Text('All Episodes', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondaryAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (_currentEpisode > 1 || _currentSeason > 1) ? _playPrevEpisode : null,
                            icon: const Icon(Icons.skip_previous_rounded),
                            label: const Text('Prev Episode'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (_currentEpisode < _episodeCount || widget.seasons.any((s) => s['season_number'] == _currentSeason + 1)) ? _playNextEpisode : null,
                            icon: const Icon(Icons.skip_next_rounded, color: Colors.black),
                            label: const Text('Next Episode', style: TextStyle(color: Colors.black)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accent,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Settings / Mirror section
                  const Text('STREAMING SOURCE MIRRORS', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  const SizedBox(height: 10),
                  _buildMirrorOption('vidsrc.to', 'Mirror 1 (Super HD - Recommended)', Icons.hd_rounded),
                  _buildMirrorOption('vidsrc.me', 'Mirror 2 (Fast Play)', Icons.flash_on_rounded),
                  _buildMirrorOption('embed.su', 'Mirror 3 (Auto Server)', Icons.auto_awesome_rounded),
                  
                  const SizedBox(height: 30),
                  
                  // Helpful notice
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Colors.white30, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'If video buffers or fails to load, try switching mirror sources or refreshing the player.',
                            style: TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ),
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

  Widget _buildRoundButton({required IconData icon, required VoidCallback? onTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Container(
        color: Colors.black54,
        child: IconButton(
          icon: Icon(icon, color: onTap == null ? Colors.white24 : Colors.white),
          onPressed: onTap,
        ),
      ),
    );
  }

  Widget _buildMirrorOption(String value, String title, IconData icon) {
    final isSelected = _mirrorSource == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _mirrorSource = value;
        });
        _reloadStream();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent.withAlpha(20) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppTheme.accent : Colors.white12),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppTheme.accent : Colors.white54, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: AppTheme.accent, size: 18),
          ],
        ),
      ),
    );
  }

  void _showMirrorSelectorSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          child: StatefulBuilder(builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  const Text('Choose Mirror Source', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  _buildMirrorOptionSheet(context, 'vidsrc.to', 'Mirror 1 — Super HD', Icons.hd_rounded, setModalState),
                  _buildMirrorOptionSheet(context, 'vidsrc.me', 'Mirror 2 — Fast Play', Icons.flash_on_rounded, setModalState),
                  _buildMirrorOptionSheet(context, 'embed.su', 'Mirror 3 — Auto Server', Icons.auto_awesome_rounded, setModalState),
                  const SizedBox(height: 8),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildMirrorOptionSheet(BuildContext context, String value, String title, IconData icon, StateSetter setModalState) {
    final isSelected = _mirrorSource == value;
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppTheme.accent : Colors.white54),
      title: Text(title, style: TextStyle(color: Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppTheme.accent) : null,
      onTap: () {
        setModalState(() {
          _mirrorSource = value;
        });
        setState(() {
          _mirrorSource = value;
        });
        _reloadStream();
        Navigator.pop(context);
      },
    );
  }

  void _showEpisodeSelectorSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          final validSeasons = widget.seasons.where((s) => (s['season_number'] as int? ?? 0) >= 1).toList();

          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                const Text('Select Season & Episode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                
                // Season tabs selector
                if (validSeasons.isNotEmpty)
                  SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: validSeasons.length,
                      itemBuilder: (ctx, index) {
                        final sNum = validSeasons[index]['season_number'] as int? ?? 1;
                        final isSel = _currentSeason == sNum;
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              _currentSeason = sNum;
                              final sData = validSeasons.firstWhere((s) => s['season_number'] == sNum);
                              _episodeCount = sData['episode_count'] ?? 10;
                            });
                            setState(() {
                              _currentSeason = sNum;
                              _updateEpisodeCount();
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSel ? AppTheme.accent : Colors.white.withAlpha(8),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Season $sNum',
                              style: TextStyle(color: isSel ? Colors.black : Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                
                const SizedBox(height: 16),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 12),
                
                // Grid of Episodes
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: _episodeCount,
                    itemBuilder: (ctx, index) {
                      final epNum = index + 1;
                      final isSel = _currentEpisode == epNum;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _currentEpisode = epNum;
                          });
                          _saveToHistory();
                          _reloadStream();
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSel ? AppTheme.secondaryAccent.withAlpha(20) : Colors.white.withAlpha(5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSel ? AppTheme.secondaryAccent : Colors.white12,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('EP', style: TextStyle(color: isSel ? AppTheme.secondaryAccent : Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text('$epNum', style: TextStyle(color: isSel ? Colors.white : Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }
}
