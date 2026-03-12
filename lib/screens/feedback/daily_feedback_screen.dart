import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/daily_feedback/daily_feedback_data_model.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/providers/daily_feedback/daily_feedback_provider.dart';
import 'package:learining_portal/screens/feedback/daily_feedback_form_screen.dart';
import 'package:learining_portal/screens/feedback/student_feedback_detail_screen.dart';
import 'package:learining_portal/screens/feedback/voice_player_widget.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:provider/provider.dart';

class DailyFeedbackScreen extends StatefulWidget {
  const DailyFeedbackScreen({super.key});

  @override
  State<DailyFeedbackScreen> createState() => _DailyFeedbackScreenState();
}

class _DailyFeedbackScreenState extends State<DailyFeedbackScreen> {
  int? _filterClassId;
  int? _filterSectionId;

  /// Feedbacks for the selected class and section only.
  List<DailyFeedbackModel> _feedbacksForClassSection(List<DailyFeedbackModel> feedbacks) {
    if (_filterClassId == null || _filterSectionId == null) return [];
    return feedbacks.where((f) {
      return f.classId == _filterClassId && f.sectionId == _filterSectionId;
    }).toList();
  }

  /// Student IDs that have at least one feedback in the selected class/section.
  Set<int> _studentIdsWithFeedback(List<DailyFeedbackModel> feedbacks) {
    final list = _feedbacksForClassSection(feedbacks);
    final ids = <int>{};
    for (final f in list) {
      ids.addAll(f.recipientStudentIds);
    }
    return ids;
  }

  /// Students (from provider) who have at least one saved feedback for selected class/section.
  List<FeedbackStudentModel> _studentsWithFeedback(
    List<DailyFeedbackModel> feedbacks,
    List<FeedbackStudentModel> students,
  ) {
    final ids = _studentIdsWithFeedback(feedbacks);
    return students.where((s) => ids.contains(s.studentId)).toList();
  }

  /// Latest feedback date for a student in the given feedback list (for display).
  String? _lastFeedbackDateForStudent(int studentId, List<DailyFeedbackModel> feedbacks) {
    final list = _feedbacksForClassSection(feedbacks)
        .where((f) => f.recipientStudentIds.contains(studentId))
        .toList();
    if (list.isEmpty) return null;
    DateTime? latestDt;
    for (final f in list) {
      if (f.createdAt == null || f.createdAt!.isEmpty) continue;
      try {
        final d = DateTime.parse(f.createdAt!).toLocal();
        if (latestDt == null || d.isAfter(latestDt)) latestDt = d;
      } catch (_) {}
    }
    if (latestDt == null) return null;
    return '${latestDt.day} ${_monthName(latestDt.month)} ${latestDt.year}';
  }

  static String _monthName(int month) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[month - 1];
  }

  void _clearFilters() {
    setState(() {
      _filterClassId = null;
      _filterSectionId = null;
    });
  }

  bool get _hasActiveFilters => _filterClassId != null || _filterSectionId != null;

  /// Unique class options (null + one per class id) so DropdownButton never has duplicate values.
  List<int?> _uniqueClassOptions(List<FeedbackClassModel> classes) {
    final result = <int?>[null];
    final seen = <int>{};
    for (final c in classes) {
      if (seen.add(c.id)) result.add(c.id);
    }
    return result;
  }

  /// Value for class dropdown: only use _filterClassId if it exists exactly once in options.
  int? _effectiveFilterClassId(List<FeedbackClassModel> classes) {
    if (_filterClassId == null) return null;
    final options = _uniqueClassOptions(classes);
    return options.contains(_filterClassId) ? _filterClassId : null;
  }

  /// Unique section options (null + one per section id).
  List<int?> _uniqueSectionOptions(List<FeedbackSectionModel> sections) {
    final result = <int?>[null];
    final seen = <int>{};
    for (final s in sections) {
      if (seen.add(s.id)) result.add(s.id);
    }
    return result;
  }

  /// Value for section dropdown: only use _filterSectionId if it exists in options.
  int? _effectiveFilterSectionId(List<FeedbackSectionModel> sections) {
    if (_filterSectionId == null) return null;
    final options = _uniqueSectionOptions(sections);
    return options.contains(_filterSectionId) ? _filterSectionId : null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DailyFeedbackProvider>();
      final staffId = context.read<AuthProvider>().currentUser?.uid;
      provider.loadFeedbacks(staffId);
      provider.loadClassesAndSections();
    });
  }

  void _openForm({DailyFeedbackModel? existing}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => DailyFeedbackFormScreen(
          feedbackId: existing?.id,
          existingFeedback: existing,
        ),
      ),
    );
    if (result == true && mounted) {
      final staffId = context.read<AuthProvider>().currentUser?.uid;
      context.read<DailyFeedbackProvider>().loadFeedbacks(staffId);
    }
  }

  Future<void> _onRefresh() async {
    final staffId = context.read<AuthProvider>().currentUser?.uid;
    await context.read<DailyFeedbackProvider>().loadFeedbacks(staffId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryBlue,
              AppColors.secondaryPurple,
              AppColors.backgroundLight,
            ],
            stops: const [0.0, 0.25, 0.4],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAppBar(context),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 12,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: Consumer<DailyFeedbackProvider>(
                      builder: (context, provider, _) {
                        return RefreshIndicator(
                          onRefresh: _onRefresh,
                          color: AppColors.primaryBlue,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildAddFeedbackButton(
                                  context,
                                  theme,
                                  provider,
                                ),
                                const SizedBox(height: 24),
                                _buildFilters(context, theme, provider),
                                const SizedBox(height: 12),
                                if (_filterClassId != null && _filterSectionId != null) ...[
                                  _buildStudentsWithFeedbackHeader(theme, provider),
                                  const SizedBox(height: 12),
                                  _buildStudentsWithFeedbackList(
                                    context,
                                    theme,
                                    provider,
                                  ),
                                ] else ...[
                                  _buildSelectClassSectionPrompt(theme),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.maybePop(context),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.feedback_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Daily Feedback',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddFeedbackButton(
    BuildContext context,
    ThemeData theme,
    DailyFeedbackProvider provider,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openForm,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryBlue, AppColors.secondaryPurple],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New feedback',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add message, voice & attachments',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(
    BuildContext context,
    ThemeData theme,
    DailyFeedbackProvider provider,
  ) {
    final classes = provider.classes;
    final sections = provider.sections;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list_rounded, size: 18, color: AppColors.primaryBlue),
              const SizedBox(width: 6),
              Text(
                'Class & Section',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (_hasActiveFilters)
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear_all_rounded, size: 18),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accentTeal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildDropdownFilter<int?>(
                theme: theme,
                value: _effectiveFilterClassId(classes),
                label: 'Class',
                options: _uniqueClassOptions(classes),
                optionLabel: (v) => v == null ? 'All' : (classes.where((c) => c.id == v).firstOrNull?.className ?? 'Class $v'),
                onChanged: (v) {
                  setState(() {
                    _filterClassId = v;
                    _filterSectionId = null;
                  });
                  provider.clearStudents();
                  if (v != null) {
                    provider.loadSectionsForClass(v);
                  } else {
                    provider.clearSections();
                  }
                },
              ),
              _buildDropdownFilter<int?>(
                theme: theme,
                value: _effectiveFilterSectionId(sections),
                label: 'Section',
                options: _uniqueSectionOptions(sections),
                optionLabel: (v) => v == null ? 'All' : (sections.where((s) => s.id == v).firstOrNull?.sectionName ?? 'Section $v'),
                onChanged: (v) {
                  setState(() => _filterSectionId = v);
                  if (v != null && _filterClassId != null) {
                    provider.loadStudents(_filterClassId!, v);
                  } else {
                    provider.clearStudents();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectClassSectionPrompt(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.school_rounded,
            size: 48,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Select class and section',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Students who have received feedback will appear here',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsWithFeedbackHeader(
    ThemeData theme,
    DailyFeedbackProvider provider,
  ) {
    final students = _studentsWithFeedback(provider.feedbacks, provider.students);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Students with feedback',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        if (students.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accentTeal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${students.length}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.accentTeal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStudentsWithFeedbackList(
    BuildContext context,
    ThemeData theme,
    DailyFeedbackProvider provider,
  ) {
    if (provider.loadingStudents) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentTeal),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading students...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final students = _studentsWithFeedback(provider.feedbacks, provider.students);
    if (students.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.person_off_rounded,
              size: 48,
              color: AppColors.textSecondary.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No students with feedback yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              'Add feedback for this class/section to see students here',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary.withOpacity(0.8),
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: students.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final student = students[index];
        final lastDate = _lastFeedbackDateForStudent(student.studentId, provider.feedbacks);
        return _StudentWithFeedbackCard(
          student: student,
          lastFeedbackDate: lastDate,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => StudentFeedbackDetailScreen(
                  student: student,
                  classId: _filterClassId!,
                  sectionId: _filterSectionId!,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDropdownFilter<T>({
    required ThemeData theme,
    required T? value,
    required String label,
    required List<T> options,
    required String Function(T?) optionLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.12)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
          hint: Text(label, style: theme.textTheme.bodySmall),
          items: options.map((v) {
            return DropdownMenuItem<T>(
              value: v,
              child: Text(
                optionLabel(v),
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            );
          }).toList(),
          onChanged: (v) => onChanged(v),
        ),
      ),
    ),
    );
  }

}

class _StudentWithFeedbackCard extends StatelessWidget {
  final FeedbackStudentModel student;
  final String? lastFeedbackDate;
  final VoidCallback onTap;

  const _StudentWithFeedbackCard({
    required this.student,
    required this.lastFeedbackDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final classSection = [
      if (student.className != null && student.className!.isNotEmpty) student.className,
      if (student.sectionName != null && student.sectionName!.isNotEmpty) student.sectionName,
    ].join(' • ');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, AppColors.backgroundLight.withOpacity(0.8)],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.person_rounded,
                  size: 28,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (classSection.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        classSection,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (lastFeedbackDate != null && lastFeedbackDate!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: AppColors.accentTeal,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Last feedback: $lastFeedbackDate',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.accentTeal,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
