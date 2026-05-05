import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/academics/admin_academics_models.dart';
import 'package:learining_portal/network/domain/academics_repository.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';

class AdminSectionsScreen extends StatefulWidget {
  const AdminSectionsScreen({super.key});

  @override
  State<AdminSectionsScreen> createState() => _AdminSectionsScreenState();
}

class _AdminSectionsScreenState extends State<AdminSectionsScreen> {
  bool _loading = true;
  String? _error;
  List<AdminAcSimpleItem> _sections = const [];

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
        _error = meta.error ?? 'Failed to load sections.';
        _sections = const [];
      } else {
        _sections = [...meta.sections]..sort((a, b) => a.id.compareTo(b.id));
        if (_sections.isEmpty) {
          _error = 'No sections found.';
        }
      }
    } catch (e) {
      _error = e.toString();
      _sections = const [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openUpsertDialog({AdminAcSimpleItem? item}) async {
    final ctrl = TextEditingController(text: item?.name ?? '');
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(item == null ? 'Add section' : 'Edit section'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: ctrl,
              decoration: SiChrome.inputDecoration(
                ctx,
                labelText: 'Section name',
                hintText: 'e.g. A',
                prefixIcon: const Icon(Icons.view_list_rounded),
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return 'Required';
                return null;
              },
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
                  final r = await AcademicsRepository.upsertSection(
                    id: item?.id,
                    name: ctrl.text.trim(),
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
    if (saved == true) {
      await _load();
    }
  }

  Future<void> _delete(AdminAcSimpleItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete section?'),
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
      final r = await AcademicsRepository.deleteSection(id: item.id);
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
      title: 'Sections',
      subtitle: 'Manage sections',
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
          : _sections.isEmpty
              ? SiEmptyState(
                  icon: Icons.view_list_outlined,
                  title: 'No sections',
                  message: _error,
                )
              : RefreshIndicator(
                  color: AppColors.primaryBlue,
                  onRefresh: _load,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    itemCount: _sections.length,
                    itemBuilder: (context, i) {
                      final s = _sections[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 0,
                        color: AppColors.surfaceWhite,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: AppColors.textSecondary.withOpacity(0.12)),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.view_list_rounded, color: AppColors.primaryBlue),
                          title: Text(s.name.isEmpty ? '(unnamed)' : s.name),
                          subtitle: Text('ID ${s.id}'),
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

