import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/class_summary/class_summary_models.dart';
import 'package:learining_portal/network/domain/class_summary_repository.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/screens/class_summaries/class_summary_detail_screen.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:learining_portal/utils/class_summary_formatters.dart';
import 'package:provider/provider.dart';

class ClassSummaryListScreen extends StatefulWidget {
  const ClassSummaryListScreen({super.key});

  @override
  State<ClassSummaryListScreen> createState() => _ClassSummaryListScreenState();
}

class _ClassSummaryListScreenState extends State<ClassSummaryListScreen> {
  bool _loading = true;
  String? _error;
  List<ClassSummary> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  int? _studentIdFromAuth(AuthProvider auth) {
    return auth.effectiveStudentId();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final studentId = _studentIdFromAuth(auth);
    if (studentId == null) {
      setState(() {
        _loading = false;
        _error = 'Class summaries are available for student accounts.';
        _items = const [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = await ClassSummaryRepository.getForStudent(studentId: studentId);
      if (!payload.success) {
        _error = payload.error ?? 'Failed to load class summaries.';
        _items = const [];
      } else {
        _items = payload.items;
        if (_items.isEmpty) {
          _error = 'No class summaries available for your classes/sections yet.';
        }
      }
    } catch (e) {
      _error = e.toString();
      _items = const [];
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SiThemedPageScaffold(
      title: 'Class Summary',
      subtitle: 'Class summaries (by date)',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          color: Colors.white,
          onPressed: _loading ? null : _load,
        ),
      ],
      child: _loading
          ? const SiLoadingBlock(message: 'Loading…')
          : _items.isEmpty
              ? SiEmptyState(
                  icon: Icons.article_outlined,
                  title: 'Nothing to show',
                  message: _error,
                )
              : RefreshIndicator(
                  color: AppColors.primaryBlue,
                  onRefresh: _load,
                  child: LayoutBuilder(
                    builder: (context, c) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                        scrollDirection: Axis.vertical,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: c.maxWidth.clamp(0, 900)),
                              child: Card(
                                elevation: 0,
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
                                ),
                                child: DataTable(
                                  headingRowColor: WidgetStatePropertyAll(
                                    AppColors.primaryBlue.withValues(alpha: 0.08),
                                  ),
                                  columns: const [
                                    DataColumn(label: Text('Date')),
                                    DataColumn(label: Text('Class')),
                                    DataColumn(label: Text('Section')),
                                    DataColumn(label: Text('Title')),
                                    DataColumn(label: Text('Actions')),
                                  ],
                                  rows: [
                                    for (final s in _items)
                                      DataRow(
                                        cells: [
                                          DataCell(Text(formatClassSummaryListDate(s.classDate))),
                                          DataCell(Text(s.className.trim().isEmpty ? '—' : s.className)),
                                          DataCell(Text(s.sectionName.trim().isEmpty ? '—' : s.sectionName)),
                                          DataCell(
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(maxWidth: 220),
                                              child: Text(
                                                s.title.trim().isEmpty ? '—' : s.title,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            TextButton.icon(
                                              onPressed: () async {
                                                final auth = context.read<AuthProvider>();
                                                final studentId = _studentIdFromAuth(auth);
                                                if (studentId == null) return;
                                                await Navigator.push<void>(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => ClassSummaryDetailScreen(
                                                      summaryId: s.id,
                                                      studentId: studentId,
                                                    ),
                                                  ),
                                                );
                                              },
                                              icon: const Icon(Icons.visibility_rounded, size: 18),
                                              label: const Text('View'),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
