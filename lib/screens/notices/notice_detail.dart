import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:learining_portal/models/notice_board_model.dart';
import 'package:learining_portal/providers/send_notifications_provider.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Normalizes HTML for the parser (e.g. line endings).
String _normalizeHtml(String html) {
  if (html.isEmpty) return html;
  return html.replaceAll(RegExp(r'\r\n?'), '\n').trim();
}

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

/// Builds style map for all HTML tags so they render accurately.
Map<String, Style> _buildHtmlStyles(ThemeData theme, TextStyle baseStyle) {
  const linkBlue = Color(0xFF1565C0);
  return {
    // Default / body
    "body": Style(
      color: AppColors.textPrimary,
      fontSize: FontSize(baseStyle.fontSize ?? 16),
      fontWeight: FontWeight.w400,
      lineHeight: LineHeight(1.6),
    ),
    // Paragraphs
    "p": Style(
      margin: Margins.only(bottom: 8),
      padding: HtmlPaddings.zero,
    ),
    // Links – blue, underlined, clickable via onLinkTap
    "a": Style(
      color: linkBlue,
      fontWeight: FontWeight.w600,
      textDecoration: TextDecoration.underline,
      textDecorationColor: linkBlue,
    ),
    // Bold
    "b": Style(fontWeight: FontWeight.bold),
    "strong": Style(fontWeight: FontWeight.bold),
    // Italic
    "i": Style(fontStyle: FontStyle.italic),
    "em": Style(fontStyle: FontStyle.italic),
    // Underline
    "u": Style(textDecoration: TextDecoration.underline),
    // Headings
    "h1": Style(
      fontSize: FontSize(24),
      fontWeight: FontWeight.bold,
      margin: Margins.only(top: 12, bottom: 8),
    ),
    "h2": Style(
      fontSize: FontSize(22),
      fontWeight: FontWeight.bold,
      margin: Margins.only(top: 10, bottom: 6),
    ),
    "h3": Style(
      fontSize: FontSize(20),
      fontWeight: FontWeight.bold,
      margin: Margins.only(top: 10, bottom: 6),
    ),
    "h4": Style(
      fontSize: FontSize(18),
      fontWeight: FontWeight.w600,
      margin: Margins.only(top: 8, bottom: 4),
    ),
    "h5": Style(
      fontSize: FontSize(16),
      fontWeight: FontWeight.w600,
      margin: Margins.only(top: 8, bottom: 4),
    ),
    "h6": Style(
      fontSize: FontSize(14),
      fontWeight: FontWeight.w600,
      margin: Margins.only(top: 6, bottom: 4),
    ),
    // Lists
    "ul": Style(
      margin: Margins.only(left: 16, top: 6, bottom: 6),
      padding: HtmlPaddings.only(left: 16),
    ),
    "ol": Style(
      margin: Margins.only(left: 16, top: 6, bottom: 6),
      padding: HtmlPaddings.only(left: 16),
    ),
    "li": Style(
      margin: Margins.only(bottom: 4),
      padding: HtmlPaddings.zero,
    ),
    // Block & inline
    "div": Style(
      margin: Margins.zero,
      padding: HtmlPaddings.zero,
    ),
    "span": Style(padding: HtmlPaddings.zero),
    // Blockquote
    "blockquote": Style(
      margin: Margins.symmetric(vertical: 8, horizontal: 0),
      padding: HtmlPaddings.only(left: 16, top: 8, bottom: 8),
      border: Border(
        left: BorderSide(
          color: AppColors.primaryBlue.withOpacity(0.5),
          width: 4,
        ),
      ),
      color: AppColors.textSecondary,
    ),
    // Code & pre
    "pre": Style(
      margin: Margins.only(top: 8, bottom: 8),
      padding: HtmlPaddings.all(12),
      backgroundColor: AppColors.textPrimary.withOpacity(0.06),
      whiteSpace: WhiteSpace.pre,
      fontFamily: 'monospace',
    ),
    "code": Style(
      fontFamily: 'monospace',
      fontSize: FontSize(13),
      backgroundColor: AppColors.textPrimary.withOpacity(0.06),
    ),
    // Horizontal rule
    "hr": Style(
      margin: Margins.symmetric(vertical: 12),
    ),
    // Subscript / superscript
    "sub": Style(
      fontSize: FontSize(12),
      verticalAlign: VerticalAlign.sub,
    ),
    "sup": Style(
      fontSize: FontSize(12),
      verticalAlign: VerticalAlign.sup,
    ),
    // Strikethrough / delete / insert
    "s": Style(textDecoration: TextDecoration.lineThrough),
    "strike": Style(textDecoration: TextDecoration.lineThrough),
    "del": Style(textDecoration: TextDecoration.lineThrough),
    "ins": Style(textDecoration: TextDecoration.underline),
    // Other inline
    "mark": Style(backgroundColor: const Color(0xFFFFEB3B)),
    "small": Style(fontSize: FontSize(12)),
    "abbr": Style(),
    "cite": Style(fontStyle: FontStyle.italic),
    "q": Style(fontStyle: FontStyle.italic),
    "dfn": Style(fontStyle: FontStyle.italic),
    "kbd": Style(
      fontFamily: 'monospace',
      backgroundColor: AppColors.textPrimary.withOpacity(0.08),
    ),
    "samp": Style(fontFamily: 'monospace'),
    "var": Style(fontStyle: FontStyle.italic),
    // Line break – handled by tag
    "br": Style(padding: HtmlPaddings.zero, margin: Margins.zero),
  };
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
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
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
              _buildAppBar(context),
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
                          _buildMetaCard(theme, notice),
                          if (notice.message != null &&
                              notice.message!.trim().isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildMessageCard(theme, notice),
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

  Widget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 16),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.maybePop(context),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.campaign_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Notice',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  'View details',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
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

  Widget _buildMetaCard(ThemeData theme, NoticeBoardModel notice) {
    final hasPublishDate = notice.publishDate != null;
    final hasNoticeDate = notice.date != null;
    final hasAuthor =
        notice.createdBy != null && notice.createdBy!.isNotEmpty;
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
        border: Border.all(
          color: AppColors.primaryBlue.withOpacity(0.08),
        ),
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
                      if (hasPublishDate && hasNoticeDate) const SizedBox(height: 10),
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

  Widget _buildMessageCard(ThemeData theme, NoticeBoardModel notice) {
    final raw = notice.message!.trim();
    if (raw.isEmpty) return const SizedBox.shrink();

    final htmlData = _normalizeHtml(raw);
    final baseStyle = theme.textTheme.bodyLarge ?? const TextStyle();
    final styles = _buildHtmlStyles(theme, baseStyle);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppColors.accentTeal.withOpacity(0.12),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentTeal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.description_rounded,
                  size: 20,
                  color: AppColors.accentTeal,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Message',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: AppColors.accentTeal.withOpacity(0.35),
                  width: 3,
                ),
              ),
            ),
            child: Html(
              data: htmlData,
              style: styles,
              shrinkWrap: true,
              onLinkTap: (url, attributes, element) {
                if (url != null && url.isNotEmpty) {
                  _openUrl(url);
                }
              },
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
            border: Border.all(
              color: AppColors.accentTeal.withOpacity(0.2),
            ),
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
