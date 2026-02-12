import 'package:flutter/material.dart';
import 'package:learining_portal/models/notice_board_model.dart';
import 'package:learining_portal/providers/send_notifications_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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

  static String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day}/${d.month}/${d.year}';
  }

  static String _formatDateTime(DateTime? d) {
    if (d == null) return '—';
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notice = widget.notice;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notice'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              notice.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            if (notice.publishDate != null || notice.date != null) ...[
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Date: ${_formatDate(notice.publishDate ?? notice.date)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (notice.createdBy != null && notice.createdBy!.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.person_outline, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'By: ${notice.createdBy}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (notice.message != null && notice.message!.isNotEmpty) ...[
              Text(
                notice.message!,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.4,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (notice.attachment != null && notice.attachment!.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                'Attachment',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _openAttachment(notice.attachment!),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.attach_file, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          notice.attachment!,
                          style: theme.textTheme.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.open_in_new, size: 20, color: theme.colorScheme.primary),
                    ],
                  ),
                ),
              ),
            ],
            if (notice.createdAt != null) ...[
              const SizedBox(height: 24),
              Text(
                'Published: ${_formatDateTime(notice.createdAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ],
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
