import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:streamsync/widgets/mini_player.dart';
import 'theme/app_theme.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'services/tmdb_service.dart';
import 'services/database_service.dart';
import 'services/download_service.dart';
import 'services/mini_player_service.dart';
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
        ChangeNotifierProvider(create: (_) => MiniPlayerService()),
        ChangeNotifierProxyProvider<DatabaseService, DownloadService>(
          create: (context) => DownloadService(dbService: Provider.of<DatabaseService>(context, listen: false)),
          update: (context, dbService, previous) => previous ?? DownloadService(dbService: dbService),
        ),
      ],
      child: const StreamVaultApp(),
    ),
  );
}

class StreamVaultApp extends StatelessWidget {
  const StreamVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StreamVault',
      theme: AppTheme.darkTheme,
      color: AppTheme.background,
      debugShowCheckedModeBanner: false,
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

  /// Switches the bottom-nav tab from anywhere inside the shell.
  static void selectTab(BuildContext context, int index) {
    context.findAncestorStateOfType<_MainNavigationShellState>()?._select(index);
  }

  /// Hides the floating dock, e.g. while a screen's drawer is open over it.
  static void setDockVisible(BuildContext context, bool visible) {
    context.findAncestorStateOfType<_MainNavigationShellState>()?._setDockVisible(visible);
  }

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const SearchScreen(),
    const WatchlistScreen(),
    const ProfileScreen(),
  ];

  bool _dockVisible = true;

  void _select(int index) {
    if (index != _currentIndex) setState(() => _currentIndex = index);
  }

  void _setDockVisible(bool visible) {
    if (visible != _dockVisible) setState(() => _dockVisible = visible);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Screens Stack
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),

          // Mini player - only shows when active, docked just above the nav dock
          Positioned(
            left: 12,
            right: 12,
            bottom: _NavDock.height + 16 + MediaQuery.paddingOf(context).bottom,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: const MiniPlayerWidget(),
            ),
          ),

          // Floating glass navigation dock
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedSlide(
              offset: Offset(0, _dockVisible ? 0 : 1.6),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: _NavDock(
                currentIndex: _currentIndex,
                onTap: _select,
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
class _NavDestination {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavDestination(this.icon, this.activeIcon, this.label);
}

/// Floating, blurred bottom navigation with an animated pill on the active tab.
class _NavDock extends StatelessWidget {
  static const double height = 64;

  static const _destinations = [
    _NavDestination(Icons.home_outlined, Icons.home_rounded, 'Home'),
    _NavDestination(Icons.search_rounded, Icons.search_rounded, 'Search'),
    _NavDestination(Icons.bookmark_outline_rounded, Icons.bookmark_rounded, 'Watchlist'),
    _NavDestination(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NavDock({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomInset),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg + 4),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg + 4),
              border: Border.all(color: AppTheme.stroke),
            ),
            child: Row(
              children: [
                for (var i = 0; i < _destinations.length; i++)
                  Expanded(
                    child: _NavDockItem(
                      destination: _destinations[i],
                      selected: i == currentIndex,
                      onTap: () => onTap(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavDockItem extends StatelessWidget {
  final _NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  const _NavDockItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.accent : AppTheme.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        highlightShape: BoxShape.rectangle,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              width: selected ? 52 : 36,
              height: 28,
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.accent.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                selected ? destination.activeIcon : destination.icon,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
              child: Text(destination.label, maxLines: 1),
            ),
          ],
        ),
      ),
    );
  }
}
