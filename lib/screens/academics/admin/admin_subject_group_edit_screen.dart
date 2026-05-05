import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/academics/admin_academics_models.dart';
import 'package:learining_portal/network/domain/academics_repository.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';

class AdminSubjectGroupEditArgs {
  const AdminSubjectGroupEditArgs({
    this.id,
    this.initialName,
    this.initialDescription,
    this.initialSubjectIds,
    this.initialClassSectionIds,
  });

  final int? id;
  final String? initialName;
  final String? initialDescription;
  final List<int>? initialSubjectIds;
  final List<int>? initialClassSectionIds;
}

class AdminSubjectGroupEditScreen extends StatefulWidget {
  const AdminSubjectGroupEditScreen({super.key, this.args});

  final AdminSubjectGroupEditArgs? args;

  @override
  State<AdminSubjectGroupEditScreen> createState() =>
      _AdminSubjectGroupEditScreenState();
}

class _AdminSubjectGroupEditScreenState
    extends State<AdminSubjectGroupEditScreen> {
  bool _loading = true;
  String? _error;
  AdminAcMetaPayload? _meta;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;

  final Set<int> _subjectIds = <int>{};
  final Set<int> _classSectionIds = <int>{};

  bool _saving = false;

  bool get _isEdit => (widget.args?.id ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.args?.initialName ?? '');
    _descCtrl =
        TextEditingController(text: widget.args?.initialDescription ?? '');
    _subjectIds.addAll(widget.args?.initialSubjectIds ?? const []);
    _classSectionIds.addAll(widget.args?.initialClassSectionIds ?? const []);
    _loadMeta();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final meta = await AcademicsRepository.getAdminAcademicsMeta();
      if (!meta.success) {
        _error = meta.error ?? 'Failed to load meta.';
      }
      _meta = meta;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  String _subjectLabel(AdminAcSubjectItem s) {
    if (s.code.isNotEmpty) return '${s.name} (${s.code})';
    return s.name;
  }

  Future<void> _save() async {
    final meta = _meta;
    if (meta == null || !meta.success) {
      SiChrome.showMessage(context, meta?.error ?? 'Meta not available');
      return;
    }
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      SiChrome.showMessage(context, 'Name is required');
      return;
    }
    if (_subjectIds.isEmpty) {
      SiChrome.showMessage(context, 'Select at least one subject');
      return;
    }
    if (_classSectionIds.isEmpty) {
      SiChrome.showMessage(context, 'Select at least one class section');
      return;
    }

    setState(() => _saving = true);
    try {
      final r = await AcademicsRepository.upsertSubjectGroup(
        id: widget.args?.id,
        name: name,
        description: _descCtrl.text.trim(),
        subjectIds: _subjectIds.toList(),
        classSectionIds: _classSectionIds.toList(),
      );
      if (!mounted) return;
      if (r['success'] == true) {
        Navigator.pop<bool>(context, true);
      } else {
        SiChrome.showMessage(context, (r['error'] ?? 'Save failed').toString());
      }
    } catch (e) {
      if (!mounted) return;
      SiChrome.showMessage(context, e.toString());
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta;
    return SiThemedPageScaffold(
      title: _isEdit ? 'Edit Subject Group' : 'Add Subject Group',
      subtitle: 'Admin',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          color: Colors.white,
          onPressed: _loading || _saving ? null : _loadMeta,
        ),
        IconButton(
          icon: const Icon(Icons.save_rounded),
          color: Colors.white,
          onPressed: _loading || _saving ? null : _save,
        ),
      ],
      child: _loading
          ? const SiLoadingBlock(message: 'Loading…')
          : (meta == null || !meta.success)
              ? SiEmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Could not load',
                  message: _error ?? meta?.error,
                )
              : Stack(
                  children: [
                    ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      children: [
                        Card(
                          elevation: 0,
                          color: AppColors.surfaceWhite,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: AppColors.textSecondary.withOpacity(0.12),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _nameCtrl,
                                  decoration: SiChrome.inputDecoration(
                                    context,
                                    labelText: 'Name',
                                    hintText: 'e.g. Science Group',
                                    prefixIcon:
                                        const Icon(Icons.grid_view_rounded),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _descCtrl,
                                  maxLines: 3,
                                  decoration: SiChrome.inputDecoration(
                                    context,
                                    labelText: 'Description (optional)',
                                    prefixIcon: const Icon(Icons.notes_rounded),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Subjects',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 0,
                          color: AppColors.surfaceWhite,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: AppColors.textSecondary.withOpacity(0.12),
                            ),
                          ),
                          child: Column(
                            children: meta.subjects.map((s) {
                              final on = _subjectIds.contains(s.id);
                              return CheckboxListTile(
                                value: on,
                                onChanged: (v) {
                                  setState(() {
                                    if (v == true) {
                                      _subjectIds.add(s.id);
                                    } else {
                                      _subjectIds.remove(s.id);
                                    }
                                  });
                                },
                                dense: true,
                                title: Text(_subjectLabel(s)),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Class sections',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 0,
                          color: AppColors.surfaceWhite,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: AppColors.textSecondary.withOpacity(0.12),
                            ),
                          ),
                          child: Column(
                            children: meta.classSections.map((cs) {
                              final on = _classSectionIds.contains(cs.id);
                              return CheckboxListTile(
                                value: on,
                                onChanged: (v) {
                                  setState(() {
                                    if (v == true) {
                                      _classSectionIds.add(cs.id);
                                    } else {
                                      _classSectionIds.remove(cs.id);
                                    }
                                  });
                                },
                                dense: true,
                                title: Text(cs.label),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.save_rounded),
                          label: Text(_saving ? 'Saving…' : 'Save'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ],
                    ),
                    if (_saving)
                      Positioned.fill(
                        child: Container(
                          color: Colors.white.withOpacity(0.35),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}

