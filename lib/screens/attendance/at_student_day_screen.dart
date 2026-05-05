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

/// Portal `admin/stuattendence/index` — class, section, date, save daily attendance.
class AtStudentDayScreen extends StatefulWidget {
  const AtStudentDayScreen({super.key});

  @override
  State<AtStudentDayScreen> createState() => _AtStudentDayScreenState();
}

class _AtStudentDayScreenState extends State<AtStudentDayScreen> {
  List<SiClassModel> _classes = [];
  List<SiSectionModel> _sections = [];
  List<AtTypeModel> _types = [];
  int? _classId;
  int _sectionId = 0;
  DateTime _date = DateTime.now();
  bool _mastersLoading = true;

  List<AtStudentDayRowModel> _rows = [];
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

  Future<void> _loadGrid() async {
    if (_classId == null || _classId! <= 0) {
      SiChrome.showMessage(context, 'Choose a class.');
      return;
    }
    if (_sectionId <= 0) {
      SiChrome.showMessage(context, 'Choose a section.');
      return;
    }
    setState(() => _gridLoading = true);
    final r = await AttendanceRepository.getStudentDayAttendance(
      classId: _classId!,
      sectionId: _sectionId,
      dateYmd: _ymd(_date),
    );
    if (!mounted) return;
    final list = <AtStudentDayRowModel>[];
    if (r['success'] == true && r['students'] is List) {
      for (final e in r['students'] as List<dynamic>) {
        list.add(AtStudentDayRowModel.fromJson(e as Map<String, dynamic>));
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
    } else if (list.isEmpty) {
      SiChrome.showMessage(context, 'No active students in this class/section.');
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    if (_rows.isEmpty) {
      SiChrome.showMessage(context, 'Load the register first.');
      return;
    }
    final def = _defaultTypeId();
    if (def == null) {
      SiChrome.showMessage(context, 'No attendance types from server.');
      return;
    }
    setState(() => _saving = true);
    final rows = <Map<String, dynamic>>[];
    for (final row in _rows) {
      final sid = row.studentSessionId;
      final tid = _typeBySession[sid] ?? def;
      rows.add({
        'student_session_id': sid,
        'attendence_type_id': tid,
        'remark': _remarkBySession[sid] ?? '',
        'feedback': '',
        'in_time': null,
        'out_time': null,
      });
    }
    try {
      final out = await AttendanceRepository.saveStudentDayAttendance(
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
      title: 'Student attendance',
      subtitle: 'One mark per student for the selected date',
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
                              _rows = [];
                              _typeBySession.clear();
                              _remarkBySession.clear();
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
                          'Marks apply to the whole day for each student (same as web admin).',
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _gridLoading ? null : _loadGrid,
                                style: AttendanceUi.accentTealButton(),
                                icon: _gridLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.groups_rounded),
                                label: const Text('Load register'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: (_saving || _rows.isEmpty) ? null : _save,
                                style: AttendanceUi.primaryBlueButton(),
                                icon: _saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save_rounded),
                                label: const Text('Save'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_types.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      'Could not load attendance types from the server.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
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
        icon: Icons.event_note_outlined,
        title: 'No register loaded',
        message:
            'Choose class, section, and session date, then tap Load register to edit attendance.',
      );
    }
    return RefreshIndicator(
      color: AppColors.primaryBlue,
      onRefresh: _loadGrid,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        itemCount: _rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 0),
        itemBuilder: (context, i) {
          final row = _rows[i];
          final sid = row.studentSessionId;
          final cur = _typeBySession[sid];
          return AttendanceUi.entryCard(
            context: context,
            leadingIcon: Icons.person_rounded,
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
                  'Admission ${row.admissionNo} · Roll ${row.rollNo}',
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
                  key: ValueKey<String>('rmk-$sid-${_ymd(_date)}'),
                  initialValue: _remarkBySession[sid] ?? '',
                  onChanged: (v) => _remarkBySession[sid] = v,
                  decoration: SiChrome.inputDecoration(
                    context,
                    labelText: 'Remark (optional)',
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
