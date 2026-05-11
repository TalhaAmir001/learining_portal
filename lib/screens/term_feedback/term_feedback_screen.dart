import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/term_feedback/term_feedback_models.dart';
import 'package:learining_portal/network/domain/term_feedback_repository.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:provider/provider.dart';

/// Mobile equivalent of `admin/termfeedback/index.php`.
///
/// Lets admins and teachers select a class/section + month range, load the
/// student list (with any previously saved feedback), edit ratings + remarks
/// per student and a single "overall class performance" rating, then save.
/// Admins additionally see the "all saved term feedback" history at the top.
class TermFeedbackScreen extends StatefulWidget {
  const TermFeedbackScreen({super.key});

  @override
  State<TermFeedbackScreen> createState() => _TermFeedbackScreenState();
}

class _TermFeedbackScreenState extends State<TermFeedbackScreen> {
  static const List<String> _monthValues = [
    '01', '02', '03', '04', '05', '06',
    '07', '08', '09', '10', '11', '12',
  ];
  static const List<String> _monthLabels = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const List<String> _ratingFieldLabels = [
    'Participation',
    'Behaviour',
    'Classwork completion',
    'Confidence / communication',
    'Homework',
  ];

  // Filter state
  TermFeedbackClass? _selectedClass;
  TermFeedbackSection? _selectedSection;
  String? _startMonth; // 01..12
  String? _startYear;  // e.g. 2026
  String? _endMonth;
  String? _endYear;

  // Loaded data
  bool _loadingClasses = false;
  bool _loadingSections = false;
  bool _loadingStudents = false;
  bool _saving = false;
  bool _canSave = false;
  bool _showHistory = false;

  List<TermFeedbackClass> _classes = const [];
  List<TermFeedbackSection> _sections = const [];
  List<TermFeedbackStudent> _students = const [];
  List<TermFeedbackHistoryItem> _history = const [];
  Map<int, TermFeedbackDraft> _drafts = {};
  Map<int, TextEditingController> _remarksControllers = {};
  TermFeedbackOverall? _overall;

  String? _error;
  String? _statusMessage;

  /// Cached resolved auth fields.
  String _userType = '';
  int? _staffId;

  @override
  void initState() {
    super.initState();
    final yearNow = DateTime.now().year;
    _startYear = yearNow.toString();
    _endYear = yearNow.toString();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  @override
  void dispose() {
    for (final c in _remarksControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final auth = context.read<AuthProvider>();
    _staffId = auth.portalStaffId ?? 0;
    final ut = auth.userType;
    if (ut == UserType.admin) {
      _userType = 'admin';
    } else if (ut == UserType.teacher) {
      _userType = 'teacher';
    } else if (auth.isSuperAdmin) {
      _userType = 'admin';
      _staffId = (_staffId ?? 0) > 0 ? _staffId : 0;
    } else {
      setState(() {
        _error = 'Term Feedback is only available to admin and teacher accounts.';
      });
      return;
    }
    await Future.wait([
      _fetchClasses(),
      if (_userType == 'admin') _fetchHistory(),
    ]);
  }

  Future<void> _fetchClasses() async {
    setState(() {
      _loadingClasses = true;
      _error = null;
    });
    final res = await TermFeedbackRepository.getClasses(
      userType: _userType,
      staffId: _staffId,
    );
    if (!mounted) return;
    setState(() {
      _loadingClasses = false;
      if (res.success) {
        _classes = res.classes;
        _canSave = res.canSave;
        _showHistory = res.showHistory;
        if (_classes.isEmpty) {
          _error = _userType == 'teacher'
              ? 'You are not assigned to any class for the current session.'
              : 'No classes found.';
        }
      } else {
        _error = res.error ?? 'Failed to load classes.';
      }
    });
  }

  Future<void> _fetchSections(int classId) async {
    setState(() {
      _loadingSections = true;
      _sections = const [];
      _selectedSection = null;
    });
    final res = await TermFeedbackRepository.getSections(
      userType: _userType,
      staffId: _staffId,
      classId: classId,
    );
    if (!mounted) return;
    setState(() {
      _loadingSections = false;
      if (res.success) {
        _sections = res.sections;
      } else {
        _error = res.error ?? 'Failed to load sections.';
      }
    });
  }

  Future<void> _fetchHistory() async {
    final res = await TermFeedbackRepository.getHistory(
      userType: _userType,
      staffId: _staffId,
    );
    if (!mounted) return;
    setState(() {
      _history = res.success ? res.items : const [];
    });
  }

  String? _composedStart() {
    if (_startMonth == null || _startYear == null) return null;
    return '$_startYear-$_startMonth';
  }

  String? _composedEnd() {
    if (_endMonth == null || _endYear == null) return null;
    return '$_endYear-$_endMonth';
  }

  Future<void> _loadStudents() async {
    final cls = _selectedClass;
    final sec = _selectedSection;
    final start = _composedStart();
    final end = _composedEnd();

    if (cls == null || sec == null || start == null || end == null) {
      _showSnack('Please choose class, section, start month and end month.');
      return;
    }
    if (start.compareTo(end) > 0) {
      _showSnack('End month must be the same as or after the start month.');
      return;
    }

    setState(() {
      _loadingStudents = true;
      _statusMessage = null;
      _students = const [];
      _drafts = {};
      for (final c in _remarksControllers.values) {
        c.dispose();
      }
      _remarksControllers = {};
      _overall = null;
    });

    final res = await TermFeedbackRepository.loadStudents(
      userType: _userType,
      staffId: _staffId,
      classId: cls.id,
      sectionId: sec.id,
      startMonth: start,
      endMonth: end,
    );
    if (!mounted) return;

    setState(() {
      _loadingStudents = false;
      if (!res.success) {
        _statusMessage = res.error ?? 'Failed to load students.';
        return;
      }
      _students = res.students;
      _overall = res.overall;
      _drafts = {
        for (final st in res.students) st.id: TermFeedbackDraft.fromStudent(st),
      };
      _remarksControllers = {
        for (final st in res.students)
          st.id: TextEditingController(text: st.feedback?.remarks ?? ''),
      };
      if (_students.isEmpty) {
        _statusMessage = 'No active students in this class/section.';
      }
    });
  }

  Future<void> _save() async {
    if (_drafts.isEmpty) return;

    // Sync remarks from controllers and validate.
    final missing = <int>[];
    for (final entry in _drafts.entries) {
      final ctl = _remarksControllers[entry.key];
      final remarks = (ctl?.text ?? '').trim();
      entry.value.remarks = remarks;
      if (remarks.isEmpty) missing.add(entry.key);
    }
    if (missing.isNotEmpty) {
      _showSnack('Remarks are required for all students.');
      return;
    }

    final cls = _selectedClass;
    final sec = _selectedSection;
    final start = _composedStart();
    final end = _composedEnd();
    if (cls == null || sec == null || start == null || end == null) {
      _showSnack('Class, section and period are required.');
      return;
    }

    setState(() => _saving = true);
    final res = await TermFeedbackRepository.save(
      userType: _userType,
      staffId: _staffId,
      classId: cls.id,
      sectionId: sec.id,
      startMonth: start,
      endMonth: end,
      overall: _overall,
      items: _drafts.values.toList(growable: false),
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (res['success'] == true) {
      _showSnack('Feedback saved.');
      if (_showHistory) {
        await _fetchHistory();
      }
    } else {
      _showSnack(res['error']?.toString() ?? 'Save failed.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return SiThemedPageScaffold(
      title: 'Term Feedback',
      subtitle: _userType == 'teacher'
          ? 'Rate students for the selected period'
          : 'Class · section · period feedback',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          color: Colors.white,
          tooltip: 'Reload classes / history',
          onPressed: _loadingClasses ? null : _bootstrap,
        ),
      ],
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loadingClasses && _classes.isEmpty) {
      return const SiLoadingBlock(message: 'Loading…');
    }
    if (_classes.isEmpty && _error != null) {
      return SiEmptyState(
        icon: Icons.school_outlined,
        title: 'Term Feedback',
        message: _error,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (_showHistory) _buildHistoryPanel(),
        if (_showHistory) const SizedBox(height: 16),
        _buildFiltersCard(),
        const SizedBox(height: 12),
        _buildRatingGuide(),
        const SizedBox(height: 16),
        if (_loadingStudents)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: SiLoadingBlock(message: 'Loading students…'),
          )
        else if (_statusMessage != null && _students.isEmpty)
          _buildInfoBanner(_statusMessage!)
        else if (_students.isNotEmpty) ...[
          _buildOverallDropdown(),
          const SizedBox(height: 12),
          ..._students.map(_buildStudentCard),
          const SizedBox(height: 16),
          _buildSaveButton(),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Filters card
  // ---------------------------------------------------------------------------

  Widget _buildFiltersCard() {
    return Card(
      elevation: 0,
      color: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.textSecondary.withOpacity(0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose class, section and period',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 12),
            _buildClassDropdown(),
            const SizedBox(height: 10),
            _buildSectionDropdown(),
            const SizedBox(height: 10),
            _buildPeriodSelectors(),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loadingStudents ? null : _loadStudents,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.search_rounded),
                label: Text(_loadingStudents ? 'Loading…' : 'Load students'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassDropdown() {
    return DropdownButtonFormField<TermFeedbackClass>(
      value: _selectedClass,
      isExpanded: true,
      decoration: SiChrome.inputDecoration(
        context,
        labelText: 'Class',
        prefixIcon: const Icon(Icons.school_rounded, size: 20),
      ),
      items: _classes
          .map((c) => DropdownMenuItem<TermFeedbackClass>(
                value: c,
                child: Text(c.name, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: _loadingClasses
          ? null
          : (value) {
              setState(() {
                _selectedClass = value;
                _selectedSection = null;
                _sections = const [];
              });
              if (value != null) {
                _fetchSections(value.id);
              }
            },
    );
  }

  Widget _buildSectionDropdown() {
    return DropdownButtonFormField<TermFeedbackSection>(
      value: _selectedSection,
      isExpanded: true,
      decoration: SiChrome.inputDecoration(
        context,
        labelText: _loadingSections ? 'Loading sections…' : 'Section',
        prefixIcon: const Icon(Icons.layers_rounded, size: 20),
      ),
      items: _sections
          .map((s) => DropdownMenuItem<TermFeedbackSection>(
                value: s,
                child: Text(s.name, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (_loadingSections || _selectedClass == null)
          ? null
          : (value) => setState(() => _selectedSection = value),
    );
  }

  Widget _buildPeriodSelectors() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Start month'),
        const SizedBox(height: 4),
        _monthYearRow(
          monthValue: _startMonth,
          yearValue: _startYear,
          onMonthChanged: (v) => setState(() => _startMonth = v),
          onYearChanged: (v) => setState(() => _startYear = v),
        ),
        const SizedBox(height: 10),
        const Text('End month'),
        const SizedBox(height: 4),
        _monthYearRow(
          monthValue: _endMonth,
          yearValue: _endYear,
          onMonthChanged: (v) => setState(() => _endMonth = v),
          onYearChanged: (v) => setState(() => _endYear = v),
        ),
      ],
    );
  }

  Widget _monthYearRow({
    required String? monthValue,
    required String? yearValue,
    required ValueChanged<String?> onMonthChanged,
    required ValueChanged<String?> onYearChanged,
  }) {
    final yearNow = DateTime.now().year;
    final years = [for (var y = yearNow - 2; y <= yearNow + 2; y++) y.toString()];
    return Row(
      children: [
        Expanded(
          flex: 7,
          child: DropdownButtonFormField<String>(
            value: monthValue,
            isExpanded: true,
            decoration: SiChrome.inputDecoration(
              context,
              labelText: 'Month',
            ),
            items: [
              for (var i = 0; i < _monthValues.length; i++)
                DropdownMenuItem<String>(
                  value: _monthValues[i],
                  child: Text(_monthLabels[i]),
                ),
            ],
            onChanged: onMonthChanged,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: DropdownButtonFormField<String>(
            value: yearValue,
            isExpanded: true,
            decoration: SiChrome.inputDecoration(
              context,
              labelText: 'Year',
            ),
            items: years
                .map((y) => DropdownMenuItem<String>(value: y, child: Text(y)))
                .toList(),
            onChanged: onYearChanged,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Rating guide / history / overall
  // ---------------------------------------------------------------------------

  Widget _buildRatingGuide() {
    return Card(
      elevation: 0,
      color: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.textSecondary.withOpacity(0.12)),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.info_outline_rounded, color: AppColors.accentTeal),
        title: const Text(
          'Rating scale guide',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text('Tap to expand · 1 (lowest) to 5 (highest)'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: const [
          _GuideSection(
            heading: 'Overall class performance',
            entries: [
              _GuideEntry('Excellent',
                  'Strong term overall. Students stayed focused, participated well, and progressed consistently.'),
              _GuideEntry('Good',
                  'Positive term. Most students engaged well; a few areas were identified for further practice.'),
              _GuideEntry('Mixed',
                  'Some students progressed well, others need more consistent focus and independent practice.'),
              _GuideEntry('Needs improvement',
                  'Improved focus, attendance, and consistent task completion are needed to make stronger progress.'),
            ],
          ),
          _GuideSection(
            heading: 'Participation (1–5)',
            entries: [
              _GuideEntry('1', 'Rarely participates; needs encouragement to engage.'),
              _GuideEntry('2', 'Participates occasionally; needs to be more consistent.'),
              _GuideEntry('3', 'Participates when prompted; satisfactory engagement.'),
              _GuideEntry('4', 'Regularly participates and contributes well.'),
              _GuideEntry('5', 'Highly engaged; actively contributes throughout lessons.'),
            ],
          ),
          _GuideSection(
            heading: 'Behaviour (1–5)',
            entries: [
              _GuideEntry('1', 'Difficulty following class expectations consistently.'),
              _GuideEntry('2', 'Sometimes struggles to stay focused / follow instructions.'),
              _GuideEntry('3', 'Generally behaves well; room to improve focus at times.'),
              _GuideEntry('4', 'Behaves well and respects the learning environment.'),
              _GuideEntry('5', 'Excellent behaviour; sets a positive example.'),
            ],
          ),
          _GuideSection(
            heading: 'Classwork completion (1–5)',
            entries: [
              _GuideEntry('1', 'Rarely completes classwork during lessons.'),
              _GuideEntry('2', 'Completes limited classwork; needs more consistency.'),
              _GuideEntry('3', 'Completes most classwork with some support.'),
              _GuideEntry('4', 'Regularly completes classwork set during lessons.'),
              _GuideEntry('5', 'Consistently completes all classwork; attempts challenge work.'),
            ],
          ),
          _GuideSection(
            heading: 'Confidence / communication (1–5)',
            entries: [
              _GuideEntry('1', 'Not yet confident to communicate; rarely contributes.'),
              _GuideEntry('2', 'Limited confidence; communicates only occasionally.'),
              _GuideEntry('3', 'Developing confidence; communicates when prompted.'),
              _GuideEntry('4', 'Communicates confidently and contributes well.'),
              _GuideEntry('5', 'Very confident; communicates clearly and contributes actively.'),
            ],
          ),
          _GuideSection(
            heading: 'Homework (1–5)',
            entries: [
              _GuideEntry('1', 'Rarely completes homework.'),
              _GuideEntry('2', 'Completes homework irregularly.'),
              _GuideEntry('3', 'Completes most homework tasks.'),
              _GuideEntry('4', 'Regularly completes homework to a good standard.'),
              _GuideEntry('5', 'Consistently completes homework to a high standard.'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryPanel() {
    return Card(
      elevation: 0,
      color: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.textSecondary.withOpacity(0.12)),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.history_rounded, color: AppColors.primaryBlue),
        title: const Text(
          'All saved term feedback',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _history.isEmpty
              ? 'No saved feedback yet for this session.'
              : '${_history.length} saved period${_history.length == 1 ? '' : 's'}',
        ),
        children: [
          if (_history.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: Column(
                children: _history
                    .map(
                      (h) => ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.event_note_rounded,
                          color: AppColors.accentTeal,
                        ),
                        title: Text(
                          [h.className, h.sectionName]
                              .where((s) => s.trim().isNotEmpty)
                              .join(' · '),
                        ),
                        subtitle: Text('${h.startMonth} → ${h.endMonth}'),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOverallDropdown() {
    return Card(
      elevation: 0,
      color: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.textSecondary.withOpacity(0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overall class performance',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Applies to this class for the selected period',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<TermFeedbackOverall?>(
              value: _overall,
              isExpanded: true,
              decoration: SiChrome.inputDecoration(
                context,
                labelText: 'Select',
              ),
              items: [
                const DropdownMenuItem<TermFeedbackOverall?>(
                  value: null,
                  child: Text('— None —'),
                ),
                ...TermFeedbackOverall.values.map(
                  (e) => DropdownMenuItem<TermFeedbackOverall?>(
                    value: e,
                    child: Text(e.label),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _overall = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentTeal.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.accentTeal.withOpacity(0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.accentTeal),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Student card
  // ---------------------------------------------------------------------------

  Widget _buildStudentCard(TermFeedbackStudent st) {
    final draft = _drafts[st.id]!;
    final ctl = _remarksControllers[st.id];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.textSecondary.withOpacity(0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.accentTeal.withOpacity(0.18),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        st.fullName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      if (st.admissionNo.trim().isNotEmpty)
                        Text(
                          st.admissionNo.trim(),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                    ],
                  ),
                ),
                if (st.feedback != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Saved',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _ratingRow(
              label: _ratingFieldLabels[0],
              value: draft.participation,
              onChanged: (v) => setState(() => draft.participation = v),
            ),
            _ratingRow(
              label: _ratingFieldLabels[1],
              value: draft.behaviour,
              onChanged: (v) => setState(() => draft.behaviour = v),
            ),
            _ratingRow(
              label: _ratingFieldLabels[2],
              value: draft.classwork,
              onChanged: (v) => setState(() => draft.classwork = v),
            ),
            _ratingRow(
              label: _ratingFieldLabels[3],
              value: draft.confidence,
              onChanged: (v) => setState(() => draft.confidence = v),
            ),
            _ratingRow(
              label: _ratingFieldLabels[4],
              value: draft.homework,
              onChanged: (v) => setState(() => draft.homework = v),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctl,
              minLines: 2,
              maxLines: 4,
              decoration: SiChrome.inputDecoration(
                context,
                labelText: 'Remarks *',
                hintText: 'Required',
                prefixIcon: const Icon(Icons.notes_rounded, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ratingRow({
    required String label,
    required int? value,
    required ValueChanged<int?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: [
              for (var i = 1; i <= 5; i++)
                ChoiceChip(
                  label: Text('$i'),
                  selected: value == i,
                  onSelected: (selected) {
                    onChanged(selected ? i : null);
                  },
                  selectedColor: AppColors.primaryBlue,
                  labelStyle: TextStyle(
                    color: value == i ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: value == i
                          ? AppColors.primaryBlue
                          : AppColors.textSecondary.withOpacity(0.25),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    final disabled = !_canSave || _saving;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: disabled ? null : _save,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.save_rounded),
        label: Text(_saving ? 'Saving…' : 'Save feedback'),
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({required this.heading, required this.entries});

  final String heading;
  final List<_GuideEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue,
                ),
          ),
          const SizedBox(height: 6),
          ...entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                    children: [
                      TextSpan(
                        text: '${e.label} — ',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      TextSpan(text: e.description),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _GuideEntry {
  const _GuideEntry(this.label, this.description);
  final String label;
  final String description;
}
