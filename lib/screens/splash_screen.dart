import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'package:streamsync/main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _particleController;
  late AnimationController _fadeController;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _glowPulse;
  late Animation<double> _textSlide;
  late Animation<double> _textFade;
  late Animation<double> _exitFade;

  final List<_Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Generate particles
    for (int i = 0; i < 25; i++) {
      _particles.add(_Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 4 + 1,
        speed: _random.nextDouble() * 0.4 + 0.1,
        opacity: _random.nextDouble() * 0.6 + 0.2,
      ));
    }

    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _particleController = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut));
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)));
    _glowPulse = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _particleController, curve: Curves.easeInOut));
    _textSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.5, 1.0, curve: Curves.easeOut)));
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.5, 1.0, curve: Curves.easeIn)));
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(_fadeController);

    _logoController.forward();

    // Navigate after delay
    Future.delayed(const Duration(milliseconds: 2800), () async {
      if (mounted) {
        await _fadeController.forward();
        if (mounted) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const MainNavigationShell(),
              transitionDuration: const Duration(milliseconds: 400),
              transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _particleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return FadeTransition(
      opacity: _exitFade,
      child: Scaffold(
        backgroundColor: const Color(0xFF07070F),
        body: Stack(
          children: [
            // Gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.2),
                  radius: 1.2,
                  colors: [Color(0xFF1A1030), Color(0xFF07070F)],
                ),
              ),
            ),

            // Animated particles
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _ParticlePainter(_particles, _particleController.value),
                  size: size,
                );
              },
            ),

            // Center content
            Center(
              child: AnimatedBuilder(
                animation: _logoController,
                builder: (context, _) {
                  return FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Glow ring + icon
                          AnimatedBuilder(
                            animation: _particleController,
                            builder: (context, child) {
                              return Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accent.withValues(
                                        alpha: 0.4 * _glowPulse.value),
                                      blurRadius: 40 * _glowPulse.value,
                                      spreadRadius: 10 * _glowPulse.value,
                                    ),
                                  ],
                                ),
                                child: child,
                              );
                            },
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppTheme.accent.withValues(alpha: 0.9),
                                    const Color(0xFF3D5AFE),
                                  ],
                                ),
                              ),
                              child: const Icon(Icons.play_circle_filled_rounded,
                                color: Colors.white, size: 64),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // App name
                          Transform.translate(
                            offset: Offset(0, _textSlide.value),
                            child: FadeTransition(
                              opacity: _textFade,
                              child: Column(
                                children: [
                                  ShaderMask(
                                    shaderCallback: (bounds) => LinearGradient(
                                      colors: [Colors.white, AppTheme.accent.withValues(alpha: 0.9)],
                                    ).createShader(bounds),
                                    child: const Text(
                                      'CineSync',
                                      style: TextStyle(
                                        fontSize: 42,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'PREMIUM STREAMING',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.accent.withValues(alpha: 0.8),
                                      letterSpacing: 5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Attribution
            Positioned(
              bottom: 36,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _logoController,
                builder: (context, _) {
                  return FadeTransition(
                    opacity: _textFade,
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 1,
                          color: Colors.white24,
                          margin: const EdgeInsets.only(bottom: 8),
                        ),
                        const Text(
                          'DEVELOPED BY SAAD IKRAM',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Particle system ──────────────────────────────────────────────────────────

class _Particle {
  double x, y, size, speed, opacity;
  _Particle({required this.x, required this.y, required this.size,
    required this.speed, required this.opacity});
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlePainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = (p.y - progress * p.speed) % 1.0;
      final paint = Paint()
        ..color = const Color(0xFF6C63FF).withValues(alpha: p.opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(p.x * size.width, y * size.height),
        p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}
