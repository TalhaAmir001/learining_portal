import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/class_summary/class_summary_models.dart';
import 'package:learining_portal/network/domain/class_summary_repository.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/screens/class_summaries/class_summary_detail_screen.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';
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
    if (auth.userType != UserType.student) return null;
    final raw = auth.currentUser?.additionalData?['id'] ?? auth.currentUser?.id;
    final n = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    if (n != null && n > 0) return n;
    return null;
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
          _error = 'No class summaries yet.';
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
      title: 'Class Summaries',
      subtitle: 'Lesson recap & key points',
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
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    itemCount: _items.length,
                    itemBuilder: (context, i) {
                      final s = _items[i];
                      final subtitleParts = <String>[];
                      if (s.classDate.trim().isNotEmpty) subtitleParts.add(s.classDate.trim());
                      final clsSec = [s.className.trim(), s.sectionName.trim()]
                          .where((e) => e.isNotEmpty)
                          .join(' • ');
                      if (clsSec.isNotEmpty) subtitleParts.add(clsSec);
                      final subtitle = subtitleParts.isEmpty ? 'Tap to view' : subtitleParts.join('\n');

                      return SiResultCard(
                        title: s.displayTitle,
                        subtitle: subtitle,
                        leadingIcon: Icons.article_rounded,
                        onTap: () async {
                          final auth = context.read<AuthProvider>();
                          final studentId = _studentIdFromAuth(auth);
                          if (studentId == null) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ClassSummaryDetailScreen(
                                summaryId: s.id,
                                studentId: studentId,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
    );
  }
}

