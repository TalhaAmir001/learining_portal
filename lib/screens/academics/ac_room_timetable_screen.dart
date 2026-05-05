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

class AcRoomTimetableScreen extends StatefulWidget {
  const AcRoomTimetableScreen({super.key});

  @override
  State<AcRoomTimetableScreen> createState() => _AcRoomTimetableScreenState();
}

class _AcRoomTimetableScreenState extends State<AcRoomTimetableScreen> {
  AcTimetableMeta? _meta;
  bool _metaLoading = true;
  AcTimetablePayload? _payload;
  bool _ttLoading = false;
  bool _weekly = true;
  String _dailyDay = 'Monday';
  String _room = '';

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    setState(() => _metaLoading = true);
    final m = await AcademicsRepository.getTimetableMeta();
    if (!mounted) return;
    final firstRoom = (m != null && m.rooms.isNotEmpty) ? m.rooms.first : '';
    setState(() {
      _meta = m;
      _metaLoading = false;
      if (_room.isEmpty && firstRoom.isNotEmpty) {
        _room = firstRoom;
      }
    });
    await _loadTimetable();
  }

  Future<void> _loadTimetable() async {
    if (_room.trim().isEmpty) {
      setState(() {
        _ttLoading = false;
        _payload = AcTimetablePayload(success: false, error: 'Pick a room.', dayOrder: const []);
      });
      return;
    }
    setState(() => _ttLoading = true);
    final p = await AcademicsRepository.getRoomTimetable(
      roomNo: _room.trim(),
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
    final isAdmin = context.watch<AuthProvider>().userType == UserType.admin;
    final m = _meta;

    return SiThemedPageScaffold(
      title: 'Room timetable',
      subtitle: 'Filter by room number',
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
                                  DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    decoration: SiChrome.inputDecoration(context, labelText: 'Room'),
                                    value: _room.isNotEmpty && m.rooms.contains(_room) ? _room : null,
                                    items: m.rooms
                                        .map(
                                          (r) => DropdownMenuItem(
                                            value: r,
                                            child: Text(r, overflow: TextOverflow.ellipsis),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) async {
                                      setState(() => _room = v ?? '');
                                      await _loadTimetable();
                                    },
                                  ),
                                  if (m.rooms.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text(
                                        'No rooms in timetable yet. Add room numbers when editing slots on web or in the app.',
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                      ),
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
