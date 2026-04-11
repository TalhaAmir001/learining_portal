import 'package:flutter/material.dart';
import 'package:learining_portal/utils/app_colors.dart';

/// One-time dashboard intro focused on Notice Board and chat.
class FeatureGuideDialog extends StatelessWidget {
  const FeatureGuideDialog({
    super.key,
    required this.isSupportUserType,
  });

  final bool isSupportUserType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.waving_hand_rounded,
                    color: AppColors.primaryBlue,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Quick tour',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Skip'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Here are two places you will use most:',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            _FeatureRow(
              icon: Icons.campaign_rounded,
              iconBg: AppColors.secondaryPurple.withOpacity(0.15),
              iconColor: AppColors.secondaryPurple,
              title: 'Notice Board',
              body:
                  'School updates and announcements appear here. Tap View All to see the full list.',
            ),
            const SizedBox(height: 16),
            _FeatureRow(
              icon: isSupportUserType
                  ? Icons.chat_bubble_rounded
                  : Icons.inbox_rounded,
              iconBg: AppColors.accentTeal.withOpacity(0.15),
              iconColor: AppColors.accentTeal,
              title: isSupportUserType ? 'Live Chat' : 'Messages',
              body: isSupportUserType
                  ? 'Open Live Chat under Quick Actions to reach support in real time.'
                  : 'Use Messages under Quick Actions to read and send conversations.',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
