import 'package:flutter/material.dart';

class SimpleBanner extends StatelessWidget {
  final String imagePath;
  final double height;
  final Widget? fallbackWidget;

  const SimpleBanner({
    super.key,
    required this.imagePath,
    this.height = 0.25,
    this.fallbackWidget,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      height: size.height * height,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
    );
  }
}
