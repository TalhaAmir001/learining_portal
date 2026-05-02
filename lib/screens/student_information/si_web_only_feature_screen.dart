import 'package:flutter/material.dart';
import 'package:learining_portal/utils/app_colors.dart';

class SiWebOnlyFeatureScreen extends StatelessWidget {
  const SiWebOnlyFeatureScreen({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          body,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textPrimary,
                height: 1.45,
              ),
        ),
      ),
    );
  }
}
