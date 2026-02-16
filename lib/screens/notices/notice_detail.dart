import 'package:flutter/material.dart';
import 'package:learining_portal/models/notice_board_model.dart';
import 'package:learining_portal/providers/send_notifications_provider.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:learining_portal/utils/widgets/notice/message_card.dart';
import 'package:learining_portal/utils/widgets/notice/meta_card.dart';
import 'package:learining_portal/utils/widgets/notice/notice_app_bar.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Converts HTML to plain text for list/preview display (strips tags, extracts link URLs, decodes entities).
/// Use this in notice_board_box and notice_board for message previews.
String htmlToPlainTextForPreview(String html) {
  if (html.isEmpty) return html;
  String text = html.replaceAll(RegExp(r'\r\n?'), '\n');

  // Extract <a href="url">content</a> and replace with the URL so it appears in preview
  text = text.replaceAllMapped(
    RegExp(
      '<a\\s[^>]*href=[\"\']([^\"\']+)[\"\'][^>]*>[\\s\\S]*?</a>',
      caseSensitive: false,
    ),
    (m) => m.group(1) ?? '',
  );

  // Block/line breaks → newlines
  text = text.replaceAll(RegExp(r'</p>\s*<p>', caseSensitive: false), '\n\n');
  text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'<p\s*[^>]*>', caseSensitive: false), '');

  // Strip all remaining tags
  text = text.replaceAll(RegExp(r'<[^>]*>'), ' ');

  // Decode common HTML entities
  text = text
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&mdash;', '—')
      .replaceAll('&ndash;', '–');

  // Collapse whitespace
  text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return text.trim();
}

class NoticeDetailScreen extends StatefulWidget {
  const NoticeDetailScreen({super.key, required this.notice});

  final NoticeBoardModel notice;

  @override
  State<NoticeDetailScreen> createState() => _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends State<NoticeDetailScreen> {
  bool _markReadDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markAsRead());
  }

  Future<void> _markAsRead() async {
    if (_markReadDone) return;
    _markReadDone = true;
    final provider = context.read<SendNotificationsProvider>();
    await provider.markAsRead(widget.notice.id);
  }

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

  /// Readable date only: e.g. "13 February 2025"
  static String _formatDateReadable(DateTime? d) {
    if (d == null) return '—';
    return '${d.day} ${_monthNames[d.month - 1]} ${d.year}';
  }

  /// Readable date and time: e.g. "13 February 2025, 2:30 PM"
  static String _formatDateTimeReadable(DateTime? d) {
    if (d == null) return '—';
    final hour = d.hour;
    final minute = d.minute.toString().padLeft(2, '0');
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${_formatDateReadable(d)}, $hour12:$minute $amPm';
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!uri.hasScheme) {
      final withScheme = Uri.parse('https://$url');
      if (await canLaunchUrl(withScheme)) {
        await launchUrl(withScheme, mode: LaunchMode.externalApplication);
      }
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notice = widget.notice;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryBlue,
              AppColors.secondaryPurple,
              AppColors.backgroundLight,
            ],
            stops: const [0.0, 0.35, 0.5],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NoticeAppBar(
                title: 'Notice',
                subtitle: 'View details',
                padding: const EdgeInsets.fromLTRB(4, 8, 12, 16),
                iconContainerShadow: true,
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  decoration: const BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 12,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTitleCard(theme, notice),
                          const SizedBox(height: 16),
                          MetaCard(notice: notice),
                          if (notice.message != null &&
                              notice.message!.trim().isNotEmpty) ...[
                            const SizedBox(height: 16),
                            MessageCard(
                              notice: notice,
                              onLinkTap: (url) {
                                // Handle URL tap
                                _openUrl(url);
                              },
                            ),
                          ],
                          if (notice.attachment != null &&
                              notice.attachment!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildAttachmentCard(theme, notice),
                          ],
                          if (notice.createdAt != null) ...[
                            const SizedBox(height: 24),
                            _buildPublishedFooter(theme, notice),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleCard(ThemeData theme, NoticeBoardModel notice) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppColors.secondaryPurple.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: AppColors.primaryBlue.withOpacity(0.06),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 48,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primaryBlue, AppColors.secondaryPurple],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (notice.isPinned) ...[
            Padding(
              padding: const EdgeInsets.only(right: 10, top: 2),
              child: Icon(
                Icons.push_pin_rounded,
                size: 20,
                color: AppColors.primaryBlue,
              ),
            ),
          ],
          Expanded(
            child: Text(
              notice.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                height: 1.35,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentCard(ThemeData theme, NoticeBoardModel notice) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openAttachment(notice.attachment!),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.accentTeal.withOpacity(0.08),
                AppColors.secondaryPurple.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accentTeal.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentTeal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.attach_file_rounded,
                  color: AppColors.accentTeal,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attachment',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notice.attachment!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 22,
                color: AppColors.accentTeal,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPublishedFooter(ThemeData theme, NoticeBoardModel notice) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.textSecondary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Created ${_formatDateTimeReadable(notice.createdAt)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary.withOpacity(0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Future<void> _openAttachment(String urlOrPath) async {
    final uri = Uri.tryParse(urlOrPath);
    if (uri == null) return;
    if (!uri.hasScheme) {
      final withScheme = Uri.parse('https://$urlOrPath');
      if (await canLaunchUrl(withScheme)) {
        await launchUrl(withScheme, mode: LaunchMode.externalApplication);
      }
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
