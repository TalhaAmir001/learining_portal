import 'package:flutter/material.dart';
import 'package:learining_portal/network/domain/zoom_live_classes_repository.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';

class ZlcReportsScreen extends StatefulWidget {
  const ZlcReportsScreen({super.key});

  @override
  State<ZlcReportsScreen> createState() => _ZlcReportsScreenState();
}

class _ZlcReportsScreenState extends State<ZlcReportsScreen> {
  List<Map<String, dynamic>> _meetings = [];
  final _classId = TextEditingController();
  final _sectionId = TextEditingController();
  List<Map<String, dynamic>> _classRows = [];
  bool _loadingM = true;

  @override
  void initState() {
    super.initState();
    _loadMeetings();
  }

  Future<void> _loadMeetings() async {
    final rows = await ZoomLiveClassesRepository.getMeetingReport();
    if (mounted) {
      setState(() {
        _meetings = rows;
        _loadingM = false;
      });
    }
  }

  Future<void> _loadClass() async {
    final c = int.tryParse(_classId.text.trim());
    final s = int.tryParse(_sectionId.text.trim());
    if (c == null || s == null || c <= 0 || s <= 0) {
      SiChrome.showMessage(context, 'Enter valid class_id and section_id');
      return;
    }
    final rows = await ZoomLiveClassesRepository.getClassReport(classId: c, sectionId: s);
    setState(() => _classRows = rows);
  }

  @override
  void dispose() {
    _classId.dispose();
    _sectionId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: SiThemedPageScaffold(
        title: 'Reports',
        subtitle: 'Finished meetings & classes',
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Meetings'),
                Tab(text: 'Class report'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _loadingM
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _meetings.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final r = _meetings[i];
                            final id = (r['id'] as num?)?.toInt() ?? 0;
                            final title = r['title']?.toString() ?? '';
                            final viewers = (r['total_viewers'] as num?)?.toInt() ?? 0;
                            return Card(
                              child: ExpansionTile(
                                title: Text(title),
                                subtitle: Text('Viewers: $viewers'),
                                children: [
                                  ListTile(
                                    dense: true,
                                    title: const Text('Staff viewers'),
                                    onTap: () async {
                                      final list = await ZoomLiveClassesRepository.getViewers(
                                        conferenceId: id,
                                        type: 'staff',
                                      );
                                      if (!context.mounted) return;
                                      showModalBottomSheet<void>(
                                        context: context,
                                        builder: (ctx) => ListView(
                                          children: list
                                              .map(
                                                (v) => ListTile(
                                                  title: Text(
                                                    '${v['staff_name'] ?? ''} ${v['staff_surname'] ?? ''}'.trim(),
                                                  ),
                                                  subtitle: Text('Hits: ${v['total_hit'] ?? 0}'),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextField(
                        controller: _classId,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Class ID'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _sectionId,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Section ID'),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _loadClass, child: const Text('Load class report')),
                      const SizedBox(height: 16),
                      ..._classRows.map(
                        (r) => Card(
                          child: ListTile(
                            title: Text(r['title']?.toString() ?? ''),
                            subtitle: Text('Viewers: ${(r['total_viewers'] as num?)?.toInt() ?? 0}'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
