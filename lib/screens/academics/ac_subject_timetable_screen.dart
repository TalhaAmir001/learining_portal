import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/academics/timetable_models.dart';
import 'package:learining_portal/network/domain/academics_repository.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/screens/academics/ac_timetable_editor_dialog.dart';
import 'package:learining_portal/screens/academics/ac_timetable_list_view.dart';
import 'package:learining_portal/screens/academics/academics_ui.dart';
import 'package:learining_portal/screens/attendance/at_subject_period_screen.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:provider/provider.dart';

class AcSubjectTimetableScreen extends StatefulWidget {
  const AcSubjectTimetableScreen({super.key});

  @override
  State<AcSubjectTimetableScreen> createState() => _AcSubjectTimetableScreenState();
}

class _AcSubjectTimetableScreenState extends State<AcSubjectTimetableScreen> {
  AcTimetableMeta? _meta;
  bool _metaLoading = true;
  AcTimetablePayload? _payload;
  bool _ttLoading = false;
  bool _weekly = true;
  String _dailyDay = 'Monday';
  int? _classId;
  int _sectionId = 0;
  int? _subjectGroupSubjectId;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    setState(() => _metaLoading = true);
    final m = await AcademicsRepository.getTimetableMeta();
    if (!mounted) return;
    setState(() {
      _meta = m;
      _metaLoading = false;
      if (m != null && m.classes.isNotEmpty) {
        _classId ??= m.classes.first.id;
        _pickDefaultSection(m);
        _pickDefaultSubject(m);
      }
    });
    await _loadTimetable();
  }

  void _pickDefaultSection(AcTimetableMeta m) {
    final cid = _classId;
    if (cid == null) return;
    final secs = m.sections.where((s) => s.classId == cid).toList();
    if (secs.isEmpty) {
      _sectionId = 0;
      return;
    }
    if (_sectionId <= 0 || !secs.any((s) => s.sectionId == _sectionId)) {
      _sectionId = secs.first.sectionId;
    }
  }

  void _pickDefaultSubject(AcTimetableMeta m) {
    final cid = _classId;
    final sid = _sectionId;
    if (cid == null || sid <= 0) return;
    final opts = AcademicsUi.subjectOptionsForClassSection(m, cid, sid);
    if (opts.isEmpty) {
      _subjectGroupSubjectId = null;
      return;
    }
    if (_subjectGroupSubjectId == null ||
        !opts.any((o) => o.subjectGroupSubjectId == _subjectGroupSubjectId)) {
      _subjectGroupSubjectId = opts.first.subjectGroupSubjectId;
    }
  }

  Future<void> _loadTimetable() async {
    final cid = _classId;
    final sgs = _subjectGroupSubjectId;
    if (cid == null || cid <= 0 || _sectionId <= 0 || sgs == null || sgs <= 0) {
      setState(() {
        _ttLoading = false;
        _payload = AcTimetablePayload(success: false, error: 'Choose class, section, and subject.', dayOrder: const []);
      });
      return;
    }
    setState(() => _ttLoading = true);
    final p = await AcademicsRepository.getSubjectTimetable(
      classId: cid,
      sectionId: _sectionId,
      subjectGroupSubjectId: sgs,
      day: _weekly ? null : _dailyDay,
    );
    if (!mounted) return;
    setState(() {
      _payload = p;
      _ttLoading = false;
    });
  }

  Future<void> _onClassChanged(int? cid) async {
    setState(() {
      _classId = cid;
      _sectionId = 0;
      _subjectGroupSubjectId = null;
      _payload = null;
    });
    final m = _meta;
    if (m != null && cid != null) {
      _pickDefaultSection(m);
      _pickDefaultSubject(m);
    }
    await _loadTimetable();
  }

  void _openAttendance(AcTimetableEntry e) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AtSubjectPeriodScreen(
          initialClassId: e.classId,
          initialSectionId: e.sectionId,
          initialDate: AcademicsUi.dateForEnglishWeekday(e.day),
          initialSubjectTimetableId: e.subjectTimetableId,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(AcTimetableEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete period?'),
        content: Text('Remove ${e.subjectName} on ${e.day}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final out = await AcademicsRepository.deleteSubjectTimetableRow(id: e.id);
    if (!mounted) return;
    if (out['success'] == true) {
      SiChrome.showMessage(context, 'Deleted.');
      await _loadTimetable();
    } else {
      SiChrome.showMessage(context, out['error']?.toString() ?? 'Delete failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().userType == UserType.admin;
    final m = _meta;

    return SiThemedPageScaffold(
      title: 'Subject timetable',
      subtitle: 'One subject across the week',
      child: _metaLoading
          ? const Center(child: CircularProgressIndicator())
          : m == null
              ? const Center(child: Text('Could not load timetable data.'))
              : Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: AppColors.primaryBlue.withOpacity(0.1)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  DropdownButtonFormField<int>(
                                    isExpanded: true,
                                    decoration: SiChrome.inputDecoration(context, labelText: 'Class'),
                                    value: _classId != null && m.classes.any((c) => c.id == _classId) ? _classId : null,
                                    items: m.classes
                                        .map(
                                          (c) => DropdownMenuItem(
                                            value: c.id,
                                            child: Text(c.name, overflow: TextOverflow.ellipsis),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: _onClassChanged,
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<int>(
                                    isExpanded: true,
                                    decoration: SiChrome.inputDecoration(context, labelText: 'Section'),
                                    value: _sectionId > 0 &&
                                            m.sections.any((s) => s.classId == _classId && s.sectionId == _sectionId)
                                        ? _sectionId
                                        : null,
                                    items: m.sections
                                        .where((s) => s.classId == _classId)
                                        .map(
                                          (s) => DropdownMenuItem(
                                            value: s.sectionId,
                                            child: Text(s.name, overflow: TextOverflow.ellipsis),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) async {
                                      setState(() {
                                        _sectionId = v ?? 0;
                                        _subjectGroupSubjectId = null;
                                      });
                                      _pickDefaultSubject(m);
                                      await _loadTimetable();
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  Builder(
                                    builder: (context) {
                                      final opts = (_classId != null && _sectionId > 0)
                                          ? AcademicsUi.subjectOptionsForClassSection(m, _classId!, _sectionId)
                                          : <AcSubjectGroupSubjectOption>[];
                                      return DropdownButtonFormField<int>(
                                        isExpanded: true,
                                        decoration: SiChrome.inputDecoration(context, labelText: 'Subject'),
                                        value: _subjectGroupSubjectId != null &&
                                                opts.any((o) => o.subjectGroupSubjectId == _subjectGroupSubjectId)
                                            ? _subjectGroupSubjectId
                                            : null,
                                        items: opts
                                            .map(
                                              (o) => DropdownMenuItem(
                                                value: o.subjectGroupSubjectId,
                                                child: Text(o.label, overflow: TextOverflow.ellipsis),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (v) async {
                                          setState(() => _subjectGroupSubjectId = v);
                                          await _loadTimetable();
                                        },
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  ToggleButtons(
                                    isSelected: [!_weekly, _weekly],
                                    onPressed: (i) async {
                                      setState(() => _weekly = i == 1);
                                      await _loadTimetable();
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    selectedColor: Colors.white,
                                    fillColor: AppColors.primaryBlue,
                                    color: AppColors.textSecondary,
                                    children: const [
                                      Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 16),
                                        child: Text('Daily'),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 16),
                                        child: Text('Weekly'),
                                      ),
                                    ],
                                  ),
                                  if (!_weekly) ...[
                                    const SizedBox(height: 12),
                                    DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      decoration: SiChrome.inputDecoration(context, labelText: 'Day'),
                                      value: AcademicsUi.englishWeekdays.contains(_dailyDay)
                                          ? _dailyDay
                                          : AcademicsUi.englishWeekdays.first,
                                      items: AcademicsUi.englishWeekdays
                                          .map(
                                            (d) => DropdownMenuItem(
                                              value: d,
                                              child: Text(d, overflow: TextOverflow.ellipsis),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) async {
                                        setState(() => _dailyDay = v ?? 'Monday');
                                        await _loadTimetable();
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: _ttLoading
                              ? const Center(child: CircularProgressIndicator())
                              : _payload == null
                                  ? const SizedBox.shrink()
                                  : AcTimetableListView(
                                      payload: _payload!,
                                      weekly: _weekly,
                                      onEntryTap: (e) {
                                        AcademicsUi.showTimetableEntrySheet(
                                          context,
                                          entry: e,
                                          isAdmin: isAdmin,
                                          onMarkAttendance: () => _openAttendance(e),
                                          onEdit: isAdmin
                                              ? () async {
                                                  final ok = await showAcTimetableEditor(
                                                    context,
                                                    meta: m,
                                                    classId: e.classId,
                                                    sectionId: e.sectionId,
                                                    existing: e,
                                                  );
                                                  if (ok == true && mounted) await _loadTimetable();
                                                }
                                              : null,
                                          onDelete: isAdmin ? () => _confirmDelete(e) : null,
                                        );
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }
}
