import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/class_summary_flashcards/class_summary_flashcards_models.dart';
import 'package:learining_portal/network/domain/class_summary_flashcards_repository.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/screens/class_summary_flashcards/class_summary_flashcard_study_screen.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:provider/provider.dart';

class ClassSummaryFlashcardSetsScreen extends StatefulWidget {
  const ClassSummaryFlashcardSetsScreen({super.key});

  @override
  State<ClassSummaryFlashcardSetsScreen> createState() =>
      _ClassSummaryFlashcardSetsScreenState();
}

class _ClassSummaryFlashcardSetsScreenState
    extends State<ClassSummaryFlashcardSetsScreen> {
  bool _loading = true;
  String? _error;
  List<ClassSummaryFlashcardSetListItem> _items = const [];

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
        _error = 'Flashcards are available for student accounts.';
        _items = const [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload =
          await ClassSummaryFlashcardsRepository.getForStudent(studentId: studentId);
      if (!payload.success) {
        _error = payload.error ?? 'Failed to load flashcards.';
        _items = const [];
      } else {
        _items = payload.items;
        if (_items.isEmpty) {
          _error = 'No flashcards yet.';
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
      title: 'Flashcards',
      subtitle: 'From class summaries',
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
                  icon: Icons.style_outlined,
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
                      final status = s.isCompleted
                          ? 'Completed'
                          : s.isNew
                              ? 'New'
                              : 'In progress';

                      final subParts = <String>[
                        s.classDate,
                        [s.className, s.sectionName]
                            .where((e) => e.trim().isNotEmpty)
                            .join(' • '),
                        status,
                      ].where((e) => e.trim().isNotEmpty).toList();

                      return SiResultCard(
                        title: s.displayTopic,
                        subtitle: subParts.join('\n'),
                        leadingIcon: Icons.style_rounded,
                        onTap: () {
                          final auth = context.read<AuthProvider>();
                          final studentId = _studentIdFromAuth(auth);
                          if (studentId == null) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ClassSummaryFlashcardStudyScreen(
                                setId: s.id,
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

