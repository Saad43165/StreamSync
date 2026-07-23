import 'package:flutter/material.dart';

class Shimmer extends StatefulWidget {
  final Widget child;
  final bool showShimmer;

  const Shimmer({
    super.key,
    required this.child,
    this.showShimmer = true,
  });

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController.unbounded(vsync: this)
      ..repeat(min: -0.5, max: 1.5, period: const Duration(milliseconds: 1000));
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showShimmer) return widget.child;

    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Color(0xFF2C323F),
                Color(0xFF434A59),
                Color(0xFF2C323F),
              ],
              stops: const [
                0.1,
                0.3,
                0.4,
              ],
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              transform: _SlidingGradientTransform(slidePercent: _shimmerController.value),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

// Preset skeletal layout shimmers
class ShimmerLoadingPresets {
  // A simple block skeleton
  static Widget skeletalBlock({
    required double width,
    required double height,
    double borderRadius = 8.0,
  }) {
    return Shimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  // A horizontal list of movie posters skeleton
  static Widget horizontalPostersSkeleton() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                skeletalBlock(width: 120, height: 160, borderRadius: 12),
                const SizedBox(height: 8),
                skeletalBlock(width: 90, height: 14),
              ],
            ),
          );
        },
      ),
    );
  }

  // Large hero item banner skeleton
  static Widget heroBannerSkeleton() {
    return Shimmer(
      child: Container(
        height: 400,
        width: double.infinity,
        color: Colors.white,
      ),
    );
  }

  // Grid list of search card skeletons
  static Widget searchGridSkeleton() {
    return GridView.builder(
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: skeletalBlock(width: double.infinity, height: double.infinity, borderRadius: 12),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: skeletalBlock(width: 100, height: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  // Single movie details header video shimmer placeholder
  static Widget detailHeaderSkeleton() {
    return Shimmer(
      child: Container(
        height: 220,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

// Individual image cover shimmer card
class ImageShimmerPlaceholder extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ImageShimmerPlaceholder({
    super.key,
    this.width = double.infinity,
    this.height = double.infinity,
    this.borderRadius = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}
