import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/communicate/communicate_models.dart';
import 'package:learining_portal/network/data_models/student_information/student_information_models.dart';
import 'package:learining_portal/network/domain/communicate_repository.dart';
import 'package:learining_portal/network/domain/student_information_repository.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/api_client.dart';
import 'package:learining_portal/utils/app_colors.dart';

enum _Audience { classAudience, individual }

/// Compose bulk email (class + sections or individual addresses), same `messages` row as web log.
class CommSendEmailScreen extends StatefulWidget {
  const CommSendEmailScreen({super.key});

  @override
  State<CommSendEmailScreen> createState() => _CommSendEmailScreenState();
}

class _CommSendEmailScreenState extends State<CommSendEmailScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _emailsCtrl = TextEditingController();
  final _scheduleDtCtrl = TextEditingController();

  List<SiClassModel> _classes = [];
  List<SiSectionModel> _sections = [];
  List<CommTemplateModel> _templates = [];

  int? _classId;
  final Set<int> _sectionIds = {};
  _Audience _audience = _Audience.classAudience;
  bool _sendMail = true;
  bool _sendSms = false;
  bool _schedule = false;
  int? _templateId;
  bool _loadingMeta = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMeta());
  }

  Future<void> _loadMeta() async {
    setState(() => _loadingMeta = true);
    final classes = await StudentInformationRepository.getClasses();
    final templates = await CommunicateRepository.getEmailTemplates();
    if (!mounted) return;
    setState(() {
      _classes = classes;
      _templates = templates;
      _loadingMeta = false;
    });
    if (_classId != null && _classId! > 0) {
      await _loadSections(_classId!);
    }
  }

  Future<void> _loadSections(int classId) async {
    final sec = await StudentInformationRepository.getSections(classId: classId);
    if (!mounted) return;
    setState(() {
      _sections = sec;
      _sectionIds.removeWhere((id) => !sec.any((s) => s.id == id));
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _emailsCtrl.dispose();
    _scheduleDtCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text;
    if (title.isEmpty) {
      SiChrome.showMessage(context, 'Enter a subject.');
      return;
    }
    if (body.trim().isEmpty) {
      SiChrome.showMessage(context, 'Enter a message body.');
      return;
    }
    if (!_sendMail && !_sendSms) {
      SiChrome.showMessage(context, 'Turn on Email and/or SMS.');
      return;
    }
    if (_schedule && _scheduleDtCtrl.text.trim().isEmpty) {
      SiChrome.showMessage(context, 'Enter schedule date/time or turn off Schedule.');
      return;
    }

    if (_audience == _Audience.classAudience) {
      if (_classId == null || _classId! <= 0) {
        SiChrome.showMessage(context, 'Choose a class.');
        return;
      }
      if (_sectionIds.isEmpty) {
        SiChrome.showMessage(context, 'Pick at least one section.');
        return;
      }
    } else {
      if (_emailsCtrl.text.trim().isEmpty) {
        SiChrome.showMessage(context, 'Enter one or more email addresses.');
        return;
      }
    }

    var messageForApi = body;
    if (!messageForApi.contains('<')) {
      messageForApi = commPlainToHtmlEmailBody(messageForApi);
    }

    final payload = <String, dynamic>{
      'title': title,
      'message': messageForApi,
      'send_mail': _sendMail,
      'send_sms': _sendSms,
      'audience': _audience == _Audience.classAudience ? 'class' : 'individual',
      'send_to': ['student'],
      'class_id': _classId ?? 0,
      'section_ids': _sectionIds.toList()..sort(),
      'individual_emails': _emailsCtrl.text.trim(),
      'is_schedule': _schedule,
      'schedule_date_time': _scheduleDtCtrl.text.trim(),
      if (_templateId != null && _templateId! > 0) 'template_id': _templateId.toString(),
    };

    setState(() => _submitting = true);
    try {
      final r = await CommunicateRepository.sendEmailCompose(payload);
      if (!mounted) return;
      if (r['success'] == true) {
        final warnings = r['warnings'];
        final extra = <String>[];
        if (warnings is List) {
          for (final w in warnings) {
            if (w != null && w.toString().trim().isNotEmpty) {
              extra.add(w.toString().trim());
            }
          }
        }
        final msg = StringBuffer(
          'Saved (${r['recipient_count'] ?? 0} recipients). Message #${r['message_id'] ?? ''}.',
        );
        if (extra.isNotEmpty) {
          msg.write('\n\n');
          msg.write(extra.join('\n'));
        }
        SiChrome.showMessage(context, msg.toString());
        Navigator.pop(context, true);
      } else {
        SiChrome.showMessage(context, r['error']?.toString() ?? 'Send failed.');
      }
    } on ApiException catch (e) {
      if (mounted) SiChrome.showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SiThemedPageScaffold(
      title: 'Send email',
      subtitle: 'Class/sections or individual list',
      child: _loadingMeta
          ? const SiLoadingBlock(message: 'Loading classes & templates…')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  'Templates',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  value: _templateId, // ignore: deprecated_member_use
                  decoration: const InputDecoration(
                    labelText: 'Optional — apply saved body',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('None')),
                    ..._templates.map(
                      (t) => DropdownMenuItem<int?>(
                        value: t.id,
                        child: Text(t.title.isNotEmpty ? t.title : 'Template #${t.id}'),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => _templateId = v);
                    if (v != null) {
                      for (final t in _templates) {
                        if (t.id == v && t.message.isNotEmpty) {
                          _bodyCtrl.text = commHtmlToPlainEmailTemplate(t.message);
                          break;
                        }
                      }
                    }
                  },
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bodyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    helperText: 'Plain text: blank line = new paragraph. Include <…> to send raw HTML.',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  minLines: 6,
                  maxLines: 14,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Send as email'),
                  value: _sendMail,
                  onChanged: (v) => setState(() => _sendMail = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include SMS (log only; gateway uses web)'),
                  value: _sendSms,
                  onChanged: (v) => setState(() => _sendSms = v),
                ),
                const SizedBox(height: 8),
                Text(
                  'Audience',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SegmentedButton<_Audience>(
                  segments: const [
                    ButtonSegment(
                      value: _Audience.classAudience,
                      label: Text('Class'),
                      icon: Icon(Icons.school_outlined),
                    ),
                    ButtonSegment(
                      value: _Audience.individual,
                      label: Text('Individual'),
                      icon: Icon(Icons.person_outline),
                    ),
                  ],
                  selected: {_audience},
                  onSelectionChanged: (Set<_Audience> s) {
                    setState(() => _audience = s.first);
                  },
                ),
                if (_audience == _Audience.classAudience) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int?>(
                    value: (_classId != null && _classes.any((c) => c.id == _classId)) ? _classId : null, // ignore: deprecated_member_use
                    decoration: const InputDecoration(
                      labelText: 'Class',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Select class')),
                      ..._classes.map(
                        (c) => DropdownMenuItem<int?>(
                          value: c.id,
                          child: Text(c.className.isNotEmpty ? c.className : 'Class #${c.id}'),
                        ),
                      ),
                    ],
                    onChanged: (v) async {
                      setState(() {
                        _classId = v;
                        _sectionIds.clear();
                        _sections = [];
                      });
                      if (v != null && v > 0) {
                        await _loadSections(v);
                        if (mounted) setState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sections',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  if (_sections.isEmpty)
                    Text(
                      _classId == null ? 'Select a class first.' : 'No sections for this class.',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _sections.map((s) {
                        final sel = _sectionIds.contains(s.id);
                        return FilterChip(
                          label: Text(s.sectionName.isNotEmpty ? s.sectionName : '#${s.id}'),
                          selected: sel,
                          onSelected: (_) {
                            setState(() {
                              if (sel) {
                                _sectionIds.remove(s.id);
                              } else {
                                _sectionIds.add(s.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                ] else ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email addresses',
                      hintText: 'Comma or newline separated',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    minLines: 2,
                    maxLines: 6,
                  ),
                ],
                const SizedBox(height: 20),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Schedule send'),
                  subtitle: const Text('MySQL datetime, e.g. 2026-05-10 18:00:00'),
                  value: _schedule,
                  onChanged: (v) => setState(() => _schedule = v),
                ),
                if (_schedule) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _scheduleDtCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Schedule date & time',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_submitting ? 'Sending…' : 'Send'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
    );
  }
}
