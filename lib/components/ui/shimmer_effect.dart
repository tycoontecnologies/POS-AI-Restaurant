import 'package:flutter/material.dart';

class ShimmerEffect extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const ShimmerEffect({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              colors: [
                Colors.grey.shade300,
                Colors.grey.shade100,
                Colors.grey.shade300,
              ],
              stops: const [0.1, 0.3, 0.4],
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              tileMode: TileMode.clamp,
              transform: _SlidingGradientTransform(
                slidePercent: _controller.value,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

class ShimmerGrid extends StatelessWidget {
  final int crossAxisCount;
  final int itemCount;
  final double itemHeight;
  final double spacing;

  const ShimmerGrid({
    super.key,
    this.crossAxisCount = 3,
    this.itemCount = 6,
    this.itemHeight = 180,
    this.spacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: 1.6,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerEffect(
                width: double.infinity,
                height: 20,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              ShimmerEffect(
                width: 100,
                height: 14,
                borderRadius: BorderRadius.circular(4),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerEffect(
                        width: 60,
                        height: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 4),
                      ShimmerEffect(
                        width: 40,
                        height: 20,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                  ShimmerEffect(
                    width: 80,
                    height: 24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ShimmerEffect(
                width: double.infinity,
                height: 40,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ShimmerCategoryGrid extends StatelessWidget {
  final int crossAxisCount;
  final int itemCount;

  const ShimmerCategoryGrid({
    super.key,
    this.crossAxisCount = 4,
    this.itemCount = 8,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShimmerEffect(
                width: 40,
                height: 40,
                borderRadius: BorderRadius.circular(20),
              ),
              const SizedBox(height: 12),
              ShimmerEffect(
                width: 120,
                height: 16,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              ShimmerEffect(
                width: 80,
                height: 12,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        );
      },
    );
  }
}
