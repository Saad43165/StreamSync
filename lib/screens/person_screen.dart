import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import 'details_screen.dart';

class PersonScreen extends StatefulWidget {
  final int personId;
  final String name;

  const PersonScreen({
    super.key,
    required this.personId,
    required this.name,
  });

  @override
  State<PersonScreen> createState() => _PersonScreenState();
}

class _PersonScreenState extends State<PersonScreen> {
  Map<String, dynamic>? _person;
  bool _isLoading = true;
  bool _bioExpanded = false;

  static const _bg = Color(0xFF080810);
  static const _card = Color(0xFF14142A);
  static const _dimText = Color(0xFF8888AA);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tmdb = Provider.of<TMDBService>(context, listen: false);
    final data = await tmdb.fetchPerson(widget.personId);
    if (!mounted) return;
    setState(() {
      _person = data;
      _isLoading = false;
    });
  }

  static String _imgUrl(String? path, {String size = 'w342'}) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return 'https://image.tmdb.org/t/p/$size$path';
  }

  static String _posterUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return 'https://image.tmdb.org/t/p/w300$path';
  }

  static String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return 'Unknown';
    final parts = raw.split('-');
    if (parts.length < 3) return raw;
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final m = int.tryParse(parts[1]);
    return '${m != null ? months[m - 1] : parts[1]} ${parts[2]}, ${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(color: Colors.black.withValues(alpha: 0.4)),
          ),
        ),
      ),
      body: _isLoading
          ? _buildSkeleton()
          : _person == null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_off_rounded, color: Colors.white24, size: 48),
          const SizedBox(height: 12),
          const Text('Could not load person info.',
              style: TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () { setState(() => _isLoading = true); _load(); },
            icon: const Icon(Icons.refresh, color: AppTheme.accent),
            label: const Text('Retry', style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 60),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 110, height: 160, decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14))),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(height: 20, color: _card),
              const SizedBox(height: 10),
              Container(height: 14, width: 160, color: _card),
              const SizedBox(height: 8),
              Container(height: 14, width: 120, color: _card),
            ])),
          ]),
          const SizedBox(height: 24),
          Container(height: 16, width: 120, color: _card),
          const SizedBox(height: 12),
          Container(height: 13, color: _card),
          const SizedBox(height: 6),
          Container(height: 13, color: _card),
          const SizedBox(height: 6),
          Container(height: 13, width: 200, color: _card),
        ]),
      ),
    );
  }

  Widget _buildContent() {
    final p = _person!;
    final profileUrl = _imgUrl(p['profile_path'] as String?);
    final bio = (p['biography'] as String? ?? '').trim();
    final birthday = _fmtDate(p['birthday'] as String?);
    final birthplace = p['place_of_birth'] as String? ?? '';
    final department = p['known_for_department'] as String? ?? '';

    final credits = (p['combined_credits'] as Map?)?.cast<String, dynamic>() ?? {};
    final cast = (credits['cast'] as List? ?? []).cast<Map<String, dynamic>>();

    // Top 10 by popularity for "Known For"
    final knownFor = [...cast]
      ..sort((a, b) => ((b['popularity'] as num?) ?? 0).compareTo((a['popularity'] as num?) ?? 0));
    final topCredits = knownFor.take(10).toList();

    // Full filmography sorted descending by year
    final filmography = [...cast]..sort((a, b) {
      final da = (a['release_date'] ?? a['first_air_date'] ?? '') as String;
      final db = (b['release_date'] ?? b['first_air_date'] ?? '') as String;
      return db.compareTo(da);
    });

    // Group filmography by year
    final Map<String, List<Map<String, dynamic>>> byYear = {};
    for (final item in filmography) {
      final date = (item['release_date'] ?? item['first_air_date'] ?? '') as String;
      final year = date.isNotEmpty ? date.split('-').first : 'Unknown';
      byYear.putIfAbsent(year, () => []).add(item);
    }
    final sortedYears = byYear.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Profile photo
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: profileUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: profileUrl,
                          width: 110,
                          height: 160,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(width: 110, height: 160, color: _card),
                          errorWidget: (_, __, ___) => Container(
                            width: 110, height: 160, color: _card,
                            child: const Icon(Icons.person_rounded, color: Colors.white24, size: 40),
                          ),
                        )
                      : Container(width: 110, height: 160, color: _card,
                          child: const Icon(Icons.person_rounded, color: Colors.white24, size: 40)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(p['name'] as String? ?? widget.name,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.2)),
                    if (department.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                        ),
                        child: Text(department, style: const TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (birthday.isNotEmpty) ...[
                      _infoRow(Icons.cake_rounded, birthday),
                      const SizedBox(height: 5),
                    ],
                    if (birthplace.isNotEmpty)
                      _infoRow(Icons.location_on_rounded, birthplace),
                  ]),
                ),
              ]),
            ),
          ),
        ),

        // Biography
        if (bio.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _SectionLabel('Biography'),
                const SizedBox(height: 10),
                Text(
                  bio,
                  maxLines: _bioExpanded ? null : 3,
                  overflow: _bioExpanded ? null : TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xAAFFFFFF), fontSize: 13.5, height: 1.6),
                ),
                if (bio.length > 200)
                  GestureDetector(
                    onTap: () => setState(() => _bioExpanded = !_bioExpanded),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(_bioExpanded ? 'Show less' : 'Read more',
                          style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ]),
            ),
          ),

        // Known For
        if (topCredits.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: const _SectionLabel('Known For'),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 210,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemExtent: 132,
                itemCount: topCredits.length,
                itemBuilder: (_, i) {
                  final item = topCredits[i];
                  final title = (item['title'] ?? item['name'] ?? 'Untitled') as String;
                  final mediaType = (item['media_type'] as String?) ?? 'movie';
                  final poster = _posterUrl(item['poster_path'] as String?);
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => DetailsScreen(id: item['id'] as int, mediaType: mediaType))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: poster.isNotEmpty
                                ? CachedNetworkImage(imageUrl: poster, fit: BoxFit.cover,
                                    width: double.infinity,
                                    placeholder: (_, __) => Container(color: _card),
                                    errorWidget: (_, __, ___) => Container(color: _card,
                                        child: const Icon(Icons.movie_rounded, color: Colors.white24, size: 28)))
                                : Container(color: _card, child: const Icon(Icons.movie_rounded, color: Colors.white24, size: 28)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w500, height: 1.3)),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),
        ],

        // Filmography
        if (filmography.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: const _SectionLabel('Filmography'),
            ),
          ),
          for (final year in sortedYears)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 6),
                    child: Text(year,
                        style: TextStyle(
                            color: AppTheme.accent.withValues(alpha: 0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ),
                  ...byYear[year]!.map((item) {
                    final title = (item['title'] ?? item['name'] ?? 'Untitled') as String;
                    final mediaType = (item['media_type'] as String?) ?? 'movie';
                    final character = (item['character'] as String? ?? '').trim();
                    return InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => DetailsScreen(id: item['id'] as int, mediaType: mediaType))),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(children: [
                          Container(
                            width: 4, height: 4,
                            decoration: BoxDecoration(color: _dimText, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                              Text(title,
                                  style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w500)),
                              if (character.isNotEmpty)
                                Text('as $character',
                                    style: const TextStyle(color: Color(0xFF8888AA), fontSize: 11.5)),
                            ]),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(mediaType == 'tv' ? 'TV' : 'Film',
                                style: const TextStyle(color: Color(0xFF8888AA), fontSize: 10)),
                          ),
                        ]),
                      ),
                    );
                  }),
                ]),
              ),
            ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(children: [
      Icon(icon, color: _dimText, size: 14),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: const TextStyle(color: Color(0xFF8888AA), fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis)),
    ]);
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 3, height: 16, decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
    ]);
  }
}
