import 'package:flutter/material.dart';
import 'dart:math' as math;

class CurvedBanner extends StatelessWidget {
  final String imagePath;
  final double height;
  final double curveHeight;
  final Color backgroundColor;
  final Widget? fallbackWidget;

  const CurvedBanner({
    super.key,
    required this.imagePath,
    this.height = 0.25,
    this.curveHeight = 50,
    this.backgroundColor = Colors.white,
    this.fallbackWidget,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      height: size.height * height,
      child: Stack(
        children: [
          // Image with curved clip
          ClipPath(
            clipper: CurvedBottomClipper(curveHeight: curveHeight),
            child: Image.asset(
              imagePath,
              width: double.infinity,
              height: size.height * height,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return fallbackWidget ??
                    Container(
                      color: colorScheme.primaryContainer,
                      child: Center(
                        child: Icon(
                          Icons.school_outlined,
                          size: 80,
                          color: colorScheme.primary,
                        ),
                      ),
                    );
              },
            ),
          ),

          // Fade overlay at the bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: curveHeight * 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    backgroundColor.withOpacity(0.0),
                    backgroundColor.withOpacity(0.2),
                    backgroundColor.withOpacity(0.5),
                    backgroundColor,
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CurvedBottomClipper extends CustomClipper<Path> {
  final double curveHeight;

  CurvedBottomClipper({required this.curveHeight});

  @override
  Path getClip(Size size) {
    final path = Path();

    // Start from top left
    path.moveTo(0, 0);

    // Go to top right
    path.lineTo(size.width, 0);

    // Go to bottom right (above the curve)
    path.lineTo(size.width, size.height - curveHeight);

    // Create cosine curve along the bottom
    for (double x = size.width; x >= 0; x -= 1) {
      // Cosine wave: amplitude * (1 + cos(frequency * x))
      // This creates a curve above the baseline (like y = cos(x) above x-axis)
      final y =
          (curveHeight / 2) * (1 + math.cos((x / size.width) * 2 * math.pi)) +
          (size.height - curveHeight);
      path.lineTo(x, y);
    }

    // Close the path
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
