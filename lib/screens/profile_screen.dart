import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Simulates the premium checkout purchase process
  void _showSimulatedCheckout(BuildContext context, DatabaseService dbService) {
    bool isProcessing = false;
    bool isSuccess = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!isProcessing && !isSuccess) ...[
                    const Text(
                      'Upgrade to Premium Pro',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Get lifetime access to ad-free viewing, premium stats tracking, and custom region synchronization.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Product:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                              Text('StreamSync Pro (Lifetime)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Price:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                              Text('\$1.99 USD', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        setModalState(() {
                          isProcessing = true;
                        });
                        // Simulate network call
                        Future.delayed(const Duration(seconds: 2), () {
                          setModalState(() {
                            isProcessing = false;
                            isSuccess = true;
                          });
                          dbService.togglePremium(); // Unlock premium
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Pay \$1.99 via Google Play',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ] else if (isProcessing) ...[
                    const SizedBox(height: 40),
                    const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Processing Transaction...',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 40),
                  ] else if (isSuccess) ...[
                    const SizedBox(height: 20),
                    const Center(
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        color: Colors.greenAccent,
                        size: 64,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Payment Successful! 🎉',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You are now upgraded to StreamSync Premium Pro. All ads have been removed.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white12,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Back to Profile', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dbService = Provider.of<DatabaseService>(context);
    final tmdbService = Provider.of<TMDBService>(context, listen: false);

    Color themeColor = Colors.purpleAccent;
    if (dbService.currentProfile == 'Family') themeColor = Colors.blueAccent;
    if (dbService.currentProfile == 'Kids') themeColor = Colors.greenAccent;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Profiles & Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Sleek Active Profile Visual Card / Login display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: themeColor.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: themeColor,
                      child: Text(
                        dbService.isLoggedIn 
                            ? dbService.username.substring(0, 1).toUpperCase()
                            : dbService.currentProfile.substring(0, 1),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
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
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dbService.isLoggedIn ? dbService.email : (dbService.isPremium ? '💎 Premium Pro Active' : 'Free Watcher'),
                            style: TextStyle(
                              color: dbService.isPremium ? AppTheme.accent : AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (dbService.isLoggedIn)
                      TextButton.icon(
                        onPressed: () {
                          dbService.logout();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Logged out successfully.')),
                          );
                        },
                        icon: const Icon(Icons.logout_rounded, color: Colors.white54, size: 16),
                        label: const Text('Logout', style: TextStyle(color: Colors.white54, fontSize: 12)),
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
                        child: const Text('Login / Sign Up', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 2. Compact Profile Switcher List
              const Text(
                'Switch Profile',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.04)),
                ),
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
                          SnackBar(content: Text('Switched profile to $profile')),
                        );
                      },
                      child: Opacity(
                        opacity: isCurrent ? 1.0 : 0.6,
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: profileColor,
                              child: Text(
                                profile.substring(0, 1),
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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

              const SizedBox(height: 24),

              // 3. Quick Actions → Settings
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SettingsScreen()),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      _profileQuickTile(
                        icon: Icons.settings_rounded,
                        label: 'Settings',
                        subtitle: 'Region, notifications, privacy',
                        iconColor: Colors.white60,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Divider(height: 1, color: Colors.white12),
                      ),
                      _profileQuickTile(
                        icon: Icons.language_rounded,
                        label: 'Streaming Region',
                        subtitle: dbService.selectedCountry == 'US' ? '🇺🇸 United States' :
                                  dbService.selectedCountry == 'IN' ? '🇮🇳 India' :
                                  dbService.selectedCountry == 'GB' ? '🇬🇧 United Kingdom' :
                                  dbService.selectedCountry == 'CA' ? '🇨🇦 Canada' : '🇦🇺 Australia',
                        iconColor: Colors.blueAccent,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Divider(height: 1, color: Colors.white12),
                      ),
                      _profileQuickTile(
                        icon: Icons.history_rounded,
                        label: 'Watch History',
                        subtitle: '${dbService.watchHistory.length} titles watched',
                        iconColor: Colors.lightBlueAccent,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 4. Premium Status Card
              _buildPremiumCard(context, dbService),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileQuickTile({
    required IconData icon,
    required String label,
    required String subtitle,
    Color iconColor = Colors.white70,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 16),
        ],
      ),
    );
  }

  Widget _buildPremiumCard(BuildContext context, DatabaseService dbService) {
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
                const SizedBox(height: 3),
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
                MaterialPageRoute(builder: (_) => SettingsScreen()),
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
