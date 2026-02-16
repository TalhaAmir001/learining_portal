import 'package:flutter/material.dart';
import 'package:learining_portal/models/notice_board_model.dart';
import 'package:learining_portal/utils/app_colors.dart';

class MetaCard extends StatelessWidget {
  final NoticeBoardModel notice;

  const MetaCard({super.key, required this.notice});

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String _formatDateTimeReadable(DateTime? d) {
    if (d == null) return '—';
    final hour = d.hour;
    final minute = d.minute.toString().padLeft(2, '0');
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${_formatDateReadable(d)}, $hour12:$minute $amPm';
  }

  static String _formatDateReadable(DateTime? d) {
    if (d == null) return '—';
    return '${d.day} ${_monthNames[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPublishDate = notice.publishDate != null;
    final hasNoticeDate = notice.date != null;
    final hasAuthor = notice.createdBy != null && notice.createdBy!.isNotEmpty;
    final hasAnyDate = hasPublishDate || hasNoticeDate;

    if (!hasAnyDate && !hasAuthor) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryBlue.withOpacity(0.05),
            AppColors.secondaryPurple.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dates row: Publish date and Notice date
          if (hasAnyDate) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.calendar_today_rounded,
                    size: 18,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasPublishDate) ...[
                        Text(
                          'Publish date',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDateTimeReadable(notice.publishDate),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (hasPublishDate && hasNoticeDate)
                        const SizedBox(height: 10),
                      if (hasNoticeDate) ...[
                        Text(
                          'Notice date',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDateTimeReadable(notice.date),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (hasAnyDate && hasAuthor) const SizedBox(height: 14),
          // Author row
          if (hasAuthor)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 18,
                    color: AppColors.secondaryPurple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Author',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notice.createdBy!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
