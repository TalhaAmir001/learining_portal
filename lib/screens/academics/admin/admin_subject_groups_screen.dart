import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/academics/admin_academics_models.dart';
import 'package:learining_portal/network/domain/academics_repository.dart';
import 'package:learining_portal/screens/academics/admin/admin_subject_group_edit_screen.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/api_client.dart';
import 'package:learining_portal/utils/app_colors.dart';

class _SubjectGroupItem {
  _SubjectGroupItem({
    required this.id,
    required this.name,
    required this.description,
    required this.subjectIds,
    required this.classSectionIds,
  });

  final int id;
  final String name;
  final String description;
  final List<int> subjectIds;
  final List<int> classSectionIds;

  factory _SubjectGroupItem.fromJson(Map<String, dynamic> json) {
    final subjects = (json['subjects'] as List?) ?? const [];
    final cs = (json['class_sections'] as List?) ?? const [];
    return _SubjectGroupItem(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      subjectIds: subjects
          .whereType<Map>()
          .map((e) => int.tryParse(e['subject_id']?.toString() ?? '') ?? 0)
          .where((v) => v > 0)
          .toList(),
      classSectionIds: cs
          .whereType<Map>()
          .map((e) => int.tryParse(e['class_section_id']?.toString() ?? '') ?? 0)
          .where((v) => v > 0)
          .toList(),
    );
  }
}

class AdminSubjectGroupsScreen extends StatefulWidget {
  const AdminSubjectGroupsScreen({super.key});

  @override
  State<AdminSubjectGroupsScreen> createState() => _AdminSubjectGroupsScreenState();
}

class _AdminSubjectGroupsScreenState extends State<AdminSubjectGroupsScreen> {
  bool _loading = true;
  String? _error;
  List<_SubjectGroupItem> _groups = const [];

  AdminAcMetaPayload? _meta;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _groups = const [];
    });
    try {
      _meta = await AcademicsRepository.getAdminAcademicsMeta();
      final r = await ApiClient.get(
        endpoint: '/mobile_apis/get_ac_subject_groups_admin.php',
      );
      if (r['success'] == true) {
        final raw = r['items'];
        if (raw is List) {
          _groups = raw
              .whereType<Map>()
              .map((e) => _SubjectGroupItem.fromJson(e.cast<String, dynamic>()))
              .toList();
        }
      } else {
        _error = (r['error'] ?? 'Failed to load subject groups').toString();
      }
      if (_groups.isEmpty && _error == null) {
        _error = 'No subject groups found.';
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  String _subjectLabel(int id) {
    final s = _meta?.subjects.where((x) => x.id == id).toList();
    if (s == null || s.isEmpty) return 'Subject $id';
    final v = s.first;
    return v.code.isNotEmpty ? '${v.name} (${v.code})' : v.name;
  }

  String _classSectionLabel(int classSectionId) {
    final cs = _meta?.classSections.where((x) => x.id == classSectionId).toList();
    if (cs == null || cs.isEmpty) return 'ClassSection $classSectionId';
    return cs.first.label;
  }

  Future<void> _openEditor({_SubjectGroupItem? item}) async {
    final meta = _meta;
    if (meta == null || !meta.success) {
      SiChrome.showMessage(context, meta?.error ?? 'Meta not available');
      return;
    }

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminSubjectGroupEditScreen(
          args: AdminSubjectGroupEditArgs(
            id: item?.id,
            initialName: item?.name,
            initialDescription: item?.description,
            initialSubjectIds: item?.subjectIds,
            initialClassSectionIds: item?.classSectionIds,
          ),
        ),
      ),
    );

    if (saved == true) await _load();
  }

  Future<void> _delete(_SubjectGroupItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete subject group?'),
        content: Text('This will delete "${item.name}".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final r = await AcademicsRepository.deleteSubjectGroup(id: item.id);
      if (r['success'] == true) {
        await _load();
      } else if (mounted) {
        SiChrome.showMessage(context, (r['error'] ?? 'Delete failed').toString());
      }
    } catch (e) {
      if (mounted) SiChrome.showMessage(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SiThemedPageScaffold(
      title: 'Subject Group',
      subtitle: 'Manage subject groups',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          color: Colors.white,
          onPressed: _loading ? null : _load,
        ),
        IconButton(
          icon: const Icon(Icons.add_rounded),
          color: Colors.white,
          onPressed: _loading ? null : () => _openEditor(),
        ),
      ],
      child: _loading
          ? const SiLoadingBlock(message: 'Loading…')
          : _groups.isEmpty
              ? SiEmptyState(
                  icon: Icons.grid_view_outlined,
                  title: 'No subject groups',
                  message: _error,
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
                      final subj = g.subjectIds.take(4).map(_subjectLabel).toList();
                      final sec = g.classSectionIds.take(3).map(_classSectionLabel).toList();
                      final subtitle = [
                        if (subj.isNotEmpty) 'Subjects: ${subj.join(', ')}${g.subjectIds.length > 4 ? '…' : ''}',
                        if (sec.isNotEmpty) 'Sections: ${sec.join(', ')}${g.classSectionIds.length > 3 ? '…' : ''}',
                      ].join('\n');
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        color: AppColors.surfaceWhite,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: AppColors.textSecondary.withOpacity(0.12)),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.grid_view_rounded, color: AppColors.primaryBlue),
                          title: Text(g.name.isEmpty ? '(unnamed)' : g.name),
                          subtitle: Text(subtitle.isEmpty ? 'ID ${g.id}' : subtitle),
                          isThreeLine: subtitle.contains('\n'),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                tooltip: 'Edit',
                                onPressed: () => _openEditor(item: g),
                                icon: const Icon(Icons.edit_rounded),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: () => _delete(g),
                                icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade700),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

