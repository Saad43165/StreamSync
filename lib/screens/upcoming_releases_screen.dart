import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'details_screen.dart';

class UpcomingReleasesScreen extends StatefulWidget {
  const UpcomingReleasesScreen({super.key});

  @override
  State<UpcomingReleasesScreen> createState() => _UpcomingReleasesScreenState();
}

class _UpcomingReleasesScreenState extends State<UpcomingReleasesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _sortBy = 'date'; // 'date' or 'title'

  // All future upcoming titles — Movies & Series
  static final List<Map<String, dynamic>> _upcomingMovies = [
    {
      'id': 1010,
      'title': 'Avatar 3: Fire and Ash',
      'media_type': 'movie',
      'poster_path': 'https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=500',
      'backdrop_path': 'https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=1000',
      'vote_average': 0.0,
      'release_date': '2026-12-19',
      'overview': 'The third chapter of James Cameron\'s epic Pandora saga. Fire Clan vs. Water Clan in an all-new conflict.',
      'genres': ['Sci-Fi', 'Adventure', 'Fantasy'],
    },
    {
      'id': 1011,
      'title': 'Avengers: Doomsday',
      'media_type': 'movie',
      'poster_path': 'https://images.unsplash.com/photo-1478760329108-5c3ed9d495a0?w=500',
      'backdrop_path': 'https://images.unsplash.com/photo-1478760329108-5c3ed9d495a0?w=1000',
      'vote_average': 0.0,
      'release_date': '2027-05-01',
      'overview': 'Robert Downey Jr. returns as Doctor Doom. Earth\'s Mightiest Heroes assemble once more.',
      'genres': ['Action', 'Superhero', 'Sci-Fi'],
    },
    {
      'id': 1012,
      'title': 'Mission: Impossible – The Final Reckoning',
      'media_type': 'movie',
      'poster_path': 'https://images.unsplash.com/photo-1517604931442-7e0c8ed2963c?w=500',
      'backdrop_path': 'https://images.unsplash.com/photo-1517604931442-7e0c8ed2963c?w=1000',
      'vote_average': 0.0,
      'release_date': '2027-05-23',
      'overview': 'Ethan Hunt\'s most dangerous mission yet. The world hangs in balance as the Entity evolves.',
      'genres': ['Action', 'Thriller', 'Espionage'],
    },
    {
      'id': 1013,
      'title': 'Superman (2026 reboot)',
      'media_type': 'movie',
      'poster_path': 'https://images.unsplash.com/photo-1531259683007-016a7b628fc3?w=500',
      'backdrop_path': 'https://images.unsplash.com/photo-1531259683007-016a7b628fc3?w=1000',
      'vote_average': 0.0,
      'release_date': '2026-11-11',
      'overview': 'James Gunn\'s reboot of the DCU. David Corenswet dons the cape for the new era of DC.',
      'genres': ['Action', 'Superhero', 'Adventure'],
    },
    {
      'id': 1014,
      'title': 'The Fantastic Four: First Steps',
      'media_type': 'movie',
      'poster_path': 'https://images.unsplash.com/photo-1501854140801-50d01698950b?w=500',
      'backdrop_path': 'https://images.unsplash.com/photo-1501854140801-50d01698950b?w=1000',
      'vote_average': 0.0,
      'release_date': '2026-10-25',
      'overview': 'Marvel\'s First Family arrives in the MCU. Set in the 1960s retro-futuristic alternate Earth.',
      'genres': ['Superhero', 'Action', 'Sci-Fi'],
    },
    {
      'id': 1015,
      'title': 'Jurassic World Rebirth',
      'media_type': 'movie',
      'poster_path': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500',
      'backdrop_path': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=1000',
      'vote_average': 0.0,
      'release_date': '2026-08-02',
      'overview': 'A new era for Jurassic World. Scarlett Johansson leads a covert ops mission on a dinosaur-ruled island.',
      'genres': ['Action', 'Adventure', 'Thriller'],
    },
    {
      'id': 1016,
      'title': 'Zootopia 2',
      'media_type': 'movie',
      'poster_path': 'https://images.unsplash.com/photo-1551632811-561732d1e306?w=500',
      'backdrop_path': 'https://images.unsplash.com/photo-1551632811-561732d1e306?w=1000',
      'vote_average': 0.0,
      'release_date': '2026-11-26',
      'overview': 'Nick and Judy return for a brand-new adventure as Zootopia expands its world.',
      'genres': ['Animation', 'Family', 'Comedy'],
    },
    {
      'id': 1017,
      'title': 'Avengers: Secret Wars',
      'media_type': 'movie',
      'poster_path': 'https://images.unsplash.com/photo-1560759226-14da22a643ef?w=500',
      'backdrop_path': 'https://images.unsplash.com/photo-1560759226-14da22a643ef?w=1000',
      'vote_average': 0.0,
      'release_date': '2028-05-07',
      'overview': 'The Multiverse Saga concludes. Every hero from across all timelines collides in Secret Wars.',
      'genres': ['Superhero', 'Action', 'Sci-Fi'],
    },
  ];

  static final List<Map<String, dynamic>> _upcomingSeries = [
    {
      'id': 2010,
      'title': 'Daredevil: Born Again Season 2',
      'name': 'Daredevil: Born Again S2',
      'media_type': 'tv',
      'poster_path': 'https://images.unsplash.com/photo-1559628233-100c798642b3?w=500',
      'backdrop_path': 'https://images.unsplash.com/photo-1559628233-100c798642b3?w=1000',
      'vote_average': 0.0,
      'release_date': '2027-03-04',
      'overview': 'Matt Murdock continues protecting Hell\'s Kitchen. Kingpin is now Mayor. The battle for New York has only begun.',
      'genres': ['Action', 'Drama', 'Crime'],
    },
    {
      'id': 2011,
      'title': 'The Last of Us Season 3',
      'name': 'The Last of Us S3',
      'media_type': 'tv',
      'poster_path': 'https://images.unsplash.com/photo-1509347528160-9a9e33742cdb?w=500',
      'backdrop_path': 'https://images.unsplash.com/photo-1509347528160-9a9e33742cdb?w=1000',
      'vote_average': 0.0,
      'release_date': '2027-08-15',
      'overview': 'Joel and Ellie\'s story reaches its conclusion. The Fireflies have a new plan for a cure.',
      'genres': ['Drama', 'Horror', 'Post-Apocalyptic'],
    },
    {
      'id': 2012,
      'title': 'House of the Dragon Season 3',
      'name': 'House of the Dragon S3',
      'media_type': 'tv',
      'poster_path': 'https://images.unsplash.com/photo-1504198322253-cfa87a0ff60f?w=500',
      'backdrop_path': 'https://images.unsplash.com/photo-1504198322253-cfa87a0ff60f?w=1000',
      'vote_average': 0.0,
      'release_date': '2026-08-01',
      'overview': 'The Dance of Dragons intensifies. Dragonfire fills the skies of Westeros as the civil war reaches its bloody peak.',
      'genres': ['Fantasy', 'Drama', 'Action'],
    },
    {
      'id': 2013,
      'title': 'Stranger Things Season 5',
      'name': 'Stranger Things S5',
      'media_type': 'tv',
      'poster_path': 'https://images.unsplash.com/photo-1535016120720-40c646be5580?w=500',
      'backdrop_path': 'https://images.unsplash.com/photo-1535016120720-40c646be5580?w=1000',
      'vote_average': 0.0,
      'release_date': '2026-11-26',
      'overview': 'The final season. Vecna returns and Hawkins faces its ultimate reckoning. Only Eleven can stop the Upside Down.',
      'genres': ['Sci-Fi', 'Horror', 'Drama'],
    },
    {
      'id': 2014,
      'title': 'Peaky Blinders: The Movie',
      'name': 'Peaky Blinders: Film',
      'media_type': 'tv',
      'poster_path': 'https://images.unsplash.com/photo-1473188588951-666fce8e7c68?w=500',
      'backdrop_path': 'https://images.unsplash.com/photo-1473188588951-666fce8e7c68?w=1000',
      'vote_average': 0.0,
      'release_date': '2027-06-15',
      'overview': 'Cillian Murphy returns as Tommy Shelby. World War II has begun and the Shelby empire must survive.',
      'genres': ['Crime', 'Drama', 'Historical'],
    },
    {
      'id': 2015,
      'title': 'Squid Game Season 3',
      'name': 'Squid Game S3',
      'media_type': 'tv',
      'poster_path': 'https://images.unsplash.com/photo-1596776340886-fcc27a06baf5?w=500',
      'backdrop_path': 'https://images.unsplash.com/photo-1596776340886-fcc27a06baf5?w=1000',
      'vote_average': 0.0,
      'release_date': '2026-09-27',
      'overview': 'The final chapter of the deadly games. Gi-hun faces the Front Man in a final, deadly confrontation.',
      'genres': ['Thriller', 'Drama', 'Korean'],
    },
    {
      'id': 2016,
      'title': 'Wednesday Season 3',
      'name': 'Wednesday S3',
      'media_type': 'tv',
      'poster_path': 'https://images.unsplash.com/photo-1531501410720-c8d437636169?w=500',
      'backdrop_path': 'https://images.unsplash.com/photo-1531501410720-c8d437636169?w=1000',
      'vote_average': 0.0,
      'release_date': '2026-09-10',
      'overview': 'Wednesday Addams returns to Nevermore Academy with new mysteries, new monsters, and new mayhem.',
      'genres': ['Comedy', 'Horror', 'Mystery'],
    },
  ];

  List<Map<String, dynamic>> _getSortedMovies() {
    final list = List<Map<String, dynamic>>.from(_upcomingMovies);
    if (_sortBy == 'date') {
      list.sort((a, b) => (a['release_date'] as String).compareTo(b['release_date'] as String));
    } else {
      list.sort((a, b) => (a['title'] as String).compareTo(b['title'] as String));
    }
    return list;
  }

  List<Map<String, dynamic>> _getSortedSeries() {
    final list = List<Map<String, dynamic>>.from(_upcomingSeries);
    if (_sortBy == 'date') {
      list.sort((a, b) => (a['release_date'] as String).compareTo(b['release_date'] as String));
    } else {
      list.sort((a, b) => (a['title'] as String).compareTo(b['title'] as String));
    }
    return list;
  }

  String _formatDate(String rawDate) {
    try {
      final parts = rawDate.split('-');
      if (parts.length < 3) return rawDate;
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final monthIndex = int.parse(parts[1]) - 1;
      return '${months[monthIndex]} ${parts[2]}, ${parts[0]}';
    } catch (_) {
      return rawDate;
    }
  }

  String _getCountdown(String rawDate) {
    try {
      final releaseDate = DateTime.parse(rawDate);
      final now = DateTime.now();
      if (releaseDate.isBefore(now)) return 'Released';
      final diff = releaseDate.difference(now);
      if (diff.inDays > 365) {
        final years = (diff.inDays / 365).floor();
        return '~$years year${years > 1 ? 's' : ''} away';
      } else if (diff.inDays > 30) {
        final months = (diff.inDays / 30).floor();
        return '~$months month${months > 1 ? 's' : ''} away';
      } else {
        return '${diff.inDays} days away';
      }
    } catch (_) {
      return 'Coming Soon';
    }
  }

  Color _getCountdownColor(String rawDate) {
    try {
      final releaseDate = DateTime.parse(rawDate);
      final now = DateTime.now();
      if (releaseDate.isBefore(now)) return Colors.white38;
      final diff = releaseDate.difference(now);
      if (diff.inDays < 60) return Colors.greenAccent;
      if (diff.inDays < 180) return AppTheme.accent;
      return AppTheme.textSecondary;
    } catch (_) {
      return AppTheme.textSecondary;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Upcoming Releases', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Only future dates — sorted for you', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded, color: Colors.white70),
            color: AppTheme.surface,
            onSelected: (val) => setState(() => _sortBy = val),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'date',
                child: Row(children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: _sortBy == 'date' ? AppTheme.accent : Colors.white70),
                  const SizedBox(width: 8),
                  Text('Sort by Date', style: TextStyle(color: _sortBy == 'date' ? AppTheme.accent : Colors.white)),
                ]),
              ),
              PopupMenuItem(
                value: 'title',
                child: Row(children: [
                  Icon(Icons.sort_by_alpha_rounded, size: 14, color: _sortBy == 'title' ? AppTheme.accent : Colors.white70),
                  const SizedBox(width: 8),
                  Text('Sort by Title', style: TextStyle(color: _sortBy == 'title' ? AppTheme.accent : Colors.white)),
                ]),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: Colors.white,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.movie_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('Movies (${_upcomingMovies.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tv_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('Series (${_upcomingSeries.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(_getSortedMovies()),
          _buildList(_getSortedSeries()),
        ],
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildUpcomingCard(context, item);
      },
    );
  }

  Widget _buildUpcomingCard(BuildContext context, Map<String, dynamic> item) {
    final title = item['title'] ?? item['name'] ?? 'Untitled';
    final releaseDate = item['release_date'] as String? ?? '';
    final overview = item['overview'] as String? ?? '';
    final posterPath = item['poster_path'] as String? ?? '';
    final genres = (item['genres'] as List?)?.cast<String>() ?? [];
    final mediaType = item['media_type'] as String? ?? 'movie';
    final countdown = _getCountdown(releaseDate);
    final countdownColor = _getCountdownColor(releaseDate);
    final formattedDate = _formatDate(releaseDate);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetailsScreen(id: item['id'], mediaType: mediaType),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Backdrop
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  Image.network(
                    posterPath.startsWith('http')
                        ? posterPath.replaceFirst('?w=500', '?w=1000')
                        : 'https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=1000',
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 180,
                      color: AppTheme.background,
                      child: const Icon(Icons.movie, color: Colors.white24, size: 48),
                    ),
                  ),
                  // Gradient overlay
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.black87],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  // Countdown badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: countdownColor.withAlpha(100)),
                      ),
                      child: Text(
                        countdown,
                        style: TextStyle(color: countdownColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  // Type badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: mediaType == 'tv' ? Colors.blueAccent.withAlpha(180) : Colors.purpleAccent.withAlpha(180),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        mediaType == 'tv' ? '📺 SERIES' : '🎬 MOVIE',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  // Date at bottom
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, color: Colors.white70, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          formattedDate,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    overview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (genres.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: genres.map((g) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(g, style: const TextStyle(color: Colors.white60, fontSize: 10)),
                      )).toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
