import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/student_information/student_information_models.dart';
import 'package:learining_portal/network/domain/student_information_repository.dart';
import 'package:learining_portal/screens/student_information/si_student_detail_screen.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select class and section.')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No multi-class students in this class/section.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi Class Student'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: _mastersLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Class',
                          border: OutlineInputBorder(),
                        ),
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
                        decoration: const InputDecoration(
                          labelText: 'Section',
                          border: OutlineInputBorder(),
                        ),
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
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _listLoading ? null : _load,
                        icon: _listLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.search_rounded),
                        label: const Text('Load students'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _rows.isEmpty
                      ? Center(
                          child: Text(
                            'Choose class and section, then load.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _rows.length,
                          itemBuilder: (context, i) {
                            final r = _rows[i];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: ExpansionTile(
                                title: Text(
                                  r.displayName.isEmpty
                                      ? 'Student #${r.studentId}'
                                      : r.displayName,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  'Sessions in this year: ${r.sessions.length}',
                                ),
                                children: [
                                  ListTile(
                                    dense: true,
                                    title: const Text('Open profile'),
                                    trailing: const Icon(Icons.open_in_new_rounded),
                                    onTap: () {
                                      Navigator.push<void>(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) => SiStudentDetailScreen(
                                            studentId: r.studentId,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  ...r.sessions.map(
                                    (s) => ListTile(
                                      dense: true,
                                      leading: const Icon(Icons.class_rounded),
                                      title: Text('${s.className} — ${s.sectionName}'),
                                      subtitle: Text('Session row id: ${s.studentSessionId}'),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
