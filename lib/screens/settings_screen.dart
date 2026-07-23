import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import '../screens/login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dbService = Provider.of<DatabaseService>(context);
    final tmdbService = Provider.of<TMDBService>(context, listen: false);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ─── Account Section ───────────────────────────
            _sectionLabel('Account'),
            _settingsCard([
              if (dbService.isLoggedIn) ...[
                _infotile(
                  icon: Icons.person_rounded,
                  label: 'Signed in as',
                  trailing: Text('@${dbService.username}', style: const TextStyle(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
                _divider(),
                _infotile(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  trailing: Text(dbService.email, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ),
                _divider(),
                _actiontile(
                  icon: Icons.logout_rounded,
                  label: 'Sign Out',
                  color: Colors.redAccent,
                  onTap: () {
                    dbService.logout();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Signed out successfully.')),
                    );
                  },
                ),
              ] else ...[
                _actiontile(
                  icon: Icons.login_rounded,
                  label: 'Sign In / Create Account',
                  color: AppTheme.accent,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen(showSkipButton: false)),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Text(
                    'Sign in to sync your watch history and watchlist across devices.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ),
              ],
            ]),

            const SizedBox(height: 20),

            // ─── Profile Section ───────────────────────────
            _sectionLabel('Active Profile'),
            _settingsCard([
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Switched to $profile profile')),
                        );
                      },
                      child: AnimatedOpacity(
                        opacity: isCurrent ? 1.0 : 0.5,
                        duration: const Duration(milliseconds: 200),
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
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
                                backgroundColor: profileColor.withAlpha(60),
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
                            if (isCurrent)
                              Container(
                                margin: const EdgeInsets.only(top: 3),
                                width: 20,
                                height: 2,
                                decoration: BoxDecoration(
                                  color: profileColor,
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ]),

            const SizedBox(height: 20),

            // ─── Streaming Region ───────────────────────────
            _sectionLabel('Streaming Preferences'),
            _settingsCard([
              _actiontile(
                icon: Icons.language_rounded,
                label: 'Streaming Region',
                trailing: Text(
                  dbService.selectedCountry == 'US' ? '🇺🇸 United States' :
                  dbService.selectedCountry == 'IN' ? '🇮🇳 India' :
                  dbService.selectedCountry == 'GB' ? '🇬🇧 United Kingdom' :
                  dbService.selectedCountry == 'CA' ? '🇨🇦 Canada' : '🇦🇺 Australia',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                onTap: () => _showRegionPicker(context, dbService, tmdbService),
              ),
              _divider(),
              _infotile(
                icon: Icons.subtitles_outlined,
                label: 'Subtitles & Audio',
                trailing: const Text('Auto-detect', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ),
              _divider(),
              _infotile(
                icon: Icons.hd_rounded,
                label: 'Video Quality',
                trailing: const Text('Auto', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ),
            ]),

            const SizedBox(height: 20),

            // ─── Notifications ───────────────────────────
            _sectionLabel('Notifications'),
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
            ]),

            const SizedBox(height: 20),

            // ─── Premium Section ───────────────────────────
            _sectionLabel('Premium'),
            _premiumCard(context, dbService),

            const SizedBox(height: 20),

            // ─── Storage & Privacy ───────────────────────────
            _sectionLabel('Storage & Privacy'),
            _settingsCard([
              _actiontile(
                icon: Icons.delete_sweep_rounded,
                label: 'Clear Watch History',
                color: Colors.orangeAccent,
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppTheme.surface,
                      title: const Text('Clear History', style: TextStyle(color: Colors.white)),
                      content: const Text(
                        'This will delete your entire watch history for the current profile.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear', style: TextStyle(color: Colors.redAccent))),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    dbService.clearDatabase();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Watch history cleared.')));
                  }
                },
              ),
              _divider(),
              _actiontile(
                icon: Icons.playlist_remove_rounded,
                label: 'Reset Watchlist & Stats',
                color: Colors.redAccent,
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppTheme.surface,
                      title: const Text('Reset Everything', style: TextStyle(color: Colors.white)),
                      content: const Text(
                        'This will delete your watchlist, watch history, and all stats permanently.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset All', style: TextStyle(color: Colors.redAccent))),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    dbService.clearDatabase();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All data reset.')));
                  }
                },
              ),
            ]),

            const SizedBox(height: 20),

            // ─── About ───────────────────────────
            _sectionLabel('About'),
            _settingsCard([
              _infotile(
                icon: Icons.info_outline_rounded,
                label: 'App Version',
                trailing: const Text('1.2.0', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ),
              _divider(),
              _infotile(
                icon: Icons.movie_filter_rounded,
                label: 'App Name',
                trailing: const Text('StreamSync', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ),
              _divider(),
              _infotile(
                icon: Icons.copyright_rounded,
                label: 'Powered by',
                trailing: const Text('TMDB API', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ),
            ]),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _settingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(children: children),
    );
  }

  Widget _infotile({
    required IconData icon,
    required String label,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 18),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _actiontile({
    required IconData icon,
    required String label,
    Color color = Colors.white,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, color: color == Colors.white ? Colors.white54 : color, size: 18),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: color == Colors.white ? Colors.white : color, fontSize: 14),
              ),
            ),
            trailing ?? const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 18),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.accent,
            activeTrackColor: AppTheme.accent.withAlpha(60),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: Colors.white12),
    );
  }

  Widget _premiumCard(BuildContext context, DatabaseService dbService) {
    final isPremium = dbService.isPremium;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPremium
              ? [const Color(0xFF1a3a2a), const Color(0xFF0d1f16)]
              : [const Color(0xFF2a1a00), const Color(0xFF1a1000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPremium ? Colors.tealAccent.withAlpha(60) : AppTheme.secondaryAccent.withAlpha(80),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPremium ? Icons.verified_rounded : Icons.workspace_premium_rounded,
                color: isPremium ? Colors.tealAccent : AppTheme.secondaryAccent,
                size: 28,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPremium ? 'Premium Pro Active' : 'StreamSync Premium',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    isPremium ? 'Lifetime license • Ad-free' : 'Lifetime access for \$1.99',
                    style: TextStyle(
                      color: isPremium ? Colors.tealAccent.withAlpha(200) : AppTheme.secondaryAccent.withAlpha(200),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (!isPremium) ...[
            const SizedBox(height: 16),
            const Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _BenefitChip('No Ads'),
                _BenefitChip('All Regions'),
                _BenefitChip('Sync History'),
                _BenefitChip('Priority Support'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showCheckoutSheet(context, dbService),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Upgrade Now — \$1.99 Lifetime',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                dbService.togglePremium();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reverted to free plan.')));
              },
              child: const Text('Restore Free Plan', style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  void _showCheckoutSheet(BuildContext context, DatabaseService dbService) {
    bool isProcessing = false;
    bool isSuccess = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              top: 20, left: 20, right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                if (!isProcessing && !isSuccess) ...[
                  const Text('Upgrade to Premium Pro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),
                  const Text('Lifetime ad-free access, region unlock, and cross-device sync.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white.withAlpha(8), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
                    child: const Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('StreamSync Premium (Lifetime)', style: TextStyle(color: Colors.white, fontSize: 13)),
                        Text('\$1.99', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 13)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setModalState(() => isProcessing = true);
                        Future.delayed(const Duration(seconds: 2), () {
                          setModalState(() { isProcessing = false; isSuccess = true; });
                          dbService.togglePremium();
                        });
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryAccent, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Pay via Google Play', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ] else if (isProcessing) ...[
                  const SizedBox(height: 32),
                  const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.accent)),
                  const SizedBox(height: 16),
                  const Text('Processing Payment...', style: TextStyle(color: Colors.white, fontSize: 14)),
                  const SizedBox(height: 32),
                ] else ...[
                  const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 64),
                  const SizedBox(height: 12),
                  const Text('Payment Successful! 🎉', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),
                  const Text('Welcome to StreamSync Premium Pro. Ads removed.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 20),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done', style: TextStyle(color: AppTheme.accent))),
                ],
              ],
            ),
          );
        });
      },
    );
  }

  void _showRegionPicker(BuildContext context, DatabaseService dbService, TMDBService tmdbService) {
    final Map<String, Map<String, String>> regions = {
      'US': {'name': 'United States', 'flag': '🇺🇸'},
      'IN': {'name': 'India', 'flag': '🇮🇳'},
      'GB': {'name': 'United Kingdom', 'flag': '🇬🇧'},
      'CA': {'name': 'Canada', 'flag': '🇨🇦'},
      'AU': {'name': 'Australia', 'flag': '🇦🇺'},
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Select Streaming Region', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ...regions.entries.map((entry) {
                final isSelected = dbService.selectedCountry == entry.key;
                return ListTile(
                  leading: Text(entry.value['flag']!, style: const TextStyle(fontSize: 22)),
                  title: Text(entry.value['name']!, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppTheme.accent) : null,
                  onTap: () {
                    dbService.updateCountry(entry.key);
                    tmdbService.fetchTrending();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Region updated to ${entry.value['name']}')),
                    );
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _BenefitChip extends StatelessWidget {
  final String label;
  const _BenefitChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.secondaryAccent.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.secondaryAccent.withAlpha(60)),
      ),
      child: Text(
        '✓ $label',
        style: const TextStyle(color: AppTheme.secondaryAccent, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
