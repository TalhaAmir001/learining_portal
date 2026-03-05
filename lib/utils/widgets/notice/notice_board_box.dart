// lib/utils/widgets/notice_board_box.dart
import 'package:flutter/material.dart';
import 'package:learining_portal/models/notice_board_model.dart';
import 'package:learining_portal/providers/send_notifications_provider.dart';
import 'package:learining_portal/screens/notices/notice_detail.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:provider/provider.dart';

class NoticeBoardBox extends StatelessWidget {
  final List<NoticeBoardModel> notices;
  final bool isLoading;
  final VoidCallback? onViewAll;

  const NoticeBoardBox({
    super.key,
    required this.notices,
    required this.isLoading,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, AppColors.backgroundLight.withOpacity(0.8)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.secondaryPurple.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with gradient
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryBlue, AppColors.secondaryPurple],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.campaign,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Notice Board',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  if (notices.isNotEmpty)
                    TextButton(
                      onPressed: onViewAll ?? () {},
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withOpacity(0.15),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View All',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Notices List
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320, minHeight: 120),
              child: isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.accentTeal,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Loading notices...',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : notices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.mark_email_read_outlined,
                            size: 48,
                            color: AppColors.textSecondary.withOpacity(0.3),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No notices',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            'Check back later for updates',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      itemCount: notices.length > 5 ? 5 : notices.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 56),
                      itemBuilder: (context, index) {
                        final notice = notices[index];
                        final isVeryRecent = _isLessThan24HoursOld(notice);
                        return _buildNoticeItem(context, notice, isVeryRecent);
                      },
                    ),
            ),

            // Footer for more notices indicator
            if (notices.length > 5)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onViewAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: AppColors.textSecondary.withOpacity(0.1),
                        ),
                      ),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '+ ${notices.length - 5} more notices',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.accentTeal,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: AppColors.accentTeal,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeItem(
    BuildContext context,
    NoticeBoardModel notice,
    bool isVeryRecent,
  ) {
    final theme = Theme.of(context);
    final hasAttachments = notice.attachment?.isNotEmpty ?? false;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NoticeDetailScreen(notice: notice),
            ),
          ).then((_) {
            if (context.mounted) {
              final provider = context.read<SendNotificationsProvider>();
              provider.loadNotices();
              provider.loadUnreadNotices();
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date indicator with subtle new indicator
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primaryBlue.withOpacity(0.1),
                          AppColors.secondaryPurple.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isVeryRecent
                            ? Colors.red.withOpacity(0.5)
                            : AppColors.accentTeal.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _getDay(notice.publishDate ?? notice.date),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isVeryRecent
                                ? Colors.red.withOpacity(0.8)
                                : AppColors.accentTeal,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          _getMonth(notice.publishDate ?? notice.date),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isVeryRecent
                                ? Colors.red.withOpacity(0.6)
                                : AppColors.accentTeal.withOpacity(0.8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Minimalist new indicator - just a small dot
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        // color: isVeryRecent ? Colors.red : AppColors.accentTeal,
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (isVeryRecent
                                        ? Colors.red
                                        : AppColors.accentTeal)
                                    .withOpacity(0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (notice.isPinned) ...[
                          Icon(
                            Icons.push_pin_rounded,
                            size: 14,
                            color: AppColors.primaryBlue,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            notice.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    if (notice.message != null) ...[
                      () {
                        final preview = htmlToPlainTextForPreview(
                          notice.message!,
                        );
                        if (preview.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            preview,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }(),
                    ],

                    const SizedBox(height: 4),

                    // Date and attachments row
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: isVeryRecent
                              ? Colors.red.withOpacity(0.6)
                              : AppColors.textSecondary.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatRelativeTime(
                            notice.publishDate ?? notice.date,
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isVeryRecent
                                ? Colors.red.withOpacity(0.8)
                                : AppColors.textSecondary.withOpacity(0.8),
                            fontSize: 10,
                            fontWeight: isVeryRecent ? FontWeight.w600 : null,
                          ),
                        ),
                        if (hasAttachments) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.attach_file,
                            size: 12,
                            color: AppColors.accentTeal,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${notice.attachment?.length}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.accentTeal,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow indicator with subtle color
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isVeryRecent
                      ? Colors.red.withOpacity(0.1)
                      : AppColors.accentTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: isVeryRecent
                      ? Colors.red.withOpacity(0.7)
                      : AppColors.accentTeal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isLessThan24HoursOld(NoticeBoardModel notice) {
    final publishDate = notice.publishDate ?? notice.date;
    if (publishDate == null) return false;

    final difference = DateTime.now().difference(publishDate);
    return difference.inHours < 24;
  }

  String _formatRelativeTime(DateTime? date) {
    if (date == null) return '';

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return _formatDateShort(date);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _getDay(DateTime? date) {
    if (date == null) return '';
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

  String _formatDateShort(DateTime? date) {
    if (date == null) return '—';
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
