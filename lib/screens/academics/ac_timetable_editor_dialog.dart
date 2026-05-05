import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/academics/timetable_models.dart';
import 'package:learining_portal/network/domain/academics_repository.dart';
import 'package:learining_portal/screens/academics/academics_ui.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';

/// Add or edit a single `subject_timetable` row (admin).
Future<bool?> showAcTimetableEditor(
  BuildContext context, {
  required AcTimetableMeta meta,
  required int classId,
  required int sectionId,
  AcTimetableEntry? existing,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _AcTimetableEditorDialog(
      meta: meta,
      classId: classId,
      sectionId: sectionId,
      existing: existing,
    ),
  );
}

class _AcTimetableEditorDialog extends StatefulWidget {
  const _AcTimetableEditorDialog({
    required this.meta,
    required this.classId,
    required this.sectionId,
    this.existing,
  });

  final AcTimetableMeta meta;
  final int classId;
  final int sectionId;
  final AcTimetableEntry? existing;

  @override
  State<_AcTimetableEditorDialog> createState() => _AcTimetableEditorDialogState();
}

class _AcTimetableEditorDialogState extends State<_AcTimetableEditorDialog> {
  late String _day;
  late TextEditingController _timeFrom;
  late TextEditingController _timeTo;
  late TextEditingController _room;
  int? _sgsId;
  int? _staffId;
  bool _saving = false;

  List<AcSubjectGroupSubjectOption> get _subjectRows {
    final groupIds = widget.meta.classSectionSubjectGroups
        .where((e) => e.classId == widget.classId && e.sectionId == widget.sectionId)
        .map((e) => e.subjectGroupId)
        .toSet();
    return widget.meta.subjectGroupSubjects.where((e) => groupIds.contains(e.subjectGroupId)).toList();
  }

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _day = (ex?.day ?? 'Monday').isNotEmpty ? ex!.day : 'Monday';
    _timeFrom = TextEditingController(text: ex?.timeFrom ?? '09:00 AM');
    _timeTo = TextEditingController(text: ex?.timeTo ?? '10:00 AM');
    _room = TextEditingController(text: ex?.roomNo ?? '');
    _sgsId = ex != null && ex.subjectGroupSubjectId > 0 ? ex.subjectGroupSubjectId : null;
    _staffId = ex != null && ex.staffId > 0 ? ex.staffId : null;
    final subjects = _subjectRows;
    if (_sgsId == null && subjects.isNotEmpty) {
      _sgsId = subjects.first.subjectGroupSubjectId;
    }
    if (_staffId == null && widget.meta.staffTeachers.isNotEmpty) {
      _staffId = widget.meta.staffTeachers.first.id;
    }
  }

  @override
  void dispose() {
    _timeFrom.dispose();
    _timeTo.dispose();
    _room.dispose();
    super.dispose();
  }

  AcSubjectGroupSubjectOption? _selectedSgs() {
    final id = _sgsId;
    if (id == null) return null;
    for (final r in _subjectRows) {
      if (r.subjectGroupSubjectId == id) return r;
    }
    return null;
  }

  Future<void> _save() async {
    final sgs = _selectedSgs();
    final staff = _staffId;
    if (sgs == null || staff == null) {
      SiChrome.showMessage(context, 'Pick subject and teacher.');
      return;
    }
    setState(() => _saving = true);
    try {
      final row = <String, dynamic>{
        'day': _day,
        'class_id': widget.classId,
        'section_id': widget.sectionId,
        'subject_group_id': sgs.subjectGroupId,
        'subject_group_subject_id': sgs.subjectGroupSubjectId,
        'staff_id': staff,
        'time_from': _timeFrom.text.trim(),
        'time_to': _timeTo.text.trim(),
        'room_no': _room.text.trim(),
      };
      final ex = widget.existing;
      final Map<String, dynamic> out;
      if (ex != null && ex.id > 0) {
        out = await AcademicsRepository.upsertSubjectTimetable(
          insert: const [],
          update: [
            {...row, 'id': ex.id},
          ],
          deleteIds: const [],
        );
      } else {
        out = await AcademicsRepository.upsertSubjectTimetable(
          insert: [row],
          update: const [],
          deleteIds: const [],
        );
      }
      if (!mounted) return;
      if (out['success'] == true) {
        Navigator.pop(context, true);
        SiChrome.showMessage(context, out['message']?.toString() ?? 'Saved.');
      } else {
        SiChrome.showMessage(context, out['error']?.toString() ?? 'Save failed.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjects = _subjectRows;
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add period' : 'Edit period'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: SiChrome.inputDecoration(context, labelText: 'Day'),
              value: AcademicsUi.englishWeekdays.contains(_day) ? _day : AcademicsUi.englishWeekdays.first,
              items: AcademicsUi.englishWeekdays
                  .map(
                    (d) => DropdownMenuItem(
                      value: d,
                      child: Text(d, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _day = v ?? 'Monday'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _timeFrom,
              decoration: SiChrome.inputDecoration(
                context,
                labelText: 'Time from',
                hintText: 'e.g. 9:00 AM',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _timeTo,
              decoration: SiChrome.inputDecoration(
                context,
                labelText: 'Time to',
                hintText: 'e.g. 10:00 AM',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _room,
              decoration: SiChrome.inputDecoration(context, labelText: 'Room'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              isExpanded: true,
              decoration: SiChrome.inputDecoration(context, labelText: 'Subject'),
              value: _sgsId != null && subjects.any((s) => s.subjectGroupSubjectId == _sgsId)
                  ? _sgsId
                  : null,
              items: subjects
                  .map(
                    (s) => DropdownMenuItem(
                      value: s.subjectGroupSubjectId,
                      child: Text(s.label, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _sgsId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              isExpanded: true,
              decoration: SiChrome.inputDecoration(context, labelText: 'Teacher'),
              value: _staffId != null && widget.meta.staffTeachers.any((s) => s.id == _staffId)
                  ? _staffId
                  : null,
              items: widget.meta.staffTeachers
                  .map(
                    (s) => DropdownMenuItem(
                      value: s.id,
                      child: Text(s.displayName, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _staffId = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primaryBlue),
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
