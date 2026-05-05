import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/academics/admin_academics_models.dart';
import 'package:learining_portal/network/domain/academics_repository.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';

class AdminClassesScreen extends StatefulWidget {
  const AdminClassesScreen({super.key});

  @override
  State<AdminClassesScreen> createState() => _AdminClassesScreenState();
}

class _AdminClassesScreenState extends State<AdminClassesScreen> {
  bool _loading = true;
  String? _error;
  List<AdminAcSimpleItem> _classes = const [];

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
        _error = meta.error ?? 'Failed to load classes.';
        _classes = const [];
      } else {
        _classes = [...meta.classes]..sort((a, b) => a.id.compareTo(b.id));
        if (_classes.isEmpty) {
          _error = 'No classes found.';
        }
      }
    } catch (e) {
      _error = e.toString();
      _classes = const [];
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
          title: Text(item == null ? 'Add class' : 'Edit class'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: ctrl,
              decoration: SiChrome.inputDecoration(
                ctx,
                labelText: 'Class name',
                hintText: 'e.g. Grade 5',
                prefixIcon: const Icon(Icons.class_rounded),
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
                  final r = await AcademicsRepository.upsertClass(
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
        title: const Text('Delete class?'),
        content: Text('This will delete "${item.name}" and related class-section mappings.'),
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
      final r = await AcademicsRepository.deleteClass(id: item.id);
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
      title: 'Class',
      subtitle: 'Manage classes',
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
          : _classes.isEmpty
              ? SiEmptyState(
                  icon: Icons.class_outlined,
                  title: 'No classes',
                  message: _error,
                )
              : RefreshIndicator(
                  color: AppColors.primaryBlue,
                  onRefresh: _load,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    itemCount: _classes.length,
                    itemBuilder: (context, i) {
                      final c = _classes[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 0,
                        color: AppColors.surfaceWhite,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: AppColors.textSecondary.withOpacity(0.12)),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.class_rounded, color: AppColors.primaryBlue),
                          title: Text(c.name.isEmpty ? '(unnamed)' : c.name),
                          subtitle: Text('ID ${c.id}'),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                tooltip: 'Edit',
                                onPressed: () => _openUpsertDialog(item: c),
                                icon: const Icon(Icons.edit_rounded),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: () => _delete(c),
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

