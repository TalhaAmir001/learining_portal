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

class AcTeacherTimetableScreen extends StatefulWidget {
  const AcTeacherTimetableScreen({super.key});

  @override
  State<AcTeacherTimetableScreen> createState() => _AcTeacherTimetableScreenState();
}

class _AcTeacherTimetableScreenState extends State<AcTeacherTimetableScreen> {
  AcTimetableMeta? _meta;
  bool _metaLoading = true;
  AcTimetablePayload? _payload;
  bool _ttLoading = false;
  bool _weekly = true;
  String _dailyDay = 'Monday';
  int? _staffId;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    setState(() {
      _metaLoading = true;
      _meta = null;
    });
    final auth = context.read<AuthProvider>();
    final m = await AcademicsRepository.getTimetableMeta();
    if (!mounted) return;
    final isAdmin = auth.userType == UserType.admin;
    final self = auth.portalStaffId;
    int? sid = self;
    if (isAdmin) {
      sid = (m != null && m.staffTeachers.isNotEmpty) ? m.staffTeachers.first.id : null;
    } else {
      sid = self ?? ((m != null && m.staffTeachers.isNotEmpty) ? m.staffTeachers.first.id : null);
    }
    setState(() {
      _meta = m;
      _metaLoading = false;
      _staffId = sid;
    });
    await _loadTimetable();
  }

  Future<void> _loadTimetable() async {
    final sid = _staffId;
    if (sid == null || sid <= 0) {
      setState(() {
        _ttLoading = false;
        _payload = AcTimetablePayload(success: false, error: 'No staff selected.', dayOrder: const []);
      });
      return;
    }
    setState(() => _ttLoading = true);
    final p = await AcademicsRepository.getTeacherTimetable(
      staffId: sid,
      day: _weekly ? null : _dailyDay,
    );
    if (!mounted) return;
    setState(() {
      _payload = p;
      _ttLoading = false;
    });
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
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.userType == UserType.admin;
    final m = _meta;

    return SiThemedPageScaffold(
      title: 'Teacher timetable',
      subtitle: isAdmin ? 'Pick a teacher' : 'Your teaching periods',
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
                                  if (isAdmin)
                                    DropdownButtonFormField<int>(
                                      isExpanded: true,
                                      decoration: SiChrome.inputDecoration(context, labelText: 'Teacher'),
                                      value: _staffId != null && m.staffTeachers.any((s) => s.id == _staffId)
                                          ? _staffId
                                          : null,
                                      items: m.staffTeachers
                                          .map(
                                            (s) => DropdownMenuItem(
                                              value: s.id,
                                              child: Text(s.displayName, overflow: TextOverflow.ellipsis),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) async {
                                        setState(() => _staffId = v);
                                        await _loadTimetable();
                                      },
                                    ),
                                  if (isAdmin) const SizedBox(height: 12),
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
