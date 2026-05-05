import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/attendance/attendance_models.dart';
import 'package:learining_portal/network/domain/attendance_repository.dart';
import 'package:learining_portal/screens/attendance/attendance_ui.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Portal `admin/staffattendance/index` — role + date.
class AtStaffDayScreen extends StatefulWidget {
  const AtStaffDayScreen({super.key});

  @override
  State<AtStaffDayScreen> createState() => _AtStaffDayScreenState();
}

class _AtStaffDayScreenState extends State<AtStaffDayScreen> {
  List<AtStaffRoleModel> _roles = [];
  List<AtTypeModel> _types = [];
  String? _roleName;
  DateTime _date = DateTime.now();
  bool _mastersLoading = true;

  List<AtStaffDayRowModel> _rows = [];
  final Map<int, int?> _typeByStaff = {};
  final Map<int, String> _remarkByStaff = {};
  final Map<int, String> _inByStaff = {};
  final Map<int, String> _outByStaff = {};
  bool _gridLoading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadMasters();
  }

  Future<void> _loadMasters() async {
    setState(() => _mastersLoading = true);
    final r = await AttendanceRepository.getStaffRoles();
    final t = await AttendanceRepository.getStaffAttendanceTypes();
    if (!mounted) return;
    setState(() {
      _roles = r;
      _types = t;
      _roleName = r.isNotEmpty ? r.first.roleName : null;
      _mastersLoading = false;
    });
  }

  int? _defaultTypeId() {
    for (final x in _types) {
      if (x.keyValue.toUpperCase() == 'P') return x.id;
    }
    return _types.isNotEmpty ? _types.first.id : null;
  }

  Future<void> _loadGrid() async {
    final role = _roleName;
    if (role == null || role.isEmpty) {
      SiChrome.showMessage(context, 'Choose a role.');
      return;
    }
    setState(() => _gridLoading = true);
    final r = await AttendanceRepository.getStaffDayAttendance(
      roleName: role,
      dateYmd: _ymd(_date),
    );
    if (!mounted) return;
    final list = <AtStaffDayRowModel>[];
    if (r['success'] == true && r['staff'] is List) {
      for (final e in r['staff'] as List<dynamic>) {
        list.add(AtStaffDayRowModel.fromJson(e as Map<String, dynamic>));
      }
    }
    final def = _defaultTypeId();
    _typeByStaff.clear();
    _remarkByStaff.clear();
    _inByStaff.clear();
    _outByStaff.clear();
    for (final row in list) {
      _typeByStaff[row.staffId] = row.staffAttendanceTypeId ?? def;
      _remarkByStaff[row.staffId] = row.remark;
      _inByStaff[row.staffId] = row.inTime ?? '';
      _outByStaff[row.staffId] = row.outTime ?? '';
    }
    setState(() {
      _rows = list;
      _gridLoading = false;
    });
    if (r['success'] != true) {
      SiChrome.showMessage(context, r['error']?.toString() ?? 'Failed to load.');
    } else if (list.isEmpty) {
      SiChrome.showMessage(context, 'No staff rows for this role.');
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
    if (def == null) return;
    setState(() => _saving = true);
    final rows = <Map<String, dynamic>>[];
    for (final row in _rows) {
      final id = row.staffId;
      final tin = (_inByStaff[id] ?? '').trim();
      final tout = (_outByStaff[id] ?? '').trim();
      rows.add({
        'staff_id': id,
        'staff_attendance_type_id': _typeByStaff[id] ?? def,
        'remark': _remarkByStaff[id] ?? '',
        if (tin.isNotEmpty) 'in_time': tin,
        if (tout.isNotEmpty) 'out_time': tout,
      });
    }
    try {
      final out = await AttendanceRepository.saveStaffDayAttendance(
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
      title: 'Staff attendance',
      subtitle: 'Same roles as the web HR attendance screen',
      child: _mastersLoading
          ? const SiLoadingBlock(message: 'Loading roles & types…')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: AttendanceUi.filterCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AttendanceUi.sectionTitle(context, 'Role & date'),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: SiChrome.inputDecoration(context, labelText: 'Role'),
                          // ignore: deprecated_member_use
                          value: _roleName,
                          items: _roles
                              .map(
                                (e) => DropdownMenuItem<String>(
                                  value: e.roleName,
                                  child: Text(e.roleName, overflow: TextOverflow.ellipsis),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _roleName = v;
                              _rows = [];
                              _typeByStaff.clear();
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        AttendanceUi.datePickerButton(
                          context: context,
                          onPressed: _pickDate,
                          dateYmd: _ymd(_date),
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
                const Divider(height: 24),
                Expanded(child: _listBody(theme)),
              ],
            ),
    );
  }

  Widget _listBody(ThemeData theme) {
    if (_rows.isEmpty) {
      return SiEmptyState(
        icon: Icons.badge_outlined,
        title: 'No register loaded',
        message: 'Select a staff role and date, then tap Load register.',
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
          final id = row.staffId;
          final cur = _typeByStaff[id];
          return AttendanceUi.entryCard(
            context: context,
            leadingIcon: Icons.badge_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  row.employeeId.isNotEmpty ? 'Employee ID ${row.employeeId}' : ' ',
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
                    setState(() => _typeByStaff[id] = v);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey<String>('in-$id-${_ymd(_date)}'),
                        initialValue: _inByStaff[id] ?? '',
                        onChanged: (v) => _inByStaff[id] = v,
                        decoration: SiChrome.inputDecoration(
                          context,
                          labelText: 'In (optional)',
                          hintText: '08:30',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        key: ValueKey<String>('out-$id-${_ymd(_date)}'),
                        initialValue: _outByStaff[id] ?? '',
                        onChanged: (v) => _outByStaff[id] = v,
                        decoration: SiChrome.inputDecoration(
                          context,
                          labelText: 'Out (optional)',
                          hintText: '15:30',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: ValueKey<String>('stf-rmk-$id-${_ymd(_date)}'),
                  initialValue: _remarkByStaff[id] ?? '',
                  onChanged: (v) => _remarkByStaff[id] = v,
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
