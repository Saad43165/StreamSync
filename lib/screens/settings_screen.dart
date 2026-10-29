import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/database_service.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _downloadsSize = "0.0 MB";
  String _cacheSize = "0.0 KB";
  bool _isLoadingMetrics = true;
  bool _isMounted = true;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }

  bool get _safeMounted => _isMounted && mounted;

  Future<void> _loadMetrics() async {
    if (!_safeMounted) return;
    setState(() => _isLoadingMetrics = true);

    try {
      final docDir = await getApplicationDocumentsDirectory();
      int downloadsBytes = 0;
      int cacheBytes = 0;

      // Scan directories that DownloadService uses: StreamVault/ subfolder
      // (also covers Android external storage path)
      final List<Directory> dirsToScan = [docDir];
      if (Platform.isAndroid) {
        try {
          final ext = await getExternalStorageDirectory();
          if (ext != null) dirsToScan.add(ext);
        } catch (_) {}
      }

      for (final dir in dirsToScan) {
        if (!await dir.exists()) continue;
        await for (final file in dir.list(recursive: true, followLinks: false)) {
          if (!_safeMounted) return;
          if (file is File) {
            try {
              final path = file.path;
              final length = await file.length();
              if (path.endsWith('.mp4') || path.endsWith('.mkv')) {
                downloadsBytes += length;
              } else if (path.endsWith('.hive') || path.endsWith('.hive.lock') || path.contains('tmdb_cache_box')) {
                cacheBytes += length;
              }
            } catch (_) {}
          }
        }
      }

      if (!_safeMounted) return;
      setState(() {
        _downloadsSize = _formatBytes(downloadsBytes);
        _cacheSize = _formatBytesSmall(cacheBytes);
        _isLoadingMetrics = false;
      });
    } catch (e) {
      debugPrint('Error loading file storage metrics: $e');
      if (_safeMounted) setState(() => _isLoadingMetrics = false);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatBytesSmall(int bytes) {
    if (bytes < 1024) return '$bytes B';
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }

  Future<void> _clearCache(BuildContext context, TMDBService tmdbService) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear TMDB Cache', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'This will wipe out $_cacheSize of cached pages and offline lists, forcing the app to fetch real-time fresh API data.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Wipe Cache', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final cacheBox = Hive.box('tmdb_cache_box');
      await cacheBox.clear();
      await tmdbService.fetchTrending();
      await _loadMetrics();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('TMDB category cache cleared successfully.')),
        );
      }
    } catch (e) {
      debugPrint('Failed to clear hive box: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not clear cache — please try again.')),
        );
      }
    }
  }

  Future<void> _purgeAllDownloads(BuildContext context, DatabaseService dbService) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete All Downloads', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text(
          'This will permanently delete all $_downloadsSize of offline video files from your local device storage.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final list = List.from(dbService.downloads);
    for (final item in list) {
      await dbService.removeDownload(item['id'] as int,
          mediaType: item['media_type'] as String?);
      if (!_safeMounted) return;
    }
    await _loadMetrics();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All offline storage files purged.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dbService = Provider.of<DatabaseService>(context);
    final tmdbService = Provider.of<TMDBService>(context, listen: false);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Settings & Storage',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        color: AppTheme.accent,
        backgroundColor: AppTheme.surface,
        onRefresh: _loadMetrics,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('Device & App Statistics'),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.6,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _statCard(
                    title: 'Offline Files',
                    value: _isLoadingMetrics ? "..." : _downloadsSize,
                    subtitle: '${dbService.downloads.length} items saved',
                    icon: Icons.download_done_rounded,
                    iconColor: AppTheme.accent,
                  ),
                  _statCard(
                    title: 'TMDB Cache Box',
                    value: _isLoadingMetrics ? "..." : _cacheSize,
                    subtitle: 'Local API Store',
                    icon: Icons.storage_rounded,
                    iconColor: AppTheme.secondaryAccent,
                  ),
                  _statCard(
                    title: 'Watch Duration',
                    value: '${dbService.totalHoursWatched} Hours',
                    subtitle: 'Recorded playback',
                    icon: Icons.hourglass_empty_rounded,
                    iconColor: Colors.blueAccent,
                  ),
                  _statCard(
                    title: 'Watchlist Storage',
                    value: '${dbService.watchlist.length} Titles',
                    subtitle: 'Saved for later',
                    icon: Icons.bookmark_added_rounded,
                    iconColor: Colors.pinkAccent,
                  ),
                ],
              ).animate().fade(duration: 400.ms, delay: 50.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),

              const SizedBox(height: 20),

              _sectionLabel('Active User Profile'),
              _settingsCard([
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: dbService.profiles.map((profile) {
                      final isCurrent = dbService.currentProfile == profile;
                      Color profileColor = Colors.purpleAccent;
                      if (profile == 'Family') profileColor = Colors.blueAccent;
                      if (profile == 'Kids') profileColor = Colors.greenAccent;

                      return GestureDetector(
                        onTap: () {
                          dbService.selectProfile(profile);
                          _loadMetrics();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Switched profile to: $profile')),
                          );
                        },
                        child: AnimatedOpacity(
                          opacity: isCurrent ? 1.0 : 0.5,
                          duration: const Duration(milliseconds: 250),
                          child: Column(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                padding: EdgeInsets.all(isCurrent ? 3 : 0),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isCurrent ? profileColor : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: profileColor.withValues(alpha: 0.25),
                                  child: Text(
                                    profile.substring(0, 1),
                                    style: TextStyle(color: profileColor, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                profile,
                                style: TextStyle(
                                  color: isCurrent ? Colors.white : AppTheme.textSecondary,
                                  fontSize: 11,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ]).animate().fade(duration: 450.ms, delay: 100.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),

              const SizedBox(height: 20),

              _sectionLabel('Streaming settings'),
              _settingsCard([
                _actiontile(
                  icon: Icons.subtitles_outlined,
                  label: 'Subtitles Multiplier',
                  trailing: Text(
                    dbService.captionSizeMultiplier == 0.8 ? 'Small (80%)' :
                    dbService.captionSizeMultiplier == 1.0 ? 'Medium (100%)' :
                    dbService.captionSizeMultiplier == 1.3 ? 'Large (130%)' : 'X-Large (160%)',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  onTap: () => _showSubtitleSettings(context, dbService),
                ),
                _divider(),
                _actiontile(
                  icon: Icons.hd_rounded,
                  label: 'Default Video Quality',
                  trailing: Text(dbService.defaultQuality, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  onTap: () => _showQualitySettings(context, dbService),
                ),
                _divider(),
                _actiontile(
                  icon: Icons.speed_rounded,
                  label: 'Playback Speed Rate',
                  trailing: Text('${dbService.playbackSpeed}x', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  onTap: () => _showSpeedSettings(context, dbService),
                ),
                _divider(),
                _switchTile(
                  icon: Icons.play_circle_outline_rounded,
                  label: 'Auto-play Next Episodes',
                  value: dbService.autoPlayNext,
                  onChanged: (v) => dbService.toggleAutoPlay(v),
                ),
              ]).animate().fade(duration: 500.ms, delay: 150.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),

              const SizedBox(height: 20),

              _sectionLabel('Notifications & Alerts'),
              _settingsCard([
                _switchTile(
                  icon: Icons.notifications_rounded,
                  label: 'New Release Alerts',
                  value: dbService.notifNewRelease,
                  onChanged: (v) => dbService.toggleNotifNewRelease(v),
                ),
                _divider(),
                _switchTile(
                  icon: Icons.local_activity_rounded,
                  label: 'Trending Content Alerts',
                  value: dbService.notifTrending,
                  onChanged: (v) => dbService.toggleNotifTrending(v),
                ),
              ]).animate().fade(duration: 550.ms, delay: 200.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),

              const SizedBox(height: 20),

              _sectionLabel('Storage Operations'),
              _settingsCard([
                _actiontile(
                  icon: Icons.delete_sweep_rounded,
                  label: 'Clear TMDB Cache Box',
                  color: AppTheme.accent,
                  onTap: () => _clearCache(context, tmdbService),
                ),
                _divider(),
                _actiontile(
                  icon: Icons.video_label_rounded,
                  label: 'Delete All Offline Downloads',
                  color: Colors.orangeAccent,
                  onTap: () => _purgeAllDownloads(context, dbService),
                ),
                _divider(),
                _actiontile(
                  icon: Icons.playlist_remove_rounded,
                  label: 'Reset Profile Watchlist & History',
                  color: Colors.redAccent,
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('Reset Everything', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        content: const Text(
                          'This will delete your watchlist, history list, and stats for this profile permanently. Local downloads remain untouched.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Reset All', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      dbService.clearDatabase();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Watch preferences and stats reset.')));
                    }
                  },
                ),
              ]).animate().fade(duration: 650.ms, delay: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),

              const SizedBox(height: 20),

              _sectionLabel('About StreamVault'),
              _settingsCard([
                _infotile(
                  icon: Icons.info_outline_rounded,
                  label: 'App Release Version',
                  trailing: const Text('3.0.0', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                _divider(),
                _infotile(
                  icon: Icons.movie_filter_rounded,
                  label: 'API Core Platform',
                  trailing: const Text('TMDB V3 Engine', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ),
                _divider(),
                _infotile(
                  icon: Icons.copyright_rounded,
                  label: 'Build Status',
                  trailing: const Text('Clean Sandbox', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ),
              ]).animate().fade(duration: 700.ms, delay: 350.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _settingsCard(List<Widget> children) {
    return GlassCard(
      borderRadius: 16,
      padding: EdgeInsets.zero,
      child: Column(children: children),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return GlassCard(
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(title, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 8), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infotile({required IconData icon, required String label, required Widget trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 18),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500))),
          trailing,
        ],
      ),
    );
  }

  Widget _actiontile({required IconData icon, required String label, Color color = Colors.white, Widget? trailing, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color == Colors.white ? Colors.white38 : color, size: 18),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: TextStyle(color: color == Colors.white ? Colors.white : color, fontSize: 13, fontWeight: color == Colors.white ? FontWeight.w500 : FontWeight.bold))),
            trailing ?? const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _switchTile({required IconData icon, required String label, required bool value, required ValueChanged<bool> onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 18),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500))),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 44, height: 24, padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: value ? AppTheme.accent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
                border: Border.all(color: value ? AppTheme.accent : Colors.white.withValues(alpha: 0.12), width: 1.0),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 17, height: 17,
                  decoration: BoxDecoration(
                    color: value ? AppTheme.accent : Colors.white54,
                    shape: BoxShape.circle,
                    boxShadow: value ? [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.5), blurRadius: 4)] : null,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider(height: 1, color: Colors.white10));
  }

  void _showSubtitleSettings(BuildContext context, DatabaseService dbService) {
    final sizes = [{'label': 'Small (80%)', 'value': 0.8}, {'label': 'Medium (100%)', 'value': 1.0}, {'label': 'Large (130%)', 'value': 1.3}, {'label': 'X-Large (160%)', 'value': 1.6}];
    showModalBottomSheet(
      context: context, backgroundColor: AppTheme.surface, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))), const SizedBox(height: 16),
        const Text('Subtitle Scale', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 12),
        ...sizes.map((size) {
          final isSelected = dbService.captionSizeMultiplier == size['value'];
          return ListTile(title: Text(size['label'] as String, style: const TextStyle(color: Colors.white, fontSize: 14)), trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppTheme.accent) : null, onTap: () { dbService.updateCaptionSize(size['value'] as double); Navigator.pop(context); });
        }),
      ])),
    );
  }

  void _showQualitySettings(BuildContext context, DatabaseService dbService) {
    final qualities = ['Auto', '1080p', '720p', '480p'];
    showModalBottomSheet(
      context: context, backgroundColor: AppTheme.surface, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))), const SizedBox(height: 16),
        const Text('Default Video Quality', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 12),
        ...qualities.map((q) {
          final isSelected = dbService.defaultQuality == q;
          return ListTile(title: Text(q, style: const TextStyle(color: Colors.white, fontSize: 14)), trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppTheme.accent) : null, onTap: () { dbService.updateQuality(q); Navigator.pop(context); });
        }),
      ])),
    );
  }

  void _showSpeedSettings(BuildContext context, DatabaseService dbService) {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    showModalBottomSheet(
      context: context, backgroundColor: AppTheme.surface, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))), const SizedBox(height: 16),
        const Text('Playback Speed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 12),
        ...speeds.map((s) {
          final isSelected = dbService.playbackSpeed == s;
          return ListTile(title: Text('${s}x', style: const TextStyle(color: Colors.white, fontSize: 14)), trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppTheme.accent) : null, onTap: () { dbService.updatePlaybackSpeed(s); Navigator.pop(context); });
        }),
      ])),
    );
  }
}

