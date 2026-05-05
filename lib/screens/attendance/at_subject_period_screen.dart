import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/attendance/attendance_models.dart';
import 'package:learining_portal/network/data_models/student_information/student_information_models.dart';
import 'package:learining_portal/network/domain/attendance_repository.dart';
import 'package:learining_portal/network/domain/student_information_repository.dart';
import 'package:learining_portal/screens/attendance/attendance_ui.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Portal `admin/subjectattendence/index` — mark by subject timetable slot.
class AtSubjectPeriodScreen extends StatefulWidget {
  const AtSubjectPeriodScreen({super.key});

  @override
  State<AtSubjectPeriodScreen> createState() => _AtSubjectPeriodScreenState();
}

class _AtSubjectPeriodScreenState extends State<AtSubjectPeriodScreen> {
  List<SiClassModel> _classes = [];
  List<SiSectionModel> _sections = [];
  List<AtTypeModel> _types = [];
  List<AtSubjectSlotModel> _slots = [];
  int? _classId;
  int _sectionId = 0;
  int? _slotId;
  DateTime _date = DateTime.now();
  bool _mastersLoading = true;
  bool _slotsLoading = false;

  List<AtSubjectStudentRowModel> _rows = [];
  final Map<int, int?> _typeBySession = {};
  final Map<int, String> _remarkBySession = {};
  bool _gridLoading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadMasters();
  }

  Future<void> _loadMasters() async {
    setState(() => _mastersLoading = true);
    final c = await StudentInformationRepository.getClasses();
    final t = await AttendanceRepository.getStudentAttendanceTypes();
    if (!mounted) return;
    setState(() {
      _classes = c;
      _types = t;
      _mastersLoading = false;
    });
  }

  Future<void> _onClassChanged(int? id) async {
    setState(() {
      _classId = id;
      _sectionId = 0;
      _sections = [];
      _slots = [];
      _slotId = null;
      _rows = [];
      _typeBySession.clear();
      _remarkBySession.clear();
    });
    if (id == null || id <= 0) return;
    final sec = await StudentInformationRepository.getSections(classId: id);
    if (!mounted) return;
    setState(() => _sections = sec);
  }

  int? _defaultTypeId() {
    for (final x in _types) {
      if (x.keyValue.toUpperCase() == 'P') return x.id;
    }
    return _types.isNotEmpty ? _types.first.id : null;
  }

  Future<void> _loadSlots() async {
    if (_classId == null || _classId! <= 0 || _sectionId <= 0) {
      SiChrome.showMessage(context, 'Choose class and section.');
      return;
    }
    setState(() => _slotsLoading = true);
    final r = await AttendanceRepository.getSubjectSlots(
      classId: _classId!,
      sectionId: _sectionId,
      dateYmd: _ymd(_date),
    );
    if (!mounted) return;
    final list = <AtSubjectSlotModel>[];
    if (r['success'] == true && r['slots'] is List) {
      for (final e in r['slots'] as List<dynamic>) {
        list.add(AtSubjectSlotModel.fromJson(e as Map<String, dynamic>));
      }
    }
    setState(() {
      _slots = list;
      _slotId = list.isNotEmpty ? list.first.subjectTimetableId : null;
      _slotsLoading = false;
      _rows = [];
      _typeBySession.clear();
      _remarkBySession.clear();
    });
    if (r['success'] != true) {
      SiChrome.showMessage(context, r['error']?.toString() ?? 'Failed to load slots.');
    } else if (list.isEmpty) {
      SiChrome.showMessage(context, 'No timetable periods for this weekday.');
    }
  }

  Future<void> _loadGrid() async {
    if (_slotId == null || _slotId! <= 0) {
      SiChrome.showMessage(context, 'Load slots and pick a period.');
      return;
    }
    setState(() => _gridLoading = true);
    final r = await AttendanceRepository.getSubjectSlotAttendance(
      classId: _classId!,
      sectionId: _sectionId,
      subjectTimetableId: _slotId!,
      dateYmd: _ymd(_date),
    );
    if (!mounted) return;
    final list = <AtSubjectStudentRowModel>[];
    if (r['success'] == true && r['students'] is List) {
      for (final e in r['students'] as List<dynamic>) {
        list.add(AtSubjectStudentRowModel.fromJson(e as Map<String, dynamic>));
      }
    }
    final def = _defaultTypeId();
    _typeBySession.clear();
    _remarkBySession.clear();
    for (final row in list) {
      _typeBySession[row.studentSessionId] = row.attendenceTypeId ?? def;
      _remarkBySession[row.studentSessionId] = row.remark;
    }
    setState(() {
      _rows = list;
      _gridLoading = false;
    });
    if (r['success'] != true) {
      SiChrome.showMessage(context, r['error']?.toString() ?? 'Failed to load.');
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() {
        _date = d;
        _slots = [];
        _slotId = null;
        _rows = [];
      });
    }
  }

  Future<void> _save() async {
    if (_slotId == null || _rows.isEmpty) {
      SiChrome.showMessage(context, 'Load students first.');
      return;
    }
    final def = _defaultTypeId();
    if (def == null) return;
    setState(() => _saving = true);
    final rows = <Map<String, dynamic>>[];
    for (final row in _rows) {
      final sid = row.studentSessionId;
      rows.add({
        'student_session_id': sid,
        'attendence_type_id': _typeBySession[sid] ?? def,
        'remark': _remarkBySession[sid] ?? '',
      });
    }
    try {
      final out = await AttendanceRepository.saveSubjectSlotAttendance(
        subjectTimetableId: _slotId!,
        dateYmd: _ymd(_date),
        rows: rows,
      );
      if (!mounted) return;
      if (out['success'] == true) {
        SiChrome.showMessage(context, out['message']?.toString() ?? 'Saved.');
        await _loadGrid();
      } else {
        SiChrome.showMessage(context, out['error']?.toString() ?? 'Save failed.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SiThemedPageScaffold(
      title: 'Period attendance',
      subtitle: 'Uses the same slots as the web timetable',
      child: _mastersLoading
          ? const SiLoadingBlock(message: 'Loading classes & types…')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: AttendanceUi.filterCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AttendanceUi.sectionTitle(context, 'Class & date'),
                        DropdownButtonFormField<int>(
                          isExpanded: true,
                          decoration: SiChrome.inputDecoration(context, labelText: 'Class'),
                          // ignore: deprecated_member_use
                          value: _classId,
                          items: _classes
                              .map(
                                (c) => DropdownMenuItem<int>(
                                  value: c.id,
                                  child: Text(c.className, overflow: TextOverflow.ellipsis),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => _onClassChanged(v),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          isExpanded: true,
                          decoration: SiChrome.inputDecoration(context, labelText: 'Section'),
                          // ignore: deprecated_member_use
                          value: _sectionId > 0 ? _sectionId : null,
                          items: _sections
                              .map(
                                (s) => DropdownMenuItem<int>(
                                  value: s.id,
                                  child: Text(s.sectionName, overflow: TextOverflow.ellipsis),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _sectionId = v ?? 0;
                              _slots = [];
                              _slotId = null;
                              _rows = [];
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        AttendanceUi.datePickerButton(
                          context: context,
                          onPressed: _pickDate,
                          dateYmd: _ymd(_date),
                        ),
                        AttendanceUi.inlineHint(
                          context,
                          'The calendar date sets the weekday used to resolve timetable periods.',
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _slotsLoading ? null : _loadSlots,
                                style: AttendanceUi.accentTealButton(),
                                icon: _slotsLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.view_timeline_rounded),
                                label: const Text('Load periods'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _gridLoading ? null : _loadGrid,
                                style: AttendanceUi.primaryBlueButton(),
                                icon: _gridLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.group_rounded),
                                label: const Text('Load class'),
                              ),
                            ),
                          ],
                        ),
                        if (_slots.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          AttendanceUi.sectionTitle(context, 'Period'),
                          DropdownButtonFormField<int>(
                            isExpanded: true,
                            decoration: SiChrome.inputDecoration(context, labelText: 'Timetable slot'),
                            // ignore: deprecated_member_use
                            value: _slotId,
                            items: _slots
                                .map(
                                  (s) => DropdownMenuItem<int>(
                                    value: s.subjectTimetableId,
                                    child: Text(
                                      '${s.subjectName} (${s.timeFrom}–${s.timeTo})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              setState(() {
                                _slotId = v;
                                _rows = [];
                                _typeBySession.clear();
                                _remarkBySession.clear();
                              });
                            },
                          ),
                        ],
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: (_saving || _rows.isEmpty) ? null : _save,
                          style: AttendanceUi.softSaveButton(),
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryBlue,
                                  ),
                                )
                              : const Icon(Icons.save_rounded),
                          label: const Text('Save this period'),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 24),
                Expanded(child: _listBody(theme)),
              ],
            ),
    );
  }

  Widget _listBody(ThemeData theme) {
    if (_rows.isEmpty) {
      return SiEmptyState(
        icon: Icons.schedule_outlined,
        title: 'No class list loaded',
        message:
            'Load periods for the date, choose a slot, then tap Load class to mark attendance for that period.',
      );
    }
    return RefreshIndicator(
      color: AppColors.primaryBlue,
      onRefresh: _loadGrid,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        itemCount: _rows.length,
        itemBuilder: (context, i) {
          final row = _rows[i];
          final sid = row.studentSessionId;
          final cur = _typeBySession[sid];
          return AttendanceUi.entryCard(
            context: context,
            leadingIcon: Icons.school_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Admission ${row.admissionNo}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  decoration: SiChrome.inputDecoration(context, labelText: 'Status'),
                  // ignore: deprecated_member_use
                  value: cur != null && _types.any((t) => t.id == cur) ? cur : _defaultTypeId(),
                  items: _types
                      .map(
                        (t) => DropdownMenuItem<int>(
                          value: t.id,
                          child: Text(t.type, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setState(() => _typeBySession[sid] = v);
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: ValueKey<String>('sub-rmk-$sid-${_slotId!}-${_ymd(_date)}'),
                  initialValue: _remarkBySession[sid] ?? '',
                  onChanged: (v) => _remarkBySession[sid] = v,
                  decoration: SiChrome.inputDecoration(
                    context,
                    labelText: 'Remark (optional)',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
