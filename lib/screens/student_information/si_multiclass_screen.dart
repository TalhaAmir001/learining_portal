import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/student_information/student_information_models.dart';
import 'package:learining_portal/network/domain/student_information_repository.dart';
import 'package:learining_portal/screens/student_information/si_student_detail_screen.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/utils/app_colors.dart';

class SiMulticlassScreen extends StatefulWidget {
  const SiMulticlassScreen({super.key});

  @override
  State<SiMulticlassScreen> createState() => _SiMulticlassScreenState();
}

class _SiMulticlassScreenState extends State<SiMulticlassScreen> {
  List<SiClassModel> _classes = [];
  List<SiSectionModel> _sections = [];
  int? _classId;
  int? _sectionId;
  bool _mastersLoading = true;
  bool _listLoading = false;
  List<SiMulticlassStudentModel> _rows = [];

  @override
  void initState() {
    super.initState();
    _loadMasters();
  }

  Future<void> _loadMasters() async {
    setState(() => _mastersLoading = true);
    final c = await StudentInformationRepository.getClasses();
    if (!mounted) return;
    setState(() {
      _classes = c;
      _mastersLoading = false;
    });
  }

  Future<void> _onClassChanged(int? id) async {
    setState(() {
      _classId = id;
      _sectionId = null;
      _sections = [];
      _rows = [];
    });
    if (id == null || id <= 0) return;
    final sec = await StudentInformationRepository.getSections(classId: id);
    if (!mounted) return;
    setState(() => _sections = sec);
  }

  Future<void> _load() async {
    if (_classId == null || _sectionId == null || _sectionId! <= 0) {
      SiChrome.showMessage(context, 'Select class and section.');
      return;
    }
    setState(() => _listLoading = true);
    final list = await StudentInformationRepository.getMulticlassStudents(
      classId: _classId!,
      sectionId: _sectionId!,
    );
    if (!mounted) return;
    setState(() {
      _rows = list;
      _listLoading = false;
    });
    if (list.isEmpty) {
      SiChrome.showMessage(
        context,
        'No multi-class students in this class/section.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SiThemedPageScaffold(
      title: 'Multi Class Student',
      subtitle: 'Students with more than one enrollment this year',
      child: _mastersLoading
          ? const SiLoadingBlock(message: 'Loading classes…')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        decoration:
                            SiChrome.inputDecoration(context, labelText: 'Class'),
                        value: _classId,
                        items: _classes
                            .map(
                              (c) => DropdownMenuItem<int>(
                                value: c.id,
                                child: Text(
                                  c.className,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => _onClassChanged(v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        decoration:
                            SiChrome.inputDecoration(context, labelText: 'Section'),
                        value: _sectionId,
                        items: _sections
                            .map(
                              (s) => DropdownMenuItem<int>(
                                value: s.id,
                                child: Text(
                                  s.sectionName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          setState(() => _sectionId = v);
                        },
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _listLoading ? null : _load,
                        icon: _listLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.groups_rounded),
                        label: const Text('Load students'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accentTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(child: _listBody()),
              ],
            ),
    );
  }

  Widget _listBody() {
    if (_rows.isEmpty) {
      return SiEmptyState(
        icon: Icons.copy_all_outlined,
        title: 'No students loaded',
        message:
            'Pick a class and section, then tap Load students to see who has multiple class enrollments.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _rows.length,
      itemBuilder: (context, i) {
        final r = _rows[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: AppColors.surfaceWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: AppColors.textSecondary.withOpacity(0.12),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondaryPurple.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.copy_all_rounded,
                  color: AppColors.secondaryPurple,
                  size: 22,
                ),
              ),
              title: Text(
                r.displayName.isEmpty ? 'Student #${r.studentId}' : r.displayName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${r.sessions.length} enrollments this session',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
              iconColor: AppColors.primaryBlue,
              collapsedIconColor: AppColors.primaryBlue,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    tileColor: AppColors.primaryBlue.withOpacity(0.06),
                    leading: const Icon(Icons.person_rounded, color: AppColors.primaryBlue),
                    title: const Text('Open profile'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              SiStudentDetailScreen(studentId: r.studentId),
                        ),
                      );
                    },
                  ),
                ),
                ...r.sessions.map(
                  (s) => ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.class_rounded,
                      size: 20,
                      color: AppColors.textSecondary.withOpacity(0.8),
                    ),
                    title: Text(
                      '${s.className} — ${s.sectionName}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    subtitle: Text(
                      'Session id: ${s.studentSessionId}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
