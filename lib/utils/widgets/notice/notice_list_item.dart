import 'package:flutter/material.dart';
import 'package:learining_portal/models/notice_board_model.dart';
import 'package:learining_portal/screens/notices/notice_detail.dart';
import 'package:learining_portal/utils/app_colors.dart';

class NoticeListItem extends StatelessWidget {
  const NoticeListItem({required this.notice, this.onReturnFromDetail});

  final NoticeBoardModel notice;
  final VoidCallback? onReturnFromDetail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAttachments = notice.attachment?.isNotEmpty ?? false;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      shadowColor: AppColors.primaryBlue.withOpacity(0.08),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NoticeDetailScreen(notice: notice),
            ),
          ).then((_) => onReturnFromDetail?.call());
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primaryBlue.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateBadge(context),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!notice.isRead) ...[
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (notice.isPinned) ...[
                          Icon(
                            Icons.push_pin_rounded,
                            size: 16,
                            color: AppColors.primaryBlue,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            notice.title,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (notice.message != null &&
                        notice.message!.isNotEmpty) ...[
                      () {
                        final preview = htmlToPlainTextForPreview(
                          notice.message!,
                        );
                        if (preview.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            preview,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }(),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: AppColors.textSecondary.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(notice.publishDate ?? notice.date),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                        if (hasAttachments) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.attach_file_rounded,
                            size: 14,
                            color: AppColors.accentTeal,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Attachment',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.accentTeal,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.accentTeal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateBadge(BuildContext context) {
    final theme = Theme.of(context);
    final date = notice.publishDate ?? notice.date;
    return Container(
      width: 48,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryBlue.withOpacity(0.12),
            AppColors.secondaryPurple.withOpacity(0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _getDay(date),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryBlue,
              fontSize: 18,
            ),
          ),
          Text(
            _getMonth(date),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.secondaryPurple,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getDay(DateTime? date) {
    if (date == null) return '—';
    return date.day.toString();
  }

  String _getMonth(DateTime? date) {
    if (date == null) return '';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[date.month - 1];
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
