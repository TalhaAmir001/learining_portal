import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/academics/admin_academics_models.dart';
import 'package:learining_portal/network/domain/academics_repository.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';

class AdminAssignClassTeacherScreen extends StatefulWidget {
  const AdminAssignClassTeacherScreen({super.key});

  @override
  State<AdminAssignClassTeacherScreen> createState() =>
      _AdminAssignClassTeacherScreenState();
}

class _AdminAssignClassTeacherScreenState
    extends State<AdminAssignClassTeacherScreen> {
  bool _loading = true;
  String? _error;

  List<AdminAcSimpleItem> _classes = const [];
  List<AdminAcSimpleItem> _sections = const [];
  List<AdminAcTeacherItem> _teachers = const [];

  // key = classId:sectionId
  final Map<String, List<int>> _assignedStaffIds = {};
  List<AdminAcClassTeacherGroup> _groups = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _assignedStaffIds.clear();
      _groups = const [];
    });
    try {
      final meta = await AcademicsRepository.getAdminAcademicsMeta();
      if (!meta.success) {
        _error = meta.error ?? 'Failed to load meta.';
        _classes = const [];
        _sections = const [];
        _teachers = const [];
      } else {
        _classes = meta.classes;
        _sections = meta.sections;
        _teachers = meta.teachers;
      }

      final groups = await AcademicsRepository.getClassTeachersAdmin();
      _groups = groups;
      for (final g in groups) {
        _assignedStaffIds[_key(g.classId, g.sectionId)] =
            g.teachers.map((t) => t.staffId).toList()..sort();
      }
    } catch (e) {
      _error = e.toString();
    }

    if (mounted) setState(() => _loading = false);
  }

  String _key(int classId, int sectionId) => '$classId:$sectionId';

  Future<void> _openEditor() async {
    if (_classes.isEmpty || _sections.isEmpty || _teachers.isEmpty) {
      SiChrome.showMessage(context, 'Meta is empty; cannot assign teachers.');
      return;
    }

    int classId = _classes.first.id;
    int sectionId = _sections.first.id;
    final selected = <int>{};

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            // hydrate selection when class/section changes
            void syncFromAssigned() {
              final list = _assignedStaffIds[_key(classId, sectionId)] ?? const [];
              selected
                ..clear()
                ..addAll(list);
            }

            syncFromAssigned();

            return AlertDialog(
              title: const Text('Assign Class Teacher'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InputDecorator(
                              decoration: SiChrome.inputDecoration(
                                ctx,
                                labelText: 'Class',
                                prefixIcon: const Icon(Icons.class_rounded),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: classId,
                                  isExpanded: true,
                                  items: _classes
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c.id,
                                          child: Text(c.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) {
                                    if (v == null) return;
                                    setLocal(() => classId = v);
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InputDecorator(
                              decoration: SiChrome.inputDecoration(
                                ctx,
                                labelText: 'Section',
                                prefixIcon: const Icon(Icons.view_list_rounded),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: sectionId,
                                  isExpanded: true,
                                  items: _sections
                                      .map(
                                        (s) => DropdownMenuItem(
                                          value: s.id,
                                          child: Text(s.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) {
                                    if (v == null) return;
                                    setLocal(() => sectionId = v);
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Teachers',
                          style: Theme.of(ctx)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceWhite,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.textSecondary.withOpacity(0.12),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _teachers.map((t) {
                            final isOn = selected.contains(t.id);
                            return CheckboxListTile(
                              value: isOn,
                              onChanged: (v) {
                                setLocal(() {
                                  if (v == true) {
                                    selected.add(t.id);
                                  } else {
                                    selected.remove(t.id);
                                  }
                                });
                              },
                              title: Text(t.displayName),
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      final r = await AcademicsRepository.setClassTeachers(
                        classId: classId,
                        sectionId: sectionId,
                        staffIds: selected.toList()..sort(),
                      );
                      if (r['success'] == true) {
                        _assignedStaffIds[_key(classId, sectionId)] =
                            selected.toList()..sort();
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } else {
                        if (ctx.mounted) {
                          SiChrome.showMessage(
                            ctx,
                            (r['error'] ?? 'Save failed').toString(),
                          );
                        }
                      }
                    } catch (e) {
                      if (ctx.mounted) SiChrome.showMessage(ctx, e.toString());
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return SiThemedPageScaffold(
      title: 'Assign Class Teacher',
      subtitle: 'Admin',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          color: Colors.white,
          onPressed: _loading ? null : _load,
        ),
        IconButton(
          icon: const Icon(Icons.edit_rounded),
          color: Colors.white,
          onPressed: _loading ? null : _openEditor,
        ),
      ],
      child: _loading
          ? const SiLoadingBlock(message: 'Loading…')
          : _error != null
              ? SiEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load',
                  message: _error,
                )
              : _groups.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      child: SiEmptyState(
                        icon: Icons.supervisor_account_outlined,
                        title: 'No assignments yet',
                        message:
                            'Tap the edit button to select a class, section, and teachers.',
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.primaryBlue,
                      onRefresh: _load,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                        itemCount: _groups.length,
                        itemBuilder: (context, i) {
                          final g = _groups[i];
                          final names = g.teachers
                              .map((t) =>
                                  ('${t.name} ${t.surname}').trim())
                              .where((s) => s.isNotEmpty)
                              .toList();
                          final subtitle = names.isEmpty
                              ? 'No teacher assigned'
                              : names.join(', ');
                          return SiResultCard(
                            title: '${g.className} · ${g.sectionName}',
                            subtitle: subtitle,
                            leadingIcon: Icons.supervisor_account_rounded,
                            onTap: _openEditor,
                          );
                        },
                      ),
                    ),
    );
  }
}

