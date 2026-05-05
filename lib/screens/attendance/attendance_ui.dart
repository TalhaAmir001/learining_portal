import 'package:flutter/material.dart';
import 'package:learining_portal/utils/app_colors.dart';

/// Shared layout and controls for Attendance flows (matches Student Info / Share Content).
abstract final class AttendanceUi {
  static const double _cardRadius = 16;
  static const double _buttonRadius = 14;

  static Widget sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
      ),
    );
  }

  /// White bordered card used for filter blocks (same as multiclass / directory lists).
  static Widget filterCard({required Widget child}) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardRadius),
        side: BorderSide(
          color: AppColors.textSecondary.withOpacity(0.12),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  /// Primary commit actions (save) — same as upload / send email.
  static ButtonStyle primaryBlueButton() {
    return FilledButton.styleFrom(
      backgroundColor: AppColors.primaryBlue,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_buttonRadius),
      ),
    );
  }

  /// Load / fetch — same accent as multiclass “Load students”.
  static ButtonStyle accentTealButton() {
    return FilledButton.styleFrom(
      backgroundColor: AppColors.accentTeal,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_buttonRadius),
      ),
    );
  }

  /// Secondary filled (save-alt) — soft purple tint.
  static ButtonStyle softSaveButton() {
    return FilledButton.styleFrom(
      foregroundColor: AppColors.primaryBlue,
      backgroundColor: AppColors.secondaryPurple.withOpacity(0.14),
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_buttonRadius),
      ),
    );
  }

  static Widget datePickerButton({
    required BuildContext context,
    required VoidCallback onPressed,
    required String dateYmd,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.calendar_today_rounded, size: 18),
      label: Text('Session date · $dateYmd'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryBlue,
        side: BorderSide(
          color: AppColors.textSecondary.withOpacity(0.35),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_buttonRadius),
        ),
      ),
    );
  }

  static Widget entryCard({
    required BuildContext context,
    required IconData leadingIcon,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardRadius),
        side: BorderSide(
          color: AppColors.textSecondary.withOpacity(0.12),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accentTeal.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                leadingIcon,
                color: AppColors.primaryBlue,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  static Widget inlineHint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
      ),
    );
  }
}
