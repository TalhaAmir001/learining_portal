import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/academics/admin_academics_models.dart';
import 'package:learining_portal/network/domain/academics_repository.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';

class _PromoteRow {
  _PromoteRow({
    required this.studentId,
    required this.displayName,
    required this.admissionNo,
    required this.rollNo,
  });

  final int studentId;
  final String displayName;
  final String admissionNo;
  final String rollNo;
  bool selected = true;
  String result = 'pass'; // pass | fail
  String nextWorking = 'countinue'; // countinue | leave

  Map<String, dynamic> toJson() => {
        'student_id': studentId,
        'result': result,
        'next_working': nextWorking,
      };
}

class AdminPromoteStudentsScreen extends StatefulWidget {
  const AdminPromoteStudentsScreen({super.key});

  @override
  State<AdminPromoteStudentsScreen> createState() =>
      _AdminPromoteStudentsScreenState();
}

class _AdminPromoteStudentsScreenState extends State<AdminPromoteStudentsScreen> {
  bool _loading = true;
  String? _error;

  AdminAcMetaPayload? _meta;

  int? _fromClassId;
  int? _fromSectionId;
  int? _toSessionId;
  int? _toClassId;
  int? _toSectionId;

  bool _loadingPreview = false;
  List<_PromoteRow> _rows = const [];

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final meta = await AcademicsRepository.getAdminAcademicsMeta();
      _meta = meta;
      if (!meta.success) {
        _error = meta.error ?? 'Failed to load meta.';
      } else {
        _fromClassId ??= meta.classes.isNotEmpty ? meta.classes.first.id : null;
        _fromSectionId ??=
            meta.sections.isNotEmpty ? meta.sections.first.id : null;
        _toClassId ??= meta.classes.isNotEmpty ? meta.classes.first.id : null;
        _toSectionId ??=
            meta.sections.isNotEmpty ? meta.sections.first.id : null;
        _toSessionId ??=
            meta.sessions.isNotEmpty ? meta.sessions.first.id : null;
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _preview() async {
    final fromClassId = _fromClassId;
    final fromSectionId = _fromSectionId;
    final toSessionId = _toSessionId;
    final toClassId = _toClassId;
    final toSectionId = _toSectionId;
    if (fromClassId == null ||
        fromSectionId == null ||
        toSessionId == null ||
        toClassId == null ||
        toSectionId == null) {
      if (!mounted) return;
      SiChrome.showMessage(context, 'Please choose all dropdowns first.');
      return;
    }
    setState(() {
      _loadingPreview = true;
      _rows = const [];
    });
    try {
      final r = await AcademicsRepository.promotePreview(
        fromClassId: fromClassId,
        fromSectionId: fromSectionId,
        toSessionId: toSessionId,
        toClassId: toClassId,
        toSectionId: toSectionId,
      );
      if (!mounted) return;
      if (r['success'] == true && r['items'] is List) {
        final items = (r['items'] as List)
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
        final rows = items.map((s) {
          final id = int.tryParse(s['student_id']?.toString() ?? '') ?? 0;
          final fn = (s['firstname'] ?? '').toString();
          final mn = (s['middlename'] ?? '').toString();
          final ln = (s['lastname'] ?? '').toString();
          final name = [fn, mn, ln].where((x) => x.trim().isNotEmpty).join(' ');
          return _PromoteRow(
            studentId: id,
            displayName: name.isEmpty ? 'Student $id' : name,
            admissionNo: (s['admission_no'] ?? '').toString(),
            rollNo: (s['roll_no'] ?? '').toString(),
          );
        }).where((x) => x.studentId > 0).toList();
        setState(() => _rows = rows);
        if (rows.isEmpty) {
          SiChrome.showMessage(context, 'No students to promote.');
        }
      } else {
        SiChrome.showMessage(context, (r['error'] ?? 'Preview failed').toString());
      }
    } catch (e) {
      if (!mounted) return;
      SiChrome.showMessage(context, e.toString());
    }
    if (mounted) setState(() => _loadingPreview = false);
  }

  Future<void> _apply() async {
    final fromClassId = _fromClassId;
    final fromSectionId = _fromSectionId;
    final toSessionId = _toSessionId;
    final toClassId = _toClassId;
    final toSectionId = _toSectionId;
    if (fromClassId == null ||
        fromSectionId == null ||
        toSessionId == null ||
        toClassId == null ||
        toSectionId == null) {
      if (!mounted) return;
      SiChrome.showMessage(context, 'Please choose all dropdowns first.');
      return;
    }
    final selected = _rows.where((r) => r.selected).toList();
    if (selected.isEmpty) {
      if (!mounted) return;
      SiChrome.showMessage(context, 'Select at least one student.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Promote students?'),
        content: Text('This will update ${selected.length} student records.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Promote')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final r = await AcademicsRepository.promoteApply(
        fromClassId: fromClassId,
        fromSectionId: fromSectionId,
        toSessionId: toSessionId,
        toClassId: toClassId,
        toSectionId: toSectionId,
        students: selected.map((e) => e.toJson()).toList(),
      );
      if (!mounted) return;
      if (r['success'] == true) {
        SiChrome.showMessage(context, 'Promoted successfully.');
        await _preview();
      } else {
        SiChrome.showMessage(context, (r['error'] ?? 'Promote failed').toString());
      }
    } catch (e) {
      if (!mounted) return;
      SiChrome.showMessage(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta;
    return SiThemedPageScaffold(
      title: 'Promote Students',
      subtitle: 'Admin',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          color: Colors.white,
          onPressed: _loading ? null : _loadMeta,
        ),
      ],
      child: _loading
          ? const SiLoadingBlock(message: 'Loading…')
          : meta == null || !meta.success
              ? SiEmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Could not load',
                  message: _error ?? 'Meta not available',
                )
              : RefreshIndicator(
                  color: AppColors.primaryBlue,
                  onRefresh: _loadMeta,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      _SelectorCard(
                        meta: meta,
                        fromClassId: _fromClassId,
                        fromSectionId: _fromSectionId,
                        toSessionId: _toSessionId,
                        toClassId: _toClassId,
                        toSectionId: _toSectionId,
                        onChanged: (s) {
                          setState(() {
                            _fromClassId = s.fromClassId;
                            _fromSectionId = s.fromSectionId;
                            _toSessionId = s.toSessionId;
                            _toClassId = s.toClassId;
                            _toSectionId = s.toSectionId;
                          });
                        },
                        onPreview: _loadingPreview ? null : _preview,
                      ),
                      const SizedBox(height: 12),
                      if (_loadingPreview)
                        const SiLoadingBlock(message: 'Loading students…')
                      else if (_rows.isEmpty)
                        const SiEmptyState(
                          icon: Icons.list_alt_outlined,
                          title: 'No preview loaded',
                          message: 'Tap Preview to load students.',
                        )
                      else ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Students (${_rows.length})',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _apply,
                              icon: const Icon(Icons.trending_up_rounded),
                              label: const Text('Promote'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.accentTeal,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ..._rows.map((r) => _StudentRowCard(
                              row: r,
                              onChanged: () => setState(() {}),
                            )),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _SelectorState {
  _SelectorState({
    required this.fromClassId,
    required this.fromSectionId,
    required this.toSessionId,
    required this.toClassId,
    required this.toSectionId,
  });

  final int? fromClassId;
  final int? fromSectionId;
  final int? toSessionId;
  final int? toClassId;
  final int? toSectionId;
}

class _SelectorCard extends StatefulWidget {
  const _SelectorCard({
    required this.meta,
    required this.fromClassId,
    required this.fromSectionId,
    required this.toSessionId,
    required this.toClassId,
    required this.toSectionId,
    required this.onChanged,
    required this.onPreview,
  });

  final AdminAcMetaPayload meta;
  final int? fromClassId;
  final int? fromSectionId;
  final int? toSessionId;
  final int? toClassId;
  final int? toSectionId;
  final ValueChanged<_SelectorState> onChanged;
  final VoidCallback? onPreview;

  @override
  State<_SelectorCard> createState() => _SelectorCardState();
}

class _SelectorCardState extends State<_SelectorCard> {
  @override
  Widget build(BuildContext context) {
    final meta = widget.meta;
    int? fromClassId = widget.fromClassId;
    int? fromSectionId = widget.fromSectionId;
    int? toSessionId = widget.toSessionId;
    int? toClassId = widget.toClassId;
    int? toSectionId = widget.toSectionId;

    return Card(
      elevation: 0,
      color: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.textSecondary.withOpacity(0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Preview',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            _dd<int>(
              context,
              label: 'From class',
              value: fromClassId,
              items: meta.classes,
              onChanged: (v) {
                setState(() => fromClassId = v);
                widget.onChanged(
                  _SelectorState(
                    fromClassId: v,
                    fromSectionId: fromSectionId,
                    toSessionId: toSessionId,
                    toClassId: toClassId,
                    toSectionId: toSectionId,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _dd<int>(
              context,
              label: 'From section',
              value: fromSectionId,
              items: meta.sections,
              onChanged: (v) {
                setState(() => fromSectionId = v);
                widget.onChanged(
                  _SelectorState(
                    fromClassId: fromClassId,
                    fromSectionId: v,
                    toSessionId: toSessionId,
                    toClassId: toClassId,
                    toSectionId: toSectionId,
                  ),
                );
              },
            ),
            const Divider(height: 22),
            _dd<int>(
              context,
              label: 'To session',
              value: toSessionId,
              items: meta.sessions,
              onChanged: (v) {
                setState(() => toSessionId = v);
                widget.onChanged(
                  _SelectorState(
                    fromClassId: fromClassId,
                    fromSectionId: fromSectionId,
                    toSessionId: v,
                    toClassId: toClassId,
                    toSectionId: toSectionId,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _dd<int>(
              context,
              label: 'To class',
              value: toClassId,
              items: meta.classes,
              onChanged: (v) {
                setState(() => toClassId = v);
                widget.onChanged(
                  _SelectorState(
                    fromClassId: fromClassId,
                    fromSectionId: fromSectionId,
                    toSessionId: toSessionId,
                    toClassId: v,
                    toSectionId: toSectionId,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _dd<int>(
              context,
              label: 'To section',
              value: toSectionId,
              items: meta.sections,
              onChanged: (v) {
                setState(() => toSectionId = v);
                widget.onChanged(
                  _SelectorState(
                    fromClassId: fromClassId,
                    fromSectionId: fromSectionId,
                    toSessionId: toSessionId,
                    toClassId: toClassId,
                    toSectionId: v,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: widget.onPreview,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Preview'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dd<T>(
    BuildContext context, {
    required String label,
    required int? value,
    required List<AdminAcSimpleItem> items,
    required ValueChanged<int?> onChanged,
  }) {
    return InputDecorator(
      decoration: SiChrome.inputDecoration(
        context,
        labelText: label,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          items: items
              .map((e) => DropdownMenuItem<int>(value: e.id, child: Text(e.name)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _StudentRowCard extends StatelessWidget {
  const _StudentRowCard({required this.row, required this.onChanged});

  final _PromoteRow row;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.textSecondary.withOpacity(0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Checkbox(
                  value: row.selected,
                  onChanged: (v) {
                    row.selected = v ?? false;
                    onChanged();
                  },
                ),
                Expanded(
                  child: Text(
                    row.displayName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            Text(
              [
                if (row.admissionNo.isNotEmpty) 'Adm: ${row.admissionNo}',
                if (row.rollNo.isNotEmpty) 'Roll: ${row.rollNo}',
                'ID ${row.studentId}',
              ].join(' · '),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: SiChrome.inputDecoration(context, labelText: 'Result'),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: row.result,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'pass', child: Text('Pass')),
                          DropdownMenuItem(value: 'fail', child: Text('Fail')),
                        ],
                        onChanged: row.selected
                            ? (v) {
                                if (v == null) return;
                                row.result = v;
                                onChanged();
                              }
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InputDecorator(
                    decoration: SiChrome.inputDecoration(context, labelText: 'Next'),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: row.nextWorking,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'countinue', child: Text('Continue')),
                          DropdownMenuItem(value: 'leave', child: Text('Leave')),
                        ],
                        onChanged: row.selected
                            ? (v) {
                                if (v == null) return;
                                row.nextWorking = v;
                                onChanged();
                              }
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

