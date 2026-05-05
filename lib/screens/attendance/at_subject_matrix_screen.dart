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

/// Read-only matrix: `admin/subjectattendence/reportbydate` style overview.
class AtSubjectMatrixScreen extends StatefulWidget {
  const AtSubjectMatrixScreen({super.key});

  @override
  State<AtSubjectMatrixScreen> createState() => _AtSubjectMatrixScreenState();
}

class _AtSubjectMatrixScreenState extends State<AtSubjectMatrixScreen> {
  List<SiClassModel> _classes = [];
  List<SiSectionModel> _sections = [];
  List<AtTypeModel> _types = [];
  int? _classId;
  int _sectionId = 0;
  DateTime _date = DateTime.now();
  bool _mastersLoading = true;

  List<AtMatrixSlotModel> _slots = [];
  List<AtMatrixStudentModel> _students = [];
  String _dayLabel = '';
  bool _loading = false;
  bool _didLoadOnce = false;

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
      _students = [];
      _dayLabel = '';
      _didLoadOnce = false;
    });
    if (id == null || id <= 0) return;
    final sec = await StudentInformationRepository.getSections(classId: id);
    if (!mounted) return;
    setState(() => _sections = sec);
  }

  String _typeShort(int? id) {
    if (id == null) return '—';
    for (final t in _types) {
      if (t.id == id) {
        final s = t.keyValue.trim();
        if (s.isNotEmpty) return s.length > 3 ? s.substring(0, 3) : s;
        if (t.type.isNotEmpty) return t.type.length > 4 ? t.type.substring(0, 4) : t.type;
      }
    }
    return '$id';
  }

  Future<void> _load() async {
    if (_classId == null || _classId! <= 0 || _sectionId <= 0) {
      SiChrome.showMessage(context, 'Choose class and section.');
      return;
    }
    setState(() => _loading = true);
    final r = await AttendanceRepository.getSubjectDayMatrix(
      classId: _classId!,
      sectionId: _sectionId,
      dateYmd: _ymd(_date),
    );
    if (!mounted) return;
    final slots = <AtMatrixSlotModel>[];
    final studs = <AtMatrixStudentModel>[];
    var day = '';
    if (r['success'] == true) {
      day = r['day']?.toString() ?? '';
      if (r['slots'] is List) {
        for (final e in r['slots'] as List<dynamic>) {
          slots.add(AtMatrixSlotModel.fromJson(e as Map<String, dynamic>));
        }
      }
      if (r['students'] is List) {
        for (final e in r['students'] as List<dynamic>) {
          studs.add(AtMatrixStudentModel.fromJson(e as Map<String, dynamic>));
        }
      }
    }
    setState(() {
      _slots = slots;
      _students = studs;
      _dayLabel = day;
      _loading = false;
      _didLoadOnce = true;
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
        _students = [];
        _dayLabel = '';
        _didLoadOnce = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SiThemedPageScaffold(
      title: 'Period matrix',
      subtitle: 'Subject marks across all periods for that weekday',
      child: _mastersLoading
          ? const SiLoadingBlock(message: 'Loading…')
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
                              _students = [];
                              _dayLabel = '';
                              _didLoadOnce = false;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        AttendanceUi.datePickerButton(
                          context: context,
                          onPressed: _pickDate,
                          dateYmd: _ymd(_date),
                        ),
                        if (_dayLabel.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.accentTeal.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.accentTeal.withOpacity(0.35),
                                ),
                              ),
                              child: Text(
                                'Weekday · $_dayLabel',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: AppColors.primaryBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loading ? null : _load,
                          style: AttendanceUi.primaryBlueButton(),
                          icon: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.grid_on_rounded),
                          label: const Text('Load matrix'),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 24),
                Expanded(child: _matrixBody(theme)),
              ],
            ),
    );
  }

  Widget _matrixBody(ThemeData theme) {
    if (!_didLoadOnce) {
      return SiEmptyState(
        icon: Icons.table_chart_outlined,
        title: 'Matrix not loaded',
        message: 'Choose class, section, and date, then tap Load matrix to preview period attendance.',
      );
    }
    if (_slots.isEmpty) {
      return SiEmptyState(
        icon: Icons.event_busy_outlined,
        title: 'No periods this day',
        message:
            'There are no timetable slots for this class on the weekday of ${_ymd(_date)}. Try another date.',
      );
    }
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      elevation: 0,
      color: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.textSecondary.withOpacity(0.12),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: SingleChildScrollView(
                  child: Table(
                    defaultColumnWidth: const IntrinsicColumnWidth(),
                    border: TableBorder.all(
                      color: AppColors.textSecondary.withOpacity(0.15),
                    ),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryBlue.withOpacity(0.12),
                              AppColors.secondaryPurple.withOpacity(0.08),
                            ],
                          ),
                        ),
                        children: [
                          _cell(theme, 'Student', header: true),
                          ..._slots.map(
                            (s) => _cell(
                              theme,
                              '${s.subjectName}\n${s.timeLabel}',
                              header: true,
                            ),
                          ),
                        ],
                      ),
                      ..._students.map((stu) {
                        return TableRow(
                          children: [
                            _cell(
                              theme,
                              '${stu.displayName}\n${stu.admissionNo}',
                              header: false,
                              narrow: true,
                            ),
                            ..._slots.map((s) {
                              final tid = stu.bySlotTypeIds[s.subjectTimetableId];
                              return _cell(theme, _typeShort(tid), header: false);
                            }),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _cell(ThemeData theme, String text, {required bool header, bool narrow = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: narrow ? 10 : 10,
        vertical: header ? 12 : 10,
      ),
      child: SizedBox(
        width: narrow ? 148 : 76,
        child: Text(
          text,
          style: header
              ? theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue,
                  height: 1.25,
                )
              : theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
        ),
      ),
    );
  }
}
