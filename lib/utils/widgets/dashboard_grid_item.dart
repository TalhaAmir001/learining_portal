// lib/utils/widgets/dashboard_grid_item.dart
import 'package:flutter/material.dart';

class DashboardItem {
  final IconData icon;
  final String title;
  final Color color;
  final Gradient? gradient;
  final VoidCallback onTap;

  DashboardItem({
    required this.icon,
    required this.title,
    required this.color,
    this.gradient,
    required this.onTap,
  });
}

class DashboardGridItem extends StatelessWidget {
  final DashboardItem item;
  final int index;

  const DashboardGridItem({super.key, required this.item, this.index = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + (index * 100)),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: item.color.withOpacity(0.2),
          highlightColor: item.color.withOpacity(0.1),
          child: Container(
            decoration: BoxDecoration(
              gradient:
                  item.gradient ??
                  LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [item.color, item.color.withOpacity(0.7)],
                  ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: item.color.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Background pattern
                Positioned(
                  bottom: -10,
                  right: -10,
                  child: Icon(
                    item.icon,
                    size: 70,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(item.icon, color: Colors.white, size: 28),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 30,
                            height: 2,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ],
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
