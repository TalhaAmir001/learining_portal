import 'package:flutter/material.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/utils/app_colors.dart';

class WelcomeSection extends StatelessWidget {
  final AuthProvider authProvider;

  const WelcomeSection({super.key, required this.authProvider});

  String _getGreeting() {
    final timeOfDay = DateTime.now().hour;

    if (timeOfDay < 12) {
      return 'Good Morning';
    } else if (timeOfDay < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  String _getUserTypeDisplay() {
    final userType = authProvider.userType?.toString().split('.').last;
    return userType?.toUpperCase() ?? 'USER';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greeting = _getGreeting();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryBlue.withOpacity(0.8),
            AppColors.secondaryPurple,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  authProvider.userName ?? 'User',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getUserTypeDisplay(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }
}
