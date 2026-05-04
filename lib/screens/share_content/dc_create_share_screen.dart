import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/share_content/share_content_models.dart';
import 'package:learining_portal/network/domain/share_content_repository.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

enum _SendKind { public, group, class_, individual }

/// When Firebase profile has no `staff.id`, use this for `upload_by` / `created_by` on this screen.
const int _kFallbackStaffIdForShareScreen = 37;

class DcCreateShareScreen extends StatefulWidget {
  const DcCreateShareScreen({super.key, this.initialUploadIds});

  /// Pre-selected `upload_contents.id` values (e.g. from the content library).
  final List<int>? initialUploadIds;

  @override
  State<DcCreateShareScreen> createState() => _DcCreateShareScreenState();
}

class _DcCreateShareScreenState extends State<DcCreateShareScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool _loading = true;
  DcShareFormMeta? _meta;
  List<DcUploadContentModel> _uploads = [];
  List<DcClassSectionOptionModel> _classSections = [];

  final Set<int> _selectedUploadIds = {};
  final Set<String> _groupIds = {};
  final Set<int> _classSectionIds = {};

  late DateTime _shareDate;
  late DateTime _validUpto;
  _SendKind _sendKind = _SendKind.public;

  final List<_IndividualRow> _individualRows = [];

  bool _submitting = false;

  /// Staff id sent to APIs (`upload_by` list, `created_by` on create).
  int _apiStaffId = _kFallbackStaffIdForShareScreen;
  bool _usingFallbackStaffId = true;

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _shareDate = DateTime(now.year, now.month, now.day);
    _validUpto = _shareDate.add(const Duration(days: 90));
    for (final id in widget.initialUploadIds ?? const <int>[]) {
      if (id > 0) {
        _selectedUploadIds.add(id);
      }
    }
    _individualRows.add(_IndividualRow());
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
    });
    final authStaffId = context.read<AuthProvider>().portalStaffId ?? 0;
    final apiStaff =
        authStaffId > 0 ? authStaffId : _kFallbackStaffIdForShareScreen;
    final meta = await ShareContentRepository.getShareFormMeta();
    final uploads = await ShareContentRepository.getUploadContents(
      limit: 400,
      uploadBy: apiStaff,
    );
    final cs = await ShareContentRepository.getClassSectionsForShare();
    if (!mounted) return;
    final validIds = uploads.map((e) => e.id).toSet();
    setState(() {
      _apiStaffId = apiStaff;
      _usingFallbackStaffId = authStaffId <= 0;
      _meta = meta ?? const DcShareFormMeta(guardianOption: false, roles: []);
      _uploads = uploads;
      _classSections = cs;
      _loading = false;
      _selectedUploadIds.removeWhere((id) => !validIds.contains(id));
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    for (final r in _individualRows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate({required bool isValidUpto}) async {
    final initial = isValidUpto ? _validUpto : _shareDate;
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (d == null || !mounted) return;
    setState(() {
      if (isValidUpto) {
        _validUpto = DateTime(d.year, d.month, d.day);
      } else {
        _shareDate = DateTime(d.year, d.month, d.day);
      }
    });
  }

  String _sendToApi() {
    switch (_sendKind) {
      case _SendKind.public:
        return 'public';
      case _SendKind.group:
        return 'group';
      case _SendKind.class_:
        return 'class';
      case _SendKind.individual:
        return 'individual';
    }
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      SiChrome.showMessage(context, 'Please enter a title.');
      return;
    }
    if (_selectedUploadIds.isEmpty) {
      SiChrome.showMessage(context, 'Select at least one file from the library.');
      return;
    }
    if (_sendKind == _SendKind.group && _groupIds.isEmpty) {
      SiChrome.showMessage(context, 'Select at least one audience group.');
      return;
    }
    if (_sendKind == _SendKind.class_ && _classSectionIds.isEmpty) {
      SiChrome.showMessage(context, 'Select at least one class / section.');
      return;
    }

    final individuals = <Map<String, dynamic>>[];
    if (_sendKind == _SendKind.individual) {
      for (final row in _individualRows) {
        final cat = row.category;
        final rid = int.tryParse(row.recordId.text.trim()) ?? 0;
        final pid = int.tryParse(row.parentId.text.trim()) ?? 0;
        if (cat == 'parent') {
          if (pid <= 0) continue;
          individuals.add({'category': 'parent', 'record_id': 0, 'parent_id': pid});
        } else if (cat == 'student') {
          if (rid <= 0) continue;
          individuals.add({'category': 'student', 'record_id': rid, 'parent_id': 0});
        } else if (cat == 'staff') {
          if (rid <= 0) continue;
          individuals.add({'category': 'staff', 'record_id': rid, 'parent_id': 0});
        } else if (cat == 'student_guardian') {
          if (rid <= 0 || pid <= 0) continue;
          individuals.add({'category': 'student_guardian', 'record_id': rid, 'parent_id': pid});
        }
      }
      if (individuals.isEmpty) {
        SiChrome.showMessage(context, 'Add at least one valid individual recipient.');
        return;
      }
    }

    final body = <String, dynamic>{
      'title': title,
      'description': _descCtrl.text.trim(),
      'share_date': _ymd(_shareDate),
      'valid_upto': _ymd(_validUpto),
      'send_to': _sendToApi(),
      'upload_content_ids': _selectedUploadIds.toList()..sort(),
      'created_by': _apiStaffId,
    };
    if (_sendKind == _SendKind.group) {
      body['group_ids'] = _groupIds.toList();
    }
    if (_sendKind == _SendKind.class_) {
      body['class_section_ids'] = _classSectionIds.toList()..sort();
    }
    if (_sendKind == _SendKind.individual) {
      body['individuals'] = individuals;
    }

    setState(() => _submitting = true);
    final result = await ShareContentRepository.createShare(body);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result['success'] == true) {
      final url = result['shared_url']?.toString();
      if (url != null && url.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Share created'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Public link (same as web):'),
                const SizedBox(height: 8),
                SelectableText(url, style: const TextStyle(fontSize: 13)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
              FilledButton.tonal(
                onPressed: () async {
                  final u = Uri.tryParse(url);
                  if (u != null && await canLaunchUrl(u)) {
                    await launchUrl(u, mode: LaunchMode.externalApplication);
                  }
                },
                child: const Text('Open link'),
              ),
            ],
          ),
        );
      } else {
        SiChrome.showMessage(
          context,
          result['message']?.toString() ?? 'Share created.',
        );
      }
      if (mounted) Navigator.pop(context, true);
    } else {
      final msg = [
        result['error']?.toString(),
        if (result['mysql_error'] != null)
          'MySQL ${result['mysql_errno']}: ${result['mysql_error']}',
      ].whereType<String>().where((s) => s.isNotEmpty).join('\n\n');
      SiChrome.showMessage(context, msg.isNotEmpty ? msg : 'Share failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SiThemedPageScaffold(
        title: 'Share content',
        subtitle: 'Match web download center',
        child: const SiLoadingBlock(message: 'Loading…'),
      );
    }

    return SiThemedPageScaffold(
      title: 'Share content',
      subtitle: 'Pick library files and audience',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (_usingFallbackStaffId)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                elevation: 0,
                color: AppColors.surfaceWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: AppColors.accentTeal.withValues(alpha: 0.35)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'No staff id on this profile. Uploads and new shares use staff #$_kFallbackStaffIdForShareScreen '
                    'so the list matches the server. Link your login to your real staff id when ready.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                  ),
                ),
              ),
            ),
          TextField(
            controller: _titleCtrl,
            decoration: SiChrome.inputDecoration(context, labelText: 'Title *'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: SiChrome.inputDecoration(context, labelText: 'Description'),
            minLines: 2,
            maxLines: 5,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(isValidUpto: false),
                  child: Text('Share from: ${_ymd(_shareDate)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(isValidUpto: true),
                  child: Text('Valid until: ${_ymd(_validUpto)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<_SendKind>(
            // ignore: deprecated_member_use
            value: _sendKind,
            isExpanded: true,
            decoration: SiChrome.inputDecoration(
              context,
              labelText: 'Send to',
              hintText: 'Who can access this share',
            ),
            items: const [
              DropdownMenuItem(
                value: _SendKind.public,
                child: Text('Public link (anyone with URL)'),
              ),
              DropdownMenuItem(
                value: _SendKind.group,
                child: Text('Group (students / guardians / roles)'),
              ),
              DropdownMenuItem(
                value: _SendKind.class_,
                child: Text('Class (class–section combinations)'),
              ),
              DropdownMenuItem(
                value: _SendKind.individual,
                child: Text('Individual recipients'),
              ),
            ],
            onChanged: _submitting
                ? null
                : (v) => setState(() => _sendKind = v ?? _SendKind.public),
          ),
          if (_sendKind == _SendKind.group) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Students'),
                  selected: _groupIds.contains('student'),
                  onSelected: _submitting
                      ? null
                      : (bool sel) => setState(() {
                            if (sel) {
                              _groupIds.add('student');
                            } else {
                              _groupIds.remove('student');
                            }
                          }),
                ),
                if (_meta?.guardianOption == true)
                  FilterChip(
                    label: const Text('Guardians'),
                    selected: _groupIds.contains('parent'),
                    onSelected: _submitting
                        ? null
                        : (bool sel) => setState(() {
                              if (sel) {
                                _groupIds.add('parent');
                              } else {
                                _groupIds.remove('parent');
                              }
                            }),
                  ),
                for (final role in _meta?.roles ?? const <DcShareRoleModel>[])
                  FilterChip(
                    label: Text(role.name.isNotEmpty ? role.name : 'Role #${role.id}'),
                    selected: _groupIds.contains('${role.id}'),
                    onSelected: _submitting
                        ? null
                        : (bool sel) => setState(() {
                              final key = '${role.id}';
                              if (sel) {
                                _groupIds.add(key);
                              } else {
                                _groupIds.remove(key);
                              }
                            }),
                  ),
              ],
            ),
          ],
          if (_sendKind == _SendKind.class_) ...[
            const SizedBox(height: 8),
            if (_classSections.isEmpty)
              Text(
                'No class sections returned from the server.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              )
            else
              SizedBox(
                height: 220,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.builder(
                    itemCount: _classSections.length,
                    itemBuilder: (context, i) {
                      final c = _classSections[i];
                      final checked = _classSectionIds.contains(c.id);
                      return CheckboxListTile(
                        value: checked,
                        onChanged: _submitting
                            ? null
                            : (bool? v) {
                                setState(() {
                                  if (v == true) {
                                    _classSectionIds.add(c.id);
                                  } else {
                                    _classSectionIds.remove(c.id);
                                  }
                                });
                              },
                        title: Text(
                          c.label.isNotEmpty ? c.label : 'Section #${c.id}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        dense: true,
                      );
                    },
                  ),
                ),
              ),
          ],
          if (_sendKind == _SendKind.individual) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _submitting
                    ? null
                    : () => setState(() => _individualRows.add(_IndividualRow())),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add recipient'),
              ),
            ),
            for (var i = 0; i < _individualRows.length; i++)
              _IndividualRecipientCard(
                row: _individualRows[i],
                locked: _submitting,
                onRemove: _individualRows.length <= 1 || _submitting
                    ? null
                    : () => setState(() {
                          _individualRows[i].dispose();
                          _individualRows.removeAt(i);
                        }),
              ),
          ],
          const SizedBox(height: 20),
          Text(
            'Library files *',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          if (_uploads.isEmpty)
            Text(
              'No files in the library yet. Upload files first.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            )
          else
            SizedBox(
              height: 260,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  itemCount: _uploads.length,
                  itemBuilder: (context, i) {
                    final u = _uploads[i];
                    final sel = _selectedUploadIds.contains(u.id);
                    return CheckboxListTile(
                      value: sel,
                      onChanged: _submitting
                          ? null
                          : (bool? v) {
                              setState(() {
                                if (v == true) {
                                  _selectedUploadIds.add(u.id);
                                } else {
                                  _selectedUploadIds.remove(u.id);
                                }
                              });
                            },
                      title: Text(
                        u.realName.isNotEmpty ? u.realName : 'File #${u.id}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          if (u.contentTypeName.isNotEmpty) u.contentTypeName,
                          if (u.createdAt.isNotEmpty) u.createdAt,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      dense: true,
                    );
                  },
                ),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                  )
                : const Icon(Icons.ios_share_rounded),
            label: Text(_submitting ? 'Sharing…' : 'Create share'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}

class _IndividualRow {
  _IndividualRow();

  String category = 'student';
  final recordId = TextEditingController();
  final parentId = TextEditingController();

  void dispose() {
    recordId.dispose();
    parentId.dispose();
  }
}

class _IndividualRecipientCard extends StatefulWidget {
  const _IndividualRecipientCard({
    required this.row,
    required this.locked,
    this.onRemove,
  });

  final _IndividualRow row;
  final bool locked;
  final VoidCallback? onRemove;

  @override
  State<_IndividualRecipientCard> createState() => _IndividualRecipientCardState();
}

class _IndividualRecipientCardState extends State<_IndividualRecipientCard> {
  late String _category;

  @override
  void initState() {
    super.initState();
    _category = widget.row.category;
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: _category,
                    decoration: SiChrome.inputDecoration(context, labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(value: 'student', child: Text('Student')),
                      DropdownMenuItem(value: 'staff', child: Text('Staff')),
                      DropdownMenuItem(value: 'parent', child: Text('Parent')),
                      DropdownMenuItem(
                        value: 'student_guardian',
                        child: Text('Student + guardian'),
                      ),
                    ],
                    onChanged: widget.locked
                        ? null
                        : (v) {
                            if (v == null) return;
                            setState(() {
                              _category = v;
                              row.category = v;
                            });
                          },
                  ),
                ),
                if (widget.onRemove != null)
                  IconButton(
                    tooltip: 'Remove',
                    onPressed: widget.onRemove,
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_category != 'parent')
              TextField(
                controller: row.recordId,
                readOnly: widget.locked,
                keyboardType: TextInputType.number,
                decoration: SiChrome.inputDecoration(
                  context,
                  labelText: _category == 'staff' ? 'Staff id *' : 'Student id *',
                ),
              ),
            if (_category == 'student_guardian') const SizedBox(height: 8),
            if (_category == 'parent' || _category == 'student_guardian') ...[
              TextField(
                controller: row.parentId,
                readOnly: widget.locked,
                keyboardType: TextInputType.number,
                decoration: SiChrome.inputDecoration(
                  context,
                  labelText: 'Parent id *',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
