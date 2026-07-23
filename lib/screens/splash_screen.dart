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
        // First time ever → show login with skip option, mark as seen
        await prefs.setBool('streamsync_seen_onboarding', true);
        nextScreen = const LoginScreen(showSkipButton: true);
      } else {
        // Has seen onboarding before but chose to skip → go straight home
        nextScreen = const MainNavigationShell();
      }

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
      body: Center(
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
                  border: Border.all(color: AppTheme.accent.withOpacity(0.4), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withOpacity(0.2),
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
                'StreamSync',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Unlimited Free Movies & TV Series',
                style: TextStyle(
                  fontSize: 13,
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
    );
  }
}
