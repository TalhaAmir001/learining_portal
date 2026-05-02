import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/student_information/student_information_models.dart';
import 'package:learining_portal/network/domain/student_information_repository.dart';
import 'package:learining_portal/screens/student_information/si_student_detail_screen.dart';
import 'package:learining_portal/utils/app_colors.dart';

class SiStudentSearchScreen extends StatefulWidget {
  const SiStudentSearchScreen({super.key});

  @override
  State<SiStudentSearchScreen> createState() => _SiStudentSearchScreenState();
}

class _SiStudentSearchScreenState extends State<SiStudentSearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  List<SiClassModel> _classes = [];
  List<SiSectionModel> _sections = [];
  int? _classId;
  int _sectionId = 0;
  bool _mastersLoading = true;

  List<SiStudentRowModel> _results = [];
  bool _listLoading = false;

  final _keywordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadMasters();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _keywordCtrl.dispose();
    super.dispose();
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
      _sectionId = 0;
      _sections = [];
    });
    if (id == null || id <= 0) return;
    final sec = await StudentInformationRepository.getSections(classId: id);
    if (!mounted) return;
    setState(() => _sections = sec);
  }

  Future<void> _searchByClass() async {
    if (_classId == null || _classId! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a class.')),
      );
      return;
    }
    setState(() => _listLoading = true);
    final rows = await StudentInformationRepository.searchStudentsByClassSection(
      classId: _classId!,
      sectionId: _sectionId,
    );
    if (!mounted) return;
    setState(() {
      _results = rows;
      _listLoading = false;
    });
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students found.')),
      );
    }
  }

  Future<void> _searchByKeyword() async {
    final q = _keywordCtrl.text.trim();
    if (q.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least 2 characters.')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _listLoading = true);
    final rows = await StudentInformationRepository.searchStudentsFullText(searchText: q);
    if (!mounted) return;
    setState(() {
      _results = rows;
      _listLoading = false;
    });
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students found.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Details'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'By class'),
            Tab(text: 'By keyword'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _classTab(),
          _keywordTab(),
        ],
      ),
    );
  }

  Widget _classTab() {
    if (_mastersLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
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
              DropdownButtonFormField<int?>(
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Section (optional)',
                  border: OutlineInputBorder(),
                ),
                value: _sectionId == 0 ? null : _sectionId,
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All sections'),
                  ),
                  ..._sections.map(
                    (s) => DropdownMenuItem<int?>(
                      value: s.id,
                      child: Text(
                        s.sectionName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (v) {
                  setState(() => _sectionId = v ?? 0);
                },
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _listLoading ? null : _searchByClass,
                icon: _listLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search_rounded),
                label: const Text('Search'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _resultList()),
      ],
    );
  }

  Widget _keywordTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keywordCtrl,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchByKeyword(),
                  decoration: const InputDecoration(
                    labelText: 'Name, admission no, phone…',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _listLoading ? null : _searchByKeyword,
                icon: _listLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _resultList()),
      ],
    );
  }

  Widget _resultList() {
    if (_results.isEmpty) {
      return Center(
        child: Text(
          'Results appear here after you search.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = _results[i];
        return ListTile(
          title: Text(
            r.displayName.isEmpty ? 'Student #${r.studentId}' : r.displayName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${r.className} ${r.sectionName} · Adm ${r.admissionNo}${r.rollNo.isNotEmpty ? ' · Roll ${r.rollNo}' : ''}',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => SiStudentDetailScreen(studentId: r.studentId),
              ),
            );
          },
        );
      },
    );
  }
}
