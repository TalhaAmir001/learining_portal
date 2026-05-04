import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:learining_portal/network/data_models/communicate/communicate_models.dart';
import 'package:learining_portal/network/domain/communicate_repository.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

List<CommLogRecipient> _dedupeCommRecipients(List<CommLogRecipient> input) {
  final seen = <String>{};
  final out = <CommLogRecipient>[];
  for (final r in input) {
    final k = '${r.userId}|${r.email}'.toLowerCase();
    if (seen.contains(k)) continue;
    seen.add(k);
    out.add(r);
  }
  return out;
}

/// Root wrapper so flutter_html parses fragments with multiple top-level nodes.
String _htmlFragment(String raw) {
  final inner = raw.replaceAll(RegExp(r'\r\n?'), '\n').trim();
  if (inner.isEmpty) return '';
  return '<div>$inner</div>';
}

/// Prefer API-resolved names (`get_comm_message_detail.php`); fall back to ids.
String _scheduleClassSectionLine({
  required String scheduleClassName,
  required String scheduleSectionNames,
  required String scheduleClassId,
  required String sectionIdsFormatted,
}) {
  final classPart = scheduleClassName.isNotEmpty
      ? 'Class: $scheduleClassName'
      : (scheduleClassId.isNotEmpty ? 'Class #$scheduleClassId' : '');
  String sectionPart;
  if (scheduleSectionNames.isNotEmpty) {
    sectionPart = 'Sections: $scheduleSectionNames';
  } else if (sectionIdsFormatted.isNotEmpty) {
    sectionPart = 'Sections: $sectionIdsFormatted';
  } else {
    sectionPart = '';
  }
  return [classPart, sectionPart].where((e) => e.isNotEmpty).join(' · ');
}

class CommMessageDetailScreen extends StatefulWidget {
  const CommMessageDetailScreen({super.key, required this.messageId});

  final int messageId;

  @override
  State<CommMessageDetailScreen> createState() => _CommMessageDetailScreenState();
}

class _CommMessageDetailScreenState extends State<CommMessageDetailScreen> {
  late Future<Map<String, dynamic>?> _future;

  @override
  void initState() {
    super.initState();
    _future = CommunicateRepository.getMessageDetail(widget.messageId);
  }

  Future<void> _reload() async {
    setState(() {
      _future = CommunicateRepository.getMessageDetail(widget.messageId);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return SiThemedPageScaffold(
      title: 'Message detail',
      subtitle: 'ID ${widget.messageId}',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () async {
            await _reload();
            if (context.mounted) SiChrome.showMessage(context, 'Refreshed');
          },
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
        ),
      ],
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SiLoadingBlock(message: 'Loading message…');
          }
          final map = snap.data;
          if (map == null || map.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 32),
              children: [
                const SiEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load message',
                  message: 'Check your connection or permissions.',
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    onPressed: () => _reload(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ),
              ],
            );
          }
          return RefreshIndicator(
            color: AppColors.primaryBlue,
            onRefresh: _reload,
            child: _CommMessageDetailBody(map: map),
          );
        },
      ),
    );
  }
}

class _CommMessageDetailBody extends StatelessWidget {
  const _CommMessageDetailBody({required this.map});

  final Map<String, dynamic> map;

  String _str(dynamic v) => v == null ? '' : v.toString().trim();

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await canLaunchUrl(uri)) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _str(map['title']);
    final messageHtml = _str(map['message']);
    final sendToRaw = _str(map['send_to']);
    final sendTo = commFormatAudienceSendTo(sendToRaw);
    final groupList = _str(map['group_list']);
    final userListRaw = _str(map['user_list']);
    final recipients = commParseRecipients(userListRaw.isEmpty ? null : userListRaw);
    final mail = commParseBoolFlag(map['send_mail']);
    final sms = commParseBoolFlag(map['send_sms']);
    final isClass = commParseBoolFlag(map['is_class']);
    final isGroup = commParseBoolFlag(map['is_group']);
    final isIndividual = commParseBoolFlag(map['is_individual']);
    final isSchedule = commParseBoolFlag(map['is_schedule']);
    final sentVal = map['sent'];
    final scheduleDt = _str(map['schedule_date_time']);
    final createdAt = _str(map['created_at']);
    final updatedAt = _str(map['updated_at']);
    final templateId = _str(map['template_id']);
    final scheduleClass = map['schedule_class'];
    final scheduleSectionRaw = _str(map['schedule_section']);
    final scheduleSection = commFormatSectionIds(scheduleSectionRaw);
    final scheduleClassName = _str(map['schedule_class_name']);
    final scheduleSectionNames = _str(map['schedule_section_names']);

    final audienceBits = <String>[];
    if (isClass) audienceBits.add('Class');
    if (isGroup) audienceBits.add('Group');
    if (isIndividual) audienceBits.add('Individual');
    final audienceLabel =
        audienceBits.isEmpty ? 'Audience' : 'Audience (${audienceBits.join(', ')})';

    final channelBits = <String>[];
    if (mail) channelBits.add('Email');
    if (sms) channelBits.add('SMS');

    String sentLabel;
    if (sentVal == null) {
      sentLabel = isSchedule ? 'Not sent yet (scheduled)' : 'Status not recorded';
    } else {
      final n = int.tryParse(sentVal.toString()) ?? 0;
      sentLabel = n != 0 ? 'Sent' : 'Not sent';
    }

    final baseStyle = theme.textTheme.bodyMedium ?? const TextStyle();
    final htmlStyles = {
      'body': Style(
        margin: Margins.zero,
        padding: HtmlPaddings.zero,
        fontSize: FontSize(baseStyle.fontSize ?? 15),
        color: AppColors.textPrimary,
        lineHeight: LineHeight(1.55),
      ),
      'p': Style(margin: Margins.only(bottom: 8), padding: HtmlPaddings.zero),
      'strong': Style(fontWeight: FontWeight.w700),
      'b': Style(fontWeight: FontWeight.w700),
      'br': Style(margin: Margins.only(bottom: 4)),
      'a': Style(
        color: const Color(0xFF1565C0),
        textDecoration: TextDecoration.underline,
      ),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (title.isNotEmpty)
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        if (title.isNotEmpty) const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (channelBits.isNotEmpty)
              Chip(
                avatar: Icon(
                  mail ? Icons.email_outlined : Icons.sms_outlined,
                  size: 18,
                  color: AppColors.primaryBlue,
                ),
                label: Text(channelBits.join(' & ')),
              ),
            Chip(
              label: Text(sentLabel),
              visualDensity: VisualDensity.compact,
            ),
            if (isSchedule && scheduleDt.isNotEmpty)
              Chip(
                avatar: const Icon(Icons.schedule, size: 18),
                label: Text('Scheduled $scheduleDt'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          audienceLabel,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        if (sendTo.isNotEmpty)
          Text(sendTo, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        if (scheduleClass != null &&
            (scheduleClass is num ? scheduleClass != 0 : _str(scheduleClass).isNotEmpty))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _scheduleClassSectionLine(
                scheduleClassName: scheduleClassName,
                scheduleSectionNames: scheduleSectionNames,
                scheduleClassId: _str(scheduleClass),
                sectionIdsFormatted: scheduleSection,
              ),
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        if (groupList.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Groups',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            groupList.replaceAll(',', ', '),
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
        if (recipients.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Recipients (${_dedupeCommRecipients(recipients).length})',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ..._dedupeCommRecipients(recipients).map(
            (r) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              color: AppColors.surfaceWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.accentTeal.withValues(alpha: 0.2)),
              ),
              child: ListTile(
                dense: true,
                title: Text(
                  r.email.isNotEmpty ? r.email : 'User ${r.userId}',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  [
                    if (r.role.isNotEmpty) r.role,
                    if (r.userId.isNotEmpty) 'ID ${r.userId}',
                    if (r.mobile.isNotEmpty) r.mobile,
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
        ] else if (userListRaw.isNotEmpty && userListRaw.startsWith('[')) ...[
          const SizedBox(height: 12),
          Text(
            'Recipients',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Could not parse recipient list.',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'Message',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (messageHtml.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.accentTeal.withValues(alpha: 0.25)),
            ),
            child: Html(
              data: _htmlFragment(messageHtml),
              style: htmlStyles,
              shrinkWrap: true,
              onLinkTap: (url, attributes, element) => _openUrl(url),
            ),
          )
        else
          Text(
            '—',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        const SizedBox(height: 20),
        if (templateId.isNotEmpty)
          SiKeyValueTile(label: 'Template id', value: templateId),
        if (createdAt.isNotEmpty) SiKeyValueTile(label: 'Created', value: createdAt),
        if (updatedAt.isNotEmpty) SiKeyValueTile(label: 'Updated', value: updatedAt),
      ],
    );
  }
}
