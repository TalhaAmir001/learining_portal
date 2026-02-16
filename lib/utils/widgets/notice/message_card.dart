import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:learining_portal/models/notice_board_model.dart';
import 'package:learining_portal/utils/app_colors.dart';

class MessageCard extends StatelessWidget {
  final NoticeBoardModel notice;
  final void Function(String url) onLinkTap;

  const MessageCard({super.key, required this.notice, required this.onLinkTap});

  String _normalizeHtml(String html) {
    if (html.isEmpty) return html;
    return html.replaceAll(RegExp(r'\r\n?'), '\n').trim();
  }

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
      "p": Style(margin: Margins.only(bottom: 8), padding: HtmlPaddings.zero),
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
      "li": Style(margin: Margins.only(bottom: 4), padding: HtmlPaddings.zero),
      // Block & inline
      "div": Style(margin: Margins.zero, padding: HtmlPaddings.zero),
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
      "hr": Style(margin: Margins.symmetric(vertical: 12)),
      // Subscript / superscript
      "sub": Style(fontSize: FontSize(12), verticalAlign: VerticalAlign.sub),
      "sup": Style(fontSize: FontSize(12), verticalAlign: VerticalAlign.sup),
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

  void _openUrl(String url) {
    onLinkTap(url);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final raw = notice.message?.trim() ?? '';

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
}
