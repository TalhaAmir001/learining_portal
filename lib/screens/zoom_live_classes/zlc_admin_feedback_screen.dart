import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/zoom_live_classes/zoom_live_classes_models.dart';
import 'package:learining_portal/network/domain/zoom_live_classes_repository.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:provider/provider.dart';

class ZlcAdminFeedbackScreen extends StatefulWidget {
  const ZlcAdminFeedbackScreen({super.key});

  @override
  State<ZlcAdminFeedbackScreen> createState() => _ZlcAdminFeedbackScreenState();
}

class _ZlcAdminFeedbackScreenState extends State<ZlcAdminFeedbackScreen> {
  ZlcFeedbackSummaryModel? _summary;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await ZoomLiveClassesRepository.getAdminFeedbackSummary();
    final list = await ZoomLiveClassesRepository.getAdminFeedbackList();
    if (mounted) {
      setState(() {
        _summary = s;
        _items = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final staffId = auth.portalStaffId ?? int.tryParse(auth.currentUser?.id ?? '') ?? 0;
    return SiThemedPageScaffold(
      title: 'Live class feedback',
      subtitle: 'Admin dashboard',
      actions: [
        IconButton(onPressed: () { setState(() => _loading = true); _load(); }, icon: const Icon(Icons.refresh)),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_summary != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text('Total ${_summary!.total}')),
                        Chip(label: Text('Unread ${_summary!.unread}')),
                        Chip(label: Text('Read ${_summary!.read}')),
                        Chip(label: Text('Critical ${_summary!.critical}')),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final r = _items[i];
                      final id = (r['id'] as num?)?.toInt() ?? 0;
                      final name = '${r['firstname'] ?? ''} ${r['lastname'] ?? ''}'.trim();
                      final read = r['read_at'] != null;
                      return Card(
                        child: ListTile(
                          title: Text(name.isEmpty ? 'Student' : name),
                          subtitle: Text(
                            '★ ${r['behavior_rating'] ?? ''} · ${r['conference_title'] ?? ''}\n${r['comment'] ?? ''}',
                            maxLines: 4,
                          ),
                          isThreeLine: true,
                          trailing: read
                              ? TextButton(
                                  onPressed: () async {
                                    await ZoomLiveClassesRepository.adminMarkFeedbackUnread(id: id);
                                    _load();
                                  },
                                  child: const Text('Unread'),
                                )
                              : TextButton(
                                  onPressed: staffId <= 0
                                      ? null
                                      : () async {
                                          await ZoomLiveClassesRepository.adminMarkFeedbackRead(
                                            id: id,
                                            staffId: staffId,
                                          );
                                          _load();
                                        },
                                  child: const Text('Read'),
                                ),
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
