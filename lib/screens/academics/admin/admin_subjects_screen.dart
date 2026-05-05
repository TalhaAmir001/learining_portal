import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/academics/admin_academics_models.dart';
import 'package:learining_portal/network/domain/academics_repository.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';

class AdminSubjectsScreen extends StatefulWidget {
  const AdminSubjectsScreen({super.key});

  @override
  State<AdminSubjectsScreen> createState() => _AdminSubjectsScreenState();
}

class _AdminSubjectsScreenState extends State<AdminSubjectsScreen> {
  static const List<String> _types = ['theory', 'practical'];

  bool _loading = true;
  String? _error;
  List<AdminAcSubjectItem> _subjects = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final meta = await AcademicsRepository.getAdminAcademicsMeta();
      if (!meta.success) {
        _error = meta.error ?? 'Failed to load subjects.';
        _subjects = const [];
      } else {
        _subjects = [...meta.subjects]..sort((a, b) => a.id.compareTo(b.id));
        if (_subjects.isEmpty) {
          _error = 'No subjects found.';
        }
      }
    } catch (e) {
      _error = e.toString();
      _subjects = const [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openUpsertDialog({AdminAcSubjectItem? item}) async {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final codeCtrl = TextEditingController(text: item?.code ?? '');
    String type = item?.type.isNotEmpty == true ? item!.type : _types.first;
    if (!_types.contains(type)) type = _types.first;
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(item == null ? 'Add subject' : 'Edit subject'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: SiChrome.inputDecoration(
                          ctx,
                          labelText: 'Subject name',
                          hintText: 'e.g. Mathematics',
                          prefixIcon: const Icon(Icons.menu_book_rounded),
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'Required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: codeCtrl,
                        decoration: SiChrome.inputDecoration(
                          ctx,
                          labelText: 'Code (optional)',
                          hintText: 'e.g. MATH',
                          prefixIcon: const Icon(Icons.tag_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InputDecorator(
                        decoration: SiChrome.inputDecoration(
                          ctx,
                          labelText: 'Type',
                          prefixIcon: const Icon(Icons.category_rounded),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: type,
                            isExpanded: true,
                            items: _types
                                .map((t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(t[0].toUpperCase() + t.substring(1)),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setLocal(() => type = v);
                            },
                          ),
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
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    try {
                      final r = await AcademicsRepository.upsertSubject(
                        id: item?.id,
                        name: nameCtrl.text.trim(),
                        code: codeCtrl.text.trim(),
                        type: type,
                      );
                      if (r['success'] == true) {
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } else {
                        if (ctx.mounted) {
                          SiChrome.showMessage(ctx, (r['error'] ?? 'Save failed').toString());
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
    if (saved == true) {
      await _load();
    }
  }

  Future<void> _delete(AdminAcSubjectItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete subject?'),
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
      final r = await AcademicsRepository.deleteSubject(id: item.id);
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
      title: 'Subjects',
      subtitle: 'Manage subject list',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          color: Colors.white,
          onPressed: _loading ? null : _load,
        ),
        IconButton(
          icon: const Icon(Icons.add_rounded),
          color: Colors.white,
          onPressed: _loading ? null : () => _openUpsertDialog(),
        ),
      ],
      child: _loading
          ? const SiLoadingBlock(message: 'Loading…')
          : _subjects.isEmpty
              ? SiEmptyState(
                  icon: Icons.menu_book_outlined,
                  title: 'No subjects',
                  message: _error,
                )
              : RefreshIndicator(
                  color: AppColors.primaryBlue,
                  onRefresh: _load,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    itemCount: _subjects.length,
                    itemBuilder: (context, i) {
                      final s = _subjects[i];
                      final meta = [
                        if (s.code.isNotEmpty) s.code,
                        if (s.type.isNotEmpty) s.type,
                        'ID ${s.id}',
                      ].join(' · ');
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 0,
                        color: AppColors.surfaceWhite,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: AppColors.textSecondary.withOpacity(0.12)),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.menu_book_rounded, color: AppColors.primaryBlue),
                          title: Text(s.name.isEmpty ? '(unnamed)' : s.name),
                          subtitle: Text(meta),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                tooltip: 'Edit',
                                onPressed: () => _openUpsertDialog(item: s),
                                icon: const Icon(Icons.edit_rounded),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: () => _delete(s),
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

