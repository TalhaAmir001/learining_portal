import 'package:flutter/material.dart';
import 'package:learining_portal/network/domain/zoom_live_classes_repository.dart';
import 'package:learining_portal/providers/auth_provider.dart' show AuthProvider, UserType;
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';
import 'package:learining_portal/screens/zoom_live_classes/zlc_join_detail_screen.dart';
import 'package:provider/provider.dart';

class ZlcMeetingsListScreen extends StatefulWidget {
  const ZlcMeetingsListScreen({super.key});

  @override
  State<ZlcMeetingsListScreen> createState() => _ZlcMeetingsListScreenState();
}

class _ZlcMeetingsListScreenState extends State<ZlcMeetingsListScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final sid = auth.portalStaffId ?? int.tryParse(auth.currentUser?.id ?? '') ?? 0;
    final list = await ZoomLiveClassesRepository.getMeetings(
      staffId: auth.userType == UserType.admin ? 0 : sid,
    );
    if (mounted) {
      setState(() {
        _rows = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SiThemedPageScaffold(
      title: 'Live meetings',
      subtitle: 'Staff Zoom meetings',
      actions: [
        IconButton(
          onPressed: () {
            setState(() => _loading = true);
            _load();
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: _rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final r = _rows[i];
                final id = (r['id'] as num?)?.toInt() ?? 0;
                final title = r['title']?.toString() ?? '';
                final date = r['date']?.toString() ?? '';
                return Card(
                  child: ListTile(
                    title: Text(title),
                    subtitle: Text(date),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      if (id <= 0) return;
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ZlcJoinDetailScreen(conferenceId: id),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
