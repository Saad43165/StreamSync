import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'watchlist_screen.dart';
import 'downloads_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final dbService = Provider.of<DatabaseService>(context);

    Color themeColor = Colors.purpleAccent;
    if (dbService.currentProfile == 'Family') themeColor = Colors.blueAccent;
    if (dbService.currentProfile == 'Kids') themeColor = Colors.greenAccent;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Space', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.white70),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Sleek Active Profile Visual Card / Login display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.surface, const Color(0xFF16151B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: themeColor.withValues(alpha: 0.15)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: themeColor.withValues(alpha: 0.2),
                          child: CircleAvatar(
                            radius: 28,
                            backgroundColor: themeColor,
                            child: Text(
                              dbService.isLoggedIn 
                                  ? dbService.username.substring(0, 1).toUpperCase()
                                  : dbService.currentProfile.substring(0, 1),
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dbService.isLoggedIn ? dbService.username : dbService.currentProfile,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: dbService.isPremium 
                                      ? Colors.amber.withValues(alpha: 0.15) 
                                      : Colors.white10,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  dbService.isPremium ? '👑 PREMIUM PRO MEMBER' : 'FREE ACCOUNT',
                                  style: TextStyle(
                                    color: dbService.isPremium ? Colors.amberAccent : Colors.white60,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (dbService.isLoggedIn)
                          IconButton(
                            onPressed: () {
                              dbService.logout();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Logged out successfully.')),
                              );
                            },
                            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                            tooltip: 'Logout',
                          )
                        else
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const LoginScreen(showSkipButton: false)),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accent,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              minimumSize: Size.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Sign In', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('${dbService.watchlist.length}', 'Watchlist'),
                        _buildStatSeparator(),
                        _buildStatItem('${dbService.watchHistory.length}', 'Watched'),
                        _buildStatSeparator(),
                        _buildStatItem('${dbService.downloads.length}', 'Downloads'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 2. Profile switcher dashboard row
              const Text(
                'Profiles',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 0.8),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: dbService.profiles.map((profile) {
                  final isCurrent = dbService.currentProfile == profile;
                  Color profileColor = Colors.purpleAccent;
                  if (profile == 'Family') profileColor = Colors.blueAccent;
                  if (profile == 'Kids') profileColor = Colors.greenAccent;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        dbService.selectProfile(profile);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: profileColor,
                            content: Text('Switched workspace profile to $profile successfully.'),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isCurrent ? profileColor.withValues(alpha: 0.1) : AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent ? profileColor : Colors.white.withValues(alpha: 0.05),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: profileColor,
                              child: Text(
                                profile.substring(0, 1),
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              profile,
                              style: TextStyle(
                                color: isCurrent ? Colors.white : AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // 3. User Space Shortcut Items
              const Text(
                'My Shortcuts',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 0.8),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    _profileNavTile(
                      context: context,
                      icon: Icons.bookmark_rounded,
                      label: 'Watchlist Library',
                      subtitle: 'Manage saved movies and shows',
                      iconColor: AppTheme.accent,
                      targetScreen: const WatchlistScreen(),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(height: 1, color: Colors.white10),
                    ),
                    _profileNavTile(
                      context: context,
                      icon: Icons.download_for_offline_rounded,
                      label: 'Offline Downloads',
                      subtitle: 'Cached movies & series file storage',
                      iconColor: Colors.greenAccent,
                      targetScreen: const DownloadsScreen(),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(height: 1, color: Colors.white10),
                    ),
                    _profileNavTile(
                      context: context,
                      icon: Icons.history_rounded,
                      label: 'Watch History',
                      subtitle: 'Resume recently watched episodes',
                      iconColor: Colors.blueAccent,
                      targetScreen: const SettingsScreen(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 4. Premium Status Card
              _buildPremiumCard(context, dbService),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String val, String label) {
    return Column(
      children: [
        Text(
          val,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildStatSeparator() {
    return Container(
      width: 1,
      height: 24,
      color: Colors.white12,
    );
  }

  Widget _profileNavTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String subtitle,
    required Color iconColor,
    required Widget targetScreen,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => targetScreen),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumCard(BuildContext context, DatabaseService dbService) {
    final isPremium = dbService.isPremium;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPremium
              ? [const Color(0xFF132F20), const Color(0xFF0A1911)]
              : [const Color(0xFF33220E), const Color(0xFF1C1207)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPremium ? Colors.tealAccent.withValues(alpha: 0.2) : AppTheme.secondaryAccent.withValues(alpha: 0.25),
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Icon(
            isPremium ? Icons.verified_rounded : Icons.workspace_premium_rounded,
            color: isPremium ? Colors.tealAccent : AppTheme.secondaryAccent,
            size: 30,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPremium ? 'Premium Pro Active' : 'Upgrade to Premium',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  isPremium ? 'Lifetime license · Ad-free browsing' : 'Lifetime access for only \$1.99',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isPremium ? Colors.white12 : AppTheme.secondaryAccent,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              isPremium ? 'Manage' : 'Upgrade',
              style: TextStyle(
                color: isPremium ? Colors.white70 : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
