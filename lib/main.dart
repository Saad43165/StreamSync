import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'services/tmdb_service.dart';
import 'services/database_service.dart';
import 'services/download_service.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/watchlist_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/splash_screen.dart';
import 'widgets/floating_download_widget.dart';

import 'package:media_kit/media_kit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await FlutterDownloader.initialize(debug: false, ignoreSsl: false);
  await Hive.initFlutter();
  await Hive.openBox('tmdb_cache_box');
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TMDBService()),
        ChangeNotifierProvider(create: (_) => DatabaseService()),
        ChangeNotifierProxyProvider<DatabaseService, DownloadService>(
          create: (context) => DownloadService(dbService: Provider.of<DatabaseService>(context, listen: false)),
          update: (context, dbService, previous) => previous ?? DownloadService(dbService: dbService),
        ),
      ],
      child: const StreamSyncApp(),
    ),
  );
}

class StreamSyncApp extends StatelessWidget {
  const StreamSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StreamSync',
      theme: AppTheme.darkTheme,
      color: AppTheme.background, // Prevents white flash on app resume
      debugShowCheckedModeBanner: false,
      // Dark background shown during page transitions — eliminates white flash
      builder: (context, child) => Container(
        color: AppTheme.background,
        child: child!,
      ),
      home: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: const SplashScreen(),
      ),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  // Core screens of StreamSync App
  final List<Widget> _screens = [
    const HomeScreen(),
    const SearchScreen(),
    const WatchlistScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // transparent to show ambient gradient
      body: Stack(
        children: [
          // Screens Stack
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),

          // Floating Glassmorphic Bottom Navigation Dock
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: BottomNavigationBar(
                      currentIndex: _currentIndex,
                      onTap: (index) {
                        setState(() {
                          _currentIndex = index;
                        });
                      },
                      type: BottomNavigationBarType.fixed,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      selectedItemColor: AppTheme.accent,
                      unselectedItemColor: AppTheme.textSecondary,
                      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      unselectedLabelStyle: const TextStyle(fontSize: 11),
                      items: const [
                        BottomNavigationBarItem(
                          icon: Icon(Icons.home_outlined),
                          activeIcon: Icon(Icons.home),
                          label: 'Home',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.search),
                          activeIcon: Icon(Icons.search_rounded),
                          label: 'Search',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.bookmark_outline),
                          activeIcon: Icon(Icons.bookmark),
                          label: 'Watchlist',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.person_outline),
                          activeIcon: Icon(Icons.person),
                          label: 'Profile',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Floating background download manager
          const FloatingDownloadWidget(),
        ],
      ),
    );
  }
}