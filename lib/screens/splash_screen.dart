import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Setup Fade-in Animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _fadeController.forward();

    // Navigate to login or main shell after 2.8 seconds
    Future.delayed(const Duration(milliseconds: 2800), () async {
      if (!mounted) return;
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final prefs = await SharedPreferences.getInstance();
      final bool hasSeenOnboarding = prefs.getBool('streamsync_seen_onboarding') ?? false;

      if (!mounted) return;
      
      Widget nextScreen;
      if (dbService.isLoggedIn) {
        // Already logged in → go straight home
        nextScreen = const MainNavigationShell();
      } else if (!hasSeenOnboarding) {
        // First time ever → show login with skip option
        nextScreen = const LoginScreen(showSkipButton: true);
      } else {
        // Has seen onboarding before (either logged in or skipped) → go straight home
        nextScreen = const MainNavigationShell();
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Glowing Logo Container
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accent.withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/app_icon.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // App Name Text
                  const Text(
                    'CineSync',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Synchronized Media & Streaming Mirror Player',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 0.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Breathing minimal indicator
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: AppTheme.accent,
                      strokeWidth: 2.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Professional Attribution Footer
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'DEVELOPED BY',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 2.5,
                        color: Colors.white.withValues(alpha: 0.35),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'SAAD IKRAM',
                      style: TextStyle(
                        fontSize: 13,
                        letterSpacing: 1.5,
                        color: AppTheme.accent.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w800,
                        shadows: [
                          Shadow(
                            color: AppTheme.accent.withValues(alpha: 0.25),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
